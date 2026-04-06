from fastapi import APIRouter, Depends, HTTPException
import os
import csv
from auth import get_current_user, require_role
from config import supabase_admin
from models import (
    PatientProfileCreate, PatientProfileResponse,
    SymptomInput, PredictionResponse, HistoryItem,
    PrescriptionResponse
)
import json

router = APIRouter(prefix="/patient", tags=["Patient"])

# We'll import the prediction function from main at runtime
predict_fn = None
disease_info_ref = None


def set_predict_function(fn, info):
    global predict_fn, disease_info_ref
    predict_fn = fn
    disease_info_ref = info


# ─── Profile ────────────────────────────────────────────────

@router.post("/profile", response_model=PatientProfileResponse)
async def create_or_update_profile(
    profile: PatientProfileCreate,
    current_user: dict = Depends(require_role("patient"))
):
    """Create or update patient profile."""
    user_id = current_user["user_id"]
    try:
        # Check if profile exists
        existing = supabase_admin.table("patient_profiles").select("*").eq("user_id", user_id).execute()

        profile_data = {
            "user_id": user_id,
            "name": profile.name,
            "age": profile.age,
            "gender": profile.gender,
            "blood_group": profile.blood_group,
            "allergies": profile.allergies,
        }

        if existing.data:
            supabase_admin.table("patient_profiles").update(profile_data).eq("user_id", user_id).execute()
        else:
            supabase_admin.table("patient_profiles").insert(profile_data).execute()

        return PatientProfileResponse(**profile_data)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Profile error: {str(e)}")


@router.get("/profile")
async def get_profile(current_user: dict = Depends(require_role("patient"))):
    """Get patient profile."""
    user_id = current_user["user_id"]
    result = supabase_admin.table("patient_profiles").select("*").eq("user_id", user_id).execute()
    if not result.data:
        return {"profile": None, "profile_complete": False}
    return {"profile": result.data[0], "profile_complete": True}


# ─── Prediction ─────────────────────────────────────────────

@router.post("/predict")
async def predict_disease(
    request: SymptomInput,
    current_user: dict = Depends(require_role("patient"))
):
    """Submit symptoms for AI prediction and auto-generate prescription."""
    if not request.symptoms.strip():
        raise HTTPException(status_code=400, detail="Symptoms cannot be empty")

    user_id = current_user["user_id"]

    try:
        # Run AI prediction
        if predict_fn is None:
            raise HTTPException(status_code=500, detail="AI model not loaded")

        prediction_result = predict_fn(request.symptoms)

        disease = prediction_result["disease"]
        confidence = prediction_result["confidence"]
        precautions = prediction_result["precautions"]
        recommended_tests = prediction_result["recommended_tests"]

        # 1. Log symptoms
        symptom_log = supabase_admin.table("symptom_logs").insert({
            "patient_id": user_id,
            "symptoms": request.symptoms,
        }).execute()

        symptom_log_id = symptom_log.data[0]["id"]

        # 2. Create prediction
        prediction = supabase_admin.table("predictions").insert({
            "patient_id": user_id,
            "symptom_log_id": symptom_log_id,
            "predicted_disease": disease,
            "confidence": confidence,
            "status": "PENDING_DOCTOR_VERIFICATION",
        }).execute()

        prediction_id = prediction.data[0]["id"]

        # 3. Generate medicines based on disease
        medicines = _get_medicines_for_disease(disease)

        # 4. Auto-generate prescription
        prescription = supabase_admin.table("prescriptions").insert({
            "prediction_id": prediction_id,
            "disease": disease,
            "medicines": medicines,
            "precautions": json.dumps(precautions),
            "tests": json.dumps(recommended_tests),
            "verification_status": "PENDING_DOCTOR_VERIFICATION",
        }).execute()

        prescription_id = prescription.data[0]["id"]

        # 5. Generate PDF
        from services.prescription_pdf import generate_and_upload_pdf
        patient_profile = supabase_admin.table("patient_profiles").select("*").eq("user_id", user_id).execute()
        patient_info = patient_profile.data[0] if patient_profile.data else {"name": "Patient"}

        pdf_url = await generate_and_upload_pdf(
            prescription_id=prescription_id,
            patient_info=patient_info,
            symptoms=request.symptoms,
            disease=disease,
            medicines=medicines,
            precautions=precautions,
            tests=recommended_tests,
        )

        # Update prescription with PDF URL
        if pdf_url:
            supabase_admin.table("prescriptions").update(
                {"pdf_url": pdf_url}
            ).eq("id", prescription_id).execute()

        return {
            "prediction_id": prediction_id,
            "prescription_id": prescription_id,
            "disease": disease,
            "confidence": confidence,
            "precautions": precautions,
            "recommended_tests": recommended_tests,
            "medicines": medicines,
            "status": "PENDING_DOCTOR_VERIFICATION",
            "pdf_url": pdf_url,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")


# ─── History ────────────────────────────────────────────────

@router.get("/history")
async def get_history(current_user: dict = Depends(require_role("patient"))):
    """Get patient's prediction history."""
    user_id = current_user["user_id"]
    try:
        predictions = supabase_admin.table("predictions").select(
            "id, predicted_disease, confidence, status, created_at, symptom_log_id"
        ).eq("patient_id", user_id).order("created_at", desc=True).execute()

        history = []
        for pred in predictions.data:
            # Get symptoms
            symptom = supabase_admin.table("symptom_logs").select("symptoms").eq(
                "id", pred["symptom_log_id"]
            ).single().execute()

            # Get prescription
            prescription = supabase_admin.table("prescriptions").select(
                "verification_status, pdf_url"
            ).eq("prediction_id", pred["id"]).execute()

            rx = prescription.data[0] if prescription.data else {}

            history.append({
                "prediction_id": pred["id"],
                "symptoms": symptom.data["symptoms"] if symptom.data else "",
                "disease": pred["predicted_disease"],
                "confidence": float(pred["confidence"]),
                "status": pred["status"],
                "verification_status": rx.get("verification_status", "PENDING_DOCTOR_VERIFICATION"),
                "pdf_url": rx.get("pdf_url"),
                "created_at": pred["created_at"],
            })

        return {"history": history}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"History error: {str(e)}")


# ─── Prescription Detail ───────────────────────────────────

@router.get("/prescription/{prediction_id}")
async def get_prescription(
    prediction_id: str,
    current_user: dict = Depends(require_role("patient"))
):
    """Get prescription details for a prediction."""
    try:
        rx = supabase_admin.table("prescriptions").select("*").eq(
            "prediction_id", prediction_id
        ).execute()

        if not rx.data:
            raise HTTPException(status_code=404, detail="Prescription not found")

        prescription = rx.data[0]

        # Get doctor review if any
        review = supabase_admin.table("doctor_reviews").select("*").eq(
            "prediction_id", prediction_id
        ).execute()

        return {
            "prescription": prescription,
            "review": review.data[0] if review.data else None,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prescription error: {str(e)}")


# ─── Helpers ────────────────────────────────────────────────

def _get_medicines_for_disease(disease: str) -> str:
    """Get suggested medicines for a disease from external CSV dataset."""
    try:
        data_path = os.path.join(os.path.dirname(__file__), "..", "medicines.csv")
        if os.path.exists(data_path):
            matching_meds = []
            with open(data_path, mode="r", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if row["Disease"].strip().lower() == disease.strip().lower():
                        # Format: Medicine (Dosage, Route, Duration)
                        med_info = f"{row['Medicine']} ({row['Dosage']}, {row['Route']}, {row['Duration']})"
                        matching_meds.append(med_info)
            
            if matching_meds:
                return ", ".join(matching_meds)
    except Exception as e:
        print(f"Error loading medicines: {e}")
    
    return "Consult a doctor for appropriate medication"
