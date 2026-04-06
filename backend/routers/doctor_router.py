from fastapi import APIRouter, Depends, HTTPException
from auth import require_role
from config import supabase_admin
from models import DoctorReviewRequest
import json

router = APIRouter(prefix="/doctor", tags=["Doctor"])


# ─── Dashboard ──────────────────────────────────────────────

@router.get("/dashboard")
async def doctor_dashboard(current_user: dict = Depends(require_role("doctor"))):
    """Get doctor dashboard stats."""
    try:
        # Total pending cases
        pending = supabase_admin.table("predictions").select(
            "id", count="exact"
        ).eq("status", "PENDING_DOCTOR_VERIFICATION").execute()

        # Cases reviewed by this doctor
        reviewed = supabase_admin.table("doctor_reviews").select(
            "id", count="exact"
        ).eq("doctor_id", current_user["user_id"]).execute()

        # Get doctor profile
        profile = supabase_admin.table("doctor_profiles").select("*").eq(
            "user_id", current_user["user_id"]
        ).single().execute()

        return {
            "pending_cases": pending.count or 0,
            "reviewed_cases": reviewed.count or 0,
            "profile": profile.data,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Dashboard error: {str(e)}")


# ─── Pending Cases ──────────────────────────────────────────

@router.get("/cases")
async def get_pending_cases(current_user: dict = Depends(require_role("doctor"))):
    """Get all pending cases for review."""
    try:
        predictions = supabase_admin.table("predictions").select(
            "id, patient_id, predicted_disease, confidence, status, created_at, symptom_log_id"
        ).eq("status", "PENDING_DOCTOR_VERIFICATION").order("created_at", desc=True).execute()

        cases = []
        for pred in predictions.data:
            # Get symptom details
            symptom = supabase_admin.table("symptom_logs").select("symptoms").eq(
                "id", pred["symptom_log_id"]
            ).single().execute()

            # Get patient info
            patient = supabase_admin.table("patient_profiles").select("name, age, gender").eq(
                "user_id", pred["patient_id"]
            ).execute()

            patient_info = patient.data[0] if patient.data else {"name": "Unknown", "age": None, "gender": None}

            cases.append({
                "prediction_id": pred["id"],
                "patient_name": patient_info.get("name", "Unknown"),
                "patient_age": patient_info.get("age"),
                "patient_gender": patient_info.get("gender"),
                "disease": pred["predicted_disease"],
                "confidence": float(pred["confidence"]),
                "symptoms": symptom.data["symptoms"] if symptom.data else "",
                "status": pred["status"],
                "created_at": pred["created_at"],
            })

        return {"cases": cases}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Cases error: {str(e)}")


# ─── Case Detail ────────────────────────────────────────────

@router.get("/cases/{prediction_id}")
async def get_case_detail(
    prediction_id: str,
    current_user: dict = Depends(require_role("doctor"))
):
    """Get full details of a specific case."""
    try:
        # Get prediction
        pred = supabase_admin.table("predictions").select("*").eq(
            "id", prediction_id
        ).single().execute()

        if not pred.data:
            raise HTTPException(status_code=404, detail="Case not found")

        # Get symptoms
        symptom = supabase_admin.table("symptom_logs").select("*").eq(
            "id", pred.data["symptom_log_id"]
        ).single().execute()

        # Get patient profile
        patient = supabase_admin.table("patient_profiles").select("*").eq(
            "user_id", pred.data["patient_id"]
        ).execute()

        # Get prescription
        prescription = supabase_admin.table("prescriptions").select("*").eq(
            "prediction_id", prediction_id
        ).execute()

        # Get existing review
        review = supabase_admin.table("doctor_reviews").select("*").eq(
            "prediction_id", prediction_id
        ).execute()

        return {
            "prediction": pred.data,
            "symptoms": symptom.data if symptom.data else {},
            "patient": patient.data[0] if patient.data else {},
            "prescription": prescription.data[0] if prescription.data else {},
            "review": review.data[0] if review.data else None,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Case detail error: {str(e)}")


# ─── Submit Review ──────────────────────────────────────────

@router.post("/review")
async def submit_review(
    review: DoctorReviewRequest,
    current_user: dict = Depends(require_role("doctor"))
):
    """Submit a doctor review for a prediction (approve/modify/reject)."""
    if review.decision not in ("APPROVED", "MODIFIED", "REJECTED"):
        raise HTTPException(status_code=400, detail="Decision must be APPROVED, MODIFIED, or REJECTED")

    doctor_id = current_user["user_id"]

    try:
        # Verify prediction exists
        pred = supabase_admin.table("predictions").select("id").eq(
            "id", review.prediction_id
        ).single().execute()

        if not pred.data:
            raise HTTPException(status_code=404, detail="Prediction not found")

        # Build updated prescription text
        updated_prescription = None
        if review.decision == "MODIFIED":
            updated_prescription = json.dumps({
                "medicines": review.updated_medicines,
                "precautions": review.updated_precautions,
                "tests": review.updated_tests,
            })

        # Create review record
        review_data = {
            "prediction_id": review.prediction_id,
            "doctor_id": doctor_id,
            "decision": review.decision,
            "notes": review.notes,
            "updated_prescription": updated_prescription,
        }

        # Check if review already exists
        existing_review = supabase_admin.table("doctor_reviews").select("id").eq(
            "prediction_id", review.prediction_id
        ).execute()

        if existing_review.data:
            supabase_admin.table("doctor_reviews").update(review_data).eq(
                "prediction_id", review.prediction_id
            ).execute()
        else:
            supabase_admin.table("doctor_reviews").insert(review_data).execute()

        # Update prediction status
        new_status = f"DOCTOR_{review.decision}"
        supabase_admin.table("predictions").update(
            {"status": new_status}
        ).eq("id", review.prediction_id).execute()

        # Update prescription status
        supabase_admin.table("prescriptions").update({
            "verification_status": review.decision,
            "doctor_id": doctor_id,
        }).eq("prediction_id", review.prediction_id).execute()

        # If modified, update prescription and regenerate PDF
        if review.decision == "MODIFIED":
            update_data = {}
            if review.updated_medicines:
                update_data["medicines"] = review.updated_medicines
            if review.updated_precautions:
                update_data["precautions"] = review.updated_precautions
            if review.updated_tests:
                update_data["tests"] = review.updated_tests

            if update_data:
                supabase_admin.table("prescriptions").update(update_data).eq(
                    "prediction_id", review.prediction_id
                ).execute()

            # Regenerate PDF with updated data
            from services.prescription_pdf import generate_and_upload_pdf

            rx = supabase_admin.table("prescriptions").select("*").eq(
                "prediction_id", review.prediction_id
            ).single().execute()

            pred_data = supabase_admin.table("predictions").select("patient_id").eq(
                "id", review.prediction_id
            ).single().execute()

            patient = supabase_admin.table("patient_profiles").select("*").eq(
                "user_id", pred_data.data["patient_id"]
            ).execute()

            symptom_log = supabase_admin.table("symptom_logs").select("symptoms").eq(
                "id", supabase_admin.table("predictions").select("symptom_log_id").eq(
                    "id", review.prediction_id
                ).single().execute().data["symptom_log_id"]
            ).single().execute()

            pdf_url = await generate_and_upload_pdf(
                prescription_id=rx.data["id"],
                patient_info=patient.data[0] if patient.data else {"name": "Patient"},
                symptoms=symptom_log.data["symptoms"] if symptom_log.data else "",
                disease=rx.data["disease"],
                medicines=rx.data.get("medicines", ""),
                precautions=json.loads(rx.data["precautions"]) if rx.data.get("precautions") else [],
                tests=json.loads(rx.data["tests"]) if rx.data.get("tests") else [],
                doctor_notes=review.notes,
            )

            if pdf_url:
                supabase_admin.table("prescriptions").update(
                    {"pdf_url": pdf_url}
                ).eq("prediction_id", review.prediction_id).execute()

        return {"message": f"Review submitted: {review.decision}", "status": "success"}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Review error: {str(e)}")
