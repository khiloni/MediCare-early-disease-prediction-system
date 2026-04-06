import json
import os
import torch
import torch.nn.functional as F
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from transformers import AutoTokenizer, AutoModelForSequenceClassification

# ─── App Setup ──────────────────────────────────────────────

app = FastAPI(
    title="Medicare AI Backend",
    description="AI Health Assistant with Supabase integration",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Model Config ───────────────────────────────────────────

MODEL_DIR = "./model"
CONFIDENCE_THRESHOLD = 0.60

tokenizer = None
model = None
disease_info = {}


class SymptomRequest(BaseModel):
    symptoms: str


class PredictionResponse(BaseModel):
    disease: str
    confidence: float
    precautions: list[str]
    recommended_tests: list[str]


# ─── Startup ────────────────────────────────────────────────

@app.on_event("startup")
async def load_resources():
    global tokenizer, model, disease_info

    json_path = "disease_info.json"
    if os.path.exists(json_path):
        with open(json_path, "r", encoding="utf-8") as f:
            disease_info = json.load(f)
    else:
        print(f"Warning: {json_path} not found.")

    if os.path.isdir(MODEL_DIR):
        print(f"Loading model from {MODEL_DIR}...")
        tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR)
        model = AutoModelForSequenceClassification.from_pretrained(MODEL_DIR)
        model.eval()
        print("Model loaded successfully.")
    else:
        print(f"Error: Model directory '{MODEL_DIR}' not found.")

    # Register prediction function with patient router
    from routers.patient_router import set_predict_function
    set_predict_function(_run_prediction, disease_info)


# ─── Core Prediction Logic ─────────────────────────────────

def _run_prediction(symptoms_text: str) -> dict:
    """Run the AI model prediction. Returns dict with disease, confidence, precautions, tests."""
    if model is None or tokenizer is None:
        raise Exception("Model is not loaded.")

    inputs = tokenizer(
        symptoms_text,
        return_tensors="pt",
        truncation=True,
        padding=True,
        max_length=128,
    )

    with torch.no_grad():
        outputs = model(**inputs)

    logits = outputs.logits
    probs = F.softmax(logits, dim=1)
    conf, predicted_class_idx = torch.max(probs, dim=1)

    confidence = conf.item()
    c_idx = predicted_class_idx.item()
    disease_name = model.config.id2label.get(c_idx, "Unknown Disease")

    if confidence < CONFIDENCE_THRESHOLD:
        return {
            "disease": "Unknown Disease",
            "confidence": round(confidence, 4),
            "precautions": ["Disease not covered by the model. Please consult a doctor."],
            "recommended_tests": ["Consult a doctor for proper diagnosis."],
        }

    details = disease_info.get(
        disease_name,
        {
            "precautions": ["Consult a doctor for detailed precautions."],
            "recommended_tests": ["Consult a doctor for appropriate tests."],
        },
    )

    return {
        "disease": disease_name,
        "confidence": round(confidence, 4),
        "precautions": details["precautions"],
        "recommended_tests": details["recommended_tests"],
    }


# ─── Legacy Predict Endpoint (kept for compatibility) ──────

@app.post("/predict", response_model=PredictionResponse)
async def predict_disease(request: SymptomRequest):
    if model is None or tokenizer is None:
        raise HTTPException(status_code=500, detail="Model is not loaded.")
    if not request.symptoms.strip():
        raise HTTPException(status_code=400, detail="Symptoms text cannot be empty.")

    try:
        result = _run_prediction(request.symptoms)
        return PredictionResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")


@app.get("/")
def read_root():
    return {
        "message": "Medicare AI API is running.",
        "version": "2.0.0",
        "docs": "/docs",
    }


# ─── Register Routers ──────────────────────────────────────

from routers.auth_router import router as auth_router
from routers.patient_router import router as patient_router
from routers.doctor_router import router as doctor_router
from routers.admin_router import router as admin_router

app.include_router(auth_router)
app.include_router(patient_router)
app.include_router(doctor_router)
app.include_router(admin_router)


# ─── Run ────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)