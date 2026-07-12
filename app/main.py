import os
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException

load_dotenv()

from app.integrations.github_service import (
    GitHubPublisher,
    GitHubPublisherError,
)
from app.models.service_request import ServiceRequest
from app.orchestrator.platform_orchestrator import create_platform_service
from app.security.checkov_scanner import (
    CheckovExecutionError,
    CheckovPolicyError,
    scan_generated_platform,
)


app = FastAPI(
    title="Platform Engineering Reference Architecture",
    version="1.0.0",
    description="Internal Developer Platform for self-service deployments",
)


@app.get("/")
def home():
    return {
        "platform": "AI Platform Engineering IDP",
        "status": "running",
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "security_scanning": "checkov",
    }


@app.post("/platform/service")
def create_service(request: ServiceRequest):
    try:
        # Step 1: Generate Kubernetes, Terraform, Argo CD,
        # Kyverno, observability and CI/CD files.
        result = create_platform_service(request)

        output_directory = (
            Path("generated")
            / request.environment
            / request.service_name
        ).resolve()

        # Step 2: Scan the generated infrastructure before GitHub publishing.
        #
        # CHECKOV_ENFORCE=true:
        #   Failed checks block branch and pull-request creation.
        #
        # CHECKOV_ENFORCE=false:
        #   Findings are reported, but publishing may continue.
        checkov_enforce = (
            os.getenv("CHECKOV_ENFORCE", "true")
            .strip()
            .lower()
            == "true"
        )

        checkov_result = scan_generated_platform(
            output_directory,
            enforce=checkov_enforce,
        )

        response = {
            "message": "Platform generated and security validation completed",
            **result,
            "security": {
                "checkov": {
                    "enforced": checkov_enforce,
                    **checkov_result.to_dict(),
                },
            },
        }

        # Step 3: Decide whether GitHub publishing is enabled.
        publish_enabled = (
            os.getenv("GITHUB_PUBLISH_ENABLED", "false")
            .strip()
            .lower()
            == "true"
        )

        if not publish_enabled:
            response["gitops"] = {
                "status": "disabled",
                "message": (
                    "Files were generated and scanned locally. "
                    "GitHub publishing is disabled."
                ),
            }

            return response

        # Step 4: Publish only after Checkov validation.
        publisher = GitHubPublisher()

        publication = publisher.publish_service(
            service_name=request.service_name,
            owner=request.owner,
            environment=request.environment,
            output_directory=output_directory,
        )

        response["message"] = (
            "Platform generated, validated, and GitHub pull request "
            "created successfully"
        )

        response["gitops"] = {
            "status": "pull_request_created",
            **publication,
        }

        return response

    except CheckovPolicyError as exc:
        raise HTTPException(
            status_code=422,
            detail={
                "message": (
                    "Generated infrastructure failed Checkov "
                    "security validation."
                ),
                "security_gate": "checkov",
                "github_pull_request_created": False,
                "checkov": {
                    "enforced": True,
                    **exc.result.to_dict(),
                },
            },
        ) from exc

    except CheckovExecutionError as exc:
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Checkov security validation could not run.",
                "security_gate": "checkov",
                "github_pull_request_created": False,
                "error": str(exc),
            },
        ) from exc

    except GitHubPublisherError as exc:
        raise HTTPException(
            status_code=502,
            detail={
                "message": (
                    "Platform files passed generation and validation, "
                    "but GitHub publishing failed."
                ),
                "github_pull_request_created": False,
                "error": str(exc),
            },
        ) from exc

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Platform service creation failed.",
                "github_pull_request_created": False,
                "error": str(exc),
            },
        ) from exc