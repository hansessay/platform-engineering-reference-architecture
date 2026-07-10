from fastapi import FastAPI

from app.models.service_request import ServiceRequest
from app.orchestrator.platform_orchestrator import create_platform_service

app = FastAPI(
    title="Platform Engineering Reference Architecture",
    version="1.0.0",
    description="Internal Developer Platform for self-service deployments",
)


@app.get("/")
def home():
    return {"platform": "AI Platform Engineering IDP", "status": "running"}


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.post("/platform/service")
def create_service(request: ServiceRequest):
    result = create_platform_service(request)

    return {
        "message": "Platform generated successfully",
        **result,
    }