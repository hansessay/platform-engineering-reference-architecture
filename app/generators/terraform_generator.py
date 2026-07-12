from pathlib import Path
from jinja2 import Environment, FileSystemLoader

from app.models.service_request import ServiceRequest


BASE_DIR = Path(__file__).resolve().parent.parent.parent
TEMPLATE_DIR = BASE_DIR / "app" / "templates"
OUTPUT_DIR = BASE_DIR / "generated"


TERRAFORM_TEMPLATES = [
   "terraform/variables.tf.j2",
    "terraform/kms.tf.j2",
    "terraform/eks-iam.tf.j2",
    "terraform/ecr.tf.j2",
    "terraform/github-oidc-role.tf.j2",
    "terraform/vpc.tf.j2",
    "terraform/subnets.tf.j2",
    "terraform/security-groups.tf.j2",
    "terraform/alb.tf.j2",
    "terraform/acm.tf.j2",
    "terraform/route53.tf.j2",
    "terraform/external-dns.tf.j2",
    "terraform/eks.tf.j2",
    "terraform/providers.tf.j2",
]


def generate_terraform_files(request: ServiceRequest):
    env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))

    service_dir = OUTPUT_DIR / request.environment / request.service_name / "terraform"
    service_dir.mkdir(parents=True, exist_ok=True)

    generated_files = []

    for template_name in TERRAFORM_TEMPLATES:
        template = env.get_template(template_name)

        rendered = template.render(
            service_name=request.service_name,
            owner=request.owner,
            language=request.language,
            environment=request.environment,
            needs_ai=request.needs_ai,
            aws_region=request.aws_region,
            aws_account_id=request.aws_account_id,
            github_owner=request.github_owner,
            github_repo=request.github_repo,
        )

        output_name = Path(template_name).name.replace(".j2", "")
        output_path = service_dir / output_name

        output_path.write_text(rendered, encoding="utf-8")

        generated_files.append(str(output_path))

    return generated_files