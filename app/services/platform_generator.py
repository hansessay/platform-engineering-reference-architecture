from pathlib import Path
from jinja2 import Environment, FileSystemLoader

from app.models.service_request import ServiceRequest


BASE_DIR = Path(__file__).resolve().parent.parent.parent
TEMPLATE_DIR = BASE_DIR / "app" / "templates"
OUTPUT_DIR = BASE_DIR / "generated"


def generate_service_platform(request: ServiceRequest):
    env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))

    service_dir = OUTPUT_DIR / request.environment / request.service_name
    service_dir.mkdir(parents=True, exist_ok=True)

    templates = [
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
    ]

    generated_files = []

    for template_name in templates:
        template = env.get_template(template_name)
        rendered = template.render(
            service_name=request.service_name,
            owner=request.owner,
            language=request.language,
            environment=request.environment,
            needs_ai=request.needs_ai,
        )

        output_name = template_name.replace(".j2", "")
        output_path = service_dir / output_name
        output_path.write_text(rendered)

        generated_files.append(str(output_path))

    return generated_files