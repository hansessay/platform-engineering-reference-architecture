from pathlib import Path
from jinja2 import Environment, FileSystemLoader

from app.models.service_request import ServiceRequest


BASE_DIR = Path(__file__).resolve().parent.parent.parent
TEMPLATE_DIR = BASE_DIR / "app" / "templates"
OUTPUT_DIR = BASE_DIR / "generated"


def generate_github_actions_workflow(request: ServiceRequest):
    env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))

    service_dir = OUTPUT_DIR / request.environment / request.service_name
    service_dir.mkdir(parents=True, exist_ok=True)

    template = env.get_template("github-actions.yaml.j2")

    rendered = template.render(
        service_name=request.service_name,
        owner=request.owner,
        language=request.language,
        environment=request.environment,
        needs_ai=request.needs_ai,
        aws_account_id=request.aws_account_id,
        aws_region=request.aws_region,
        github_owner=request.github_owner,
        github_repo=request.github_repo,
    )

    output_path = service_dir / "github-actions.yaml"
    output_path.write_text(rendered)

    return [str(output_path)]