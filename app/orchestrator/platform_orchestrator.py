from app.models.service_request import ServiceRequest
from app.generators.kubernetes_generator import generate_kubernetes_manifests
from app.generators.github_actions_generator import generate_github_actions_workflow
from app.generators.terraform_generator import generate_terraform_files


def create_platform_service(request: ServiceRequest):
    generated_files = []

    kubernetes_files = generate_kubernetes_manifests(request)
    generated_files.extend(kubernetes_files)

    github_actions_files = generate_github_actions_workflow(request)
    generated_files.extend(github_actions_files)

    terraform_files = generate_terraform_files(request)
    generated_files.extend(terraform_files)

    return {
        "service_name": request.service_name,
        "environment": request.environment,
        "owner": request.owner,
        "generated_files": generated_files,
    }