from __future__ import annotations

import json
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass
class CheckovResult:
    passed: bool
    exit_code: int
    passed_checks: int
    failed_checks: int
    skipped_checks: int
    failed_check_details: list[dict[str, Any]]

    def to_dict(self) -> dict[str, Any]:
        return {
            "passed": self.passed,
            "exit_code": self.exit_code,
            "summary": {
                "passed": self.passed_checks,
                "failed": self.failed_checks,
                "skipped": self.skipped_checks,
            },
            "failed_checks": self.failed_check_details,
        }


class CheckovExecutionError(RuntimeError):
    """Raised when Checkov cannot run correctly."""


class CheckovPolicyError(RuntimeError):
    """Raised when generated infrastructure fails Checkov checks."""

    def __init__(self, result: CheckovResult) -> None:
        self.result = result
        super().__init__(
            f"Checkov found {result.failed_checks} failed security checks."
        )


def _find_checkov() -> str:
    executable = shutil.which("checkov")

    if executable:
        return executable

    raise CheckovExecutionError(
        "Checkov is not installed in the active virtual environment."
    )


def _normalise_reports(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]

    if isinstance(payload, dict):
        return [payload]

    return []


def scan_generated_platform(
    output_directory: Path | str,
    *,
    enforce: bool = True,
) -> CheckovResult:
    scan_directory = Path(output_directory).resolve()

    if not scan_directory.exists():
        raise CheckovExecutionError(
            f"Generated directory does not exist: {scan_directory}"
        )

    if not scan_directory.is_dir():
        raise CheckovExecutionError(
            f"Checkov scan path is not a directory: {scan_directory}"
        )

    command = [
        _find_checkov(),
        "--directory",
        str(scan_directory),
        "--framework",
        "terraform",
        "kubernetes",
        "--output",
        "json",
        "--compact",
        "--quiet",
        "--download-external-modules",
        "false",
    ]

    process = subprocess.run(
        command,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )

    raw_output = process.stdout.strip()

    if not raw_output:
        error_message = process.stderr.strip() or "Checkov returned no output."
        raise CheckovExecutionError(
            f"Checkov execution failed: {error_message}"
        )

    try:
        payload = json.loads(raw_output)
    except json.JSONDecodeError as exc:
        raise CheckovExecutionError(
            "Checkov returned invalid JSON."
        ) from exc

    reports = _normalise_reports(payload)

    passed_checks = 0
    failed_checks = 0
    skipped_checks = 0
    failed_check_details: list[dict[str, Any]] = []

    for report in reports:
        summary = report.get("summary", {})

        passed_checks += int(summary.get("passed", 0) or 0)
        failed_checks += int(summary.get("failed", 0) or 0)
        skipped_checks += int(summary.get("skipped", 0) or 0)

        results = report.get("results", {})

        for finding in results.get("failed_checks", []) or []:
            failed_check_details.append(
                {
                    "check_id": finding.get("check_id"),
                    "check_name": finding.get("check_name"),
                    "resource": finding.get("resource"),
                    "file_path": finding.get("file_path"),
                    "file_line_range": finding.get("file_line_range"),
                    "guideline": finding.get("guideline"),
                }
            )

    result = CheckovResult(
        passed=failed_checks == 0,
        exit_code=process.returncode,
        passed_checks=passed_checks,
        failed_checks=failed_checks,
        skipped_checks=skipped_checks,
        failed_check_details=failed_check_details,
    )

    if enforce and not result.passed:
        raise CheckovPolicyError(result)

    return result