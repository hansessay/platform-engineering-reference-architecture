from pathlib import Path

from jinja2 import Environment, FileSystemLoader, StrictUndefined

from app.models.service_request import ServiceRequest


BASE_DIR = Path(__file__).resolve().parent.parent.parent
TEMPLATE_DIR = BASE_DIR / "app" / "templates"
OUTPUT_DIR = BASE_DIR / "generated"


KUBERNETES_TEMPLATES = [
    "namespace.yaml.j2",
    "deployment.yaml.j2",
    "service.yaml.j2",
    "configmap.yaml.j2",
    "secret.yaml.j2",
    "ingress.yaml.j2",
    "hpa.yaml.j2",
    "pdb.yaml.j2",
    "networkpolicy.yaml.j2",
    "rbac.yaml.j2",
    "argocd-app.yaml.j2",

    # Observability
    "servicemonitor.yaml.j2",
    "prometheusrule.yaml.j2",
    "alertmanager-config.yaml.j2",
    "grafana-dashboard.json.j2",

    # Security
    "kyverno-require-nonroot.yaml.j2",
    "kyverno-require-resources.yaml.j2",
    "kyverno-disallow-latest.yaml.j2",
    "kyverno-require-labels.yaml.j2",
]


def generate_kubernetes_manifests(request: ServiceRequest) -> list[str]:
    env = Environment(
        loader=FileSystemLoader(TEMPLATE_DIR),
        undefined=StrictUndefined,
        trim_blocks=True,
        lstrip_blocks=True,
    )

    target_namespace = f"{request.environment}-{request.owner}".lower()

    service_dir = OUTPUT_DIR / request.environment / request.service_name
    kyverno_dir = service_dir / "kyverno"

    service_dir.mkdir(parents=True, exist_ok=True)
    kyverno_dir.mkdir(parents=True, exist_ok=True)

    generated_files: list[str] = []

    template_context = {
        "service_name": request.service_name,
        "owner": request.owner,
        "language": request.language,
        "environment": request.environment,
        "needs_ai": request.needs_ai,
        "aws_account_id": request.aws_account_id,
        "aws_region": request.aws_region,
        "target_namespace": target_namespace,

        # Persistent storage
        "persistent_storage": request.persistent_storage,
        "storage_type": request.storage_type,
        "storage_size": request.storage_size,
        "storage_class": request.storage_class,
        "storage_access_mode": request.storage_access_mode,
        "mount_path": request.mount_path,
        "storage_snapshots": request.storage_snapshots,
    }

    templates_to_generate = KUBERNETES_TEMPLATES.copy()

    if request.persistent_storage:
        templates_to_generate.append("pvc.yaml.j2")

    for template_name in templates_to_generate:
        template = env.get_template(template_name)
        rendered = template.render(**template_context)

        output_name = template_name.removesuffix(".j2")

        if template_name.startswith("kyverno"):
            output_path = kyverno_dir / output_name
        else:
            output_path = service_dir / output_name

        output_path.write_text(rendered, encoding="utf-8")
        generated_files.append(str(output_path))

    return generated_files