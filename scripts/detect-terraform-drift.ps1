param(
    [string]$TerraformDirectory = "generated\dev\patient-ai-api\terraform"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $TerraformDirectory)) {
    Write-Error "Terraform directory not found: $TerraformDirectory"
    exit 1
}

Push-Location $TerraformDirectory

try {
    Write-Host "Initializing Terraform..."
    terraform init -input=false

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform initialization failed."
        exit 1
    }

    Write-Host "Checking Terraform formatting..."
    terraform fmt -check -recursive

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform formatting check failed."
        exit 1
    }

    Write-Host "Validating Terraform configuration..."
    terraform validate

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform validation failed."
        exit 1
    }

    Write-Host "Checking for infrastructure drift..."

    terraform plan `
        -input=false `
        -detailed-exitcode `
        -no-color `
        -out=tfplan

    $planExitCode = $LASTEXITCODE

    switch ($planExitCode) {
        0 {
            Write-Host "No Terraform drift detected."
            exit 0
        }

        1 {
            Write-Error "Terraform plan failed."
            exit 1
        }

        2 {
            Write-Warning "Terraform drift or pending infrastructure changes detected."

            terraform show -no-color tfplan |
                Set-Content drift-report.txt

            Write-Host "Drift report written to:"
            Write-Host "$TerraformDirectory\drift-report.txt"

            exit 2
        }

        default {
            Write-Error "Unexpected Terraform exit code: $planExitCode"
            exit 1
        }
    }
}
finally {
    Pop-Location
}