from fastapi import FastAPI

app = FastAPI(
    title="Patient AI API",
    version="1.0.0",
    description="Demo healthcare service managed through the SRE Platform",
)


@app.get("/")
def home():
    return {
        "service": "patient-ai-api",
        "status": "running",
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
    }


@app.get("/patients/{patient_id}")
def get_patient(patient_id: str):
    return {
        "patient_id": patient_id,
        "risk": "low",
        "source": "demo",
    }