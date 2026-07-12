from __future__ import annotations

import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from github import Auth, Github
from github.GithubException import GithubException
from github.Repository import Repository


class GitHubPublisherError(RuntimeError):
    """Raised when generated platform files cannot be published to GitHub."""


class GitHubPublisher:
    def __init__(self) -> None:
        token = os.getenv("GITHUB_TOKEN")
        repository_name = os.getenv("GITHUB_REPOSITORY")
        default_branch = os.getenv("GITHUB_DEFAULT_BRANCH", "main")

        if not token:
            raise GitHubPublisherError("GITHUB_TOKEN is not configured.")

        if not repository_name:
            raise GitHubPublisherError(
                "GITHUB_REPOSITORY is not configured."
            )

        self.repository_name = repository_name.strip()
        self.default_branch = default_branch.strip()

        self.client = Github(
            auth=Auth.Token(token.strip()),
            timeout=30,
            retry=1,
        )

    @staticmethod
    def _slugify(value: str) -> str:
        value = value.strip().lower()
        value = re.sub(r"[^a-z0-9._-]+", "-", value)
        return value.strip("-")

    def _get_repository(self) -> Repository:
        try:
            repository = self.client.get_repo(self.repository_name)

            print(
                f"Connected to GitHub repository: {repository.full_name}",
                flush=True,
            )

            return repository

        except GithubException as exc:
            raise GitHubPublisherError(
                f"Unable to access GitHub repository "
                f"'{self.repository_name}': {exc.data}"
            ) from exc

    def _create_branch(
        self,
        repository: Repository,
        service_name: str,
        environment: str,
    ) -> str:
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")

        branch_name = (
            f"platform/{self._slugify(environment)}-"
            f"{self._slugify(service_name)}-{timestamp}"
        )

        try:
            base_branch = repository.get_branch(self.default_branch)

            repository.create_git_ref(
                ref=f"refs/heads/{branch_name}",
                sha=base_branch.commit.sha,
            )

            print(
                f"Created GitHub branch: {branch_name}",
                flush=True,
            )

            return branch_name

        except GithubException as exc:
            raise GitHubPublisherError(
                f"Unable to create GitHub branch "
                f"'{branch_name}': {exc.data}"
            ) from exc

    @staticmethod
    def _collect_files(output_directory: Path) -> list[Path]:
        if not output_directory.exists():
            raise GitHubPublisherError(
                f"Generated directory does not exist: "
                f"{output_directory}"
            )

        excluded_directories = {
            ".terraform",
            ".git",
            ".venv",
            "__pycache__",
            "node_modules",
        }

        excluded_suffixes = {
            ".exe",
            ".dll",
            ".so",
            ".dylib",
            ".pyc",
            ".tfstate",
            ".tfplan",
            ".zip",
            ".tar",
            ".gz",
        }

        excluded_names = {
            "terraform.tfstate",
            "terraform.tfstate.backup",
            "terraform.tfvars",
            "terraform.tfvars.json",
            "tfplan",
            "crash.log",
        }

        files: list[Path] = []

        for path in output_directory.rglob("*"):
            if not path.is_file():
                continue

            relative_path = path.relative_to(output_directory)

            if any(
                part in excluded_directories
                for part in relative_path.parts
            ):
                continue

            if path.name in excluded_names:
                continue

            if path.suffix.lower() in excluded_suffixes:
                continue

            files.append(path)

        files.sort()

        if not files:
            raise GitHubPublisherError(
                f"No publishable generated files found in: "
                f"{output_directory}"
            )

        return files

    @staticmethod
    def _read_file_content(local_file: Path) -> str:
        try:
            return local_file.read_text(encoding="utf-8")

        except UnicodeDecodeError as exc:
            raise GitHubPublisherError(
                f"Generated file is not UTF-8 text: {local_file}"
            ) from exc

        except OSError as exc:
            raise GitHubPublisherError(
                f"Unable to read generated file "
                f"'{local_file}': {exc}"
            ) from exc

    def _build_github_path(
        self,
        *,
        relative_path: Path,
        repository_directory: str,
        service_name: str,
    ) -> str:
        """
        Store GitHub Actions workflows in GitHub's required workflow
        directory. Store all other generated files under the service
        directory.
        """
        relative_posix_path = relative_path.as_posix()

        if relative_posix_path == "github-actions.yaml":
            workflow_name = self._slugify(service_name)

            return f".github/workflows/{workflow_name}.yml"

        return (
            f"{repository_directory.rstrip('/')}/"
            f"{relative_posix_path}"
        )

    def _upload_files(
        self,
        repository: Repository,
        branch_name: str,
        output_directory: Path,
        repository_directory: str,
        service_name: str,
    ) -> list[str]:
        files = self._collect_files(output_directory)
        uploaded_files: list[str] = []

        print(
            f"Publishing {len(files)} files to "
            f"{self.repository_name}:{branch_name}",
            flush=True,
        )

        for index, local_file in enumerate(files, start=1):
            relative_path = local_file.relative_to(output_directory)

            github_path = self._build_github_path(
                relative_path=relative_path,
                repository_directory=repository_directory,
                service_name=service_name,
            )

            print(
                f"[{index}/{len(files)}] Uploading {github_path}",
                flush=True,
            )

            content = self._read_file_content(local_file)

            try:
                repository.create_file(
                    path=github_path,
                    message=(
                        f"platform: add {service_name} "
                        f"{relative_path.name}"
                    ),
                    content=content,
                    branch=branch_name,
                )

                uploaded_files.append(github_path)

            except GithubException as exc:
                raise GitHubPublisherError(
                    f"Unable to upload "
                    f"'{github_path}': {exc.data}"
                ) from exc

        print(
            f"Uploaded {len(uploaded_files)} files successfully.",
            flush=True,
        )

        return uploaded_files

    def _create_pull_request(
        self,
        repository: Repository,
        branch_name: str,
        service_name: str,
        owner: str,
        environment: str,
        uploaded_files: list[str],
    ) -> Any:
        pull_request_title = (
            f"platform: provision {service_name} in {environment}"
        )

        pull_request_body = f"""## Platform service request

This pull request was created automatically by the Internal Developer Platform.

### Service

- **Name:** `{service_name}`
- **Owner:** `{owner}`
- **Environment:** `{environment}`
- **Generated files:** {len(uploaded_files)}

### Automated validation

- GitHub Actions workflow generated
- Checkov security scanning enabled
- Terraform and Kubernetes resources included

### Review checklist

- [ ] Terraform configuration reviewed
- [ ] Kubernetes resources reviewed
- [ ] Checkov findings reviewed
- [ ] Security policies reviewed
- [ ] Argo CD configuration reviewed
- [ ] Ownership information confirmed
"""

        try:
            print(
                "Creating GitHub pull request.",
                flush=True,
            )

            pull_request = repository.create_pull(
                title=pull_request_title,
                body=pull_request_body,
                head=branch_name,
                base=self.default_branch,
                draft=False,
            )

            print(
                f"Created pull request #{pull_request.number}: "
                f"{pull_request.html_url}",
                flush=True,
            )

            return pull_request

        except GithubException as exc:
            raise GitHubPublisherError(
                "Files were uploaded, but the pull request could not "
                f"be created: {exc.data}"
            ) from exc

    def publish_service(
        self,
        *,
        service_name: str,
        owner: str,
        environment: str,
        output_directory: Path,
    ) -> dict[str, Any]:
        repository = self._get_repository()

        branch_name = self._create_branch(
            repository=repository,
            service_name=service_name,
            environment=environment,
        )

        repository_directory = (
            f"services/{self._slugify(environment)}/"
            f"{self._slugify(service_name)}"
        )

        uploaded_files = self._upload_files(
            repository=repository,
            branch_name=branch_name,
            output_directory=output_directory,
            repository_directory=repository_directory,
            service_name=service_name,
        )

        pull_request = self._create_pull_request(
            repository=repository,
            branch_name=branch_name,
            service_name=service_name,
            owner=owner,
            environment=environment,
            uploaded_files=uploaded_files,
        )

        workflow_path = (
            f".github/workflows/"
            f"{self._slugify(service_name)}.yml"
        )

        return {
            "repository": self.repository_name,
            "branch": branch_name,
            "pull_request_number": pull_request.number,
            "pull_request_url": pull_request.html_url,
            "repository_directory": repository_directory,
            "workflow_path": workflow_path,
            "uploaded_files": uploaded_files,
        }