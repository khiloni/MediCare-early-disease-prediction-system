from fastapi import APIRouter, Depends, HTTPException
from auth import require_role
from config import supabase_admin
from models import DoctorVerifyRequest

router = APIRouter(prefix="/admin", tags=["Admin"])


# ─── Dashboard ──────────────────────────────────────────────

@router.get("/dashboard")
async def admin_dashboard(current_user: dict = Depends(require_role("admin"))):
    """Admin dashboard with system stats."""
    try:
        patients = supabase_admin.table("users").select("id", count="exact").eq("role", "patient").execute()
        doctors = supabase_admin.table("users").select("id", count="exact").eq("role", "doctor").execute()
        unverified = supabase_admin.table("doctor_profiles").select("user_id", count="exact").eq("verified", False).execute()
        predictions = supabase_admin.table("predictions").select("id", count="exact").execute()

        return {
            "total_patients": patients.count or 0,
            "total_doctors": doctors.count or 0,
            "unverified_doctors": unverified.count or 0,
            "total_predictions": predictions.count or 0,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Dashboard error: {str(e)}")


# ─── Doctor Verification ───────────────────────────────────

@router.get("/doctors")
async def get_all_doctors(current_user: dict = Depends(require_role("admin"))):
    """List all doctors with verification status."""
    try:
        doctors = supabase_admin.table("doctor_profiles").select(
            "user_id, name, license_number, specialization, verified, status"
        ).execute()

        result = []
        for doc in doctors.data:
            user = supabase_admin.table("users").select("email, created_at").eq(
                "id", doc["user_id"]
            ).single().execute()

            result.append({
                **doc,
                "email": user.data["email"] if user.data else "",
                "created_at": user.data["created_at"] if user.data else "",
            })

        return {"doctors": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Doctors list error: {str(e)}")


@router.post("/doctors/{user_id}/verify")
async def verify_doctor(
    user_id: str,
    request: DoctorVerifyRequest,
    current_user: dict = Depends(require_role("admin"))
):
    """Approve or reject a doctor."""
    try:
        # Check doctor exists
        doc = supabase_admin.table("doctor_profiles").select("user_id").eq(
            "user_id", user_id
        ).execute()

        if not doc.data:
            raise HTTPException(status_code=404, detail="Doctor not found")

        new_status = "approved" if request.verified else "rejected"
        supabase_admin.table("doctor_profiles").update(
            {"verified": request.verified, "status": new_status}
        ).eq("user_id", user_id).execute()

        status = "approved" if request.verified else "rejected"
        return {"message": f"Doctor {status} successfully", "verified": request.verified}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Verification error: {str(e)}")


# ─── User Management ───────────────────────────────────────

@router.get("/users")
async def get_all_users(current_user: dict = Depends(require_role("admin"))):
    """List all users in the system."""
    try:
        users = supabase_admin.table("users").select("*").order("created_at", desc=True).execute()
        return {"users": users.data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Users list error: {str(e)}")


@router.delete("/users/{user_id}")
async def delete_user(
    user_id: str,
    current_user: dict = Depends(require_role("admin"))
):
    """Delete a user (admin only)."""
    try:
        # Don't allow deleting admin
        user = supabase_admin.table("users").select("role").eq("id", user_id).single().execute()
        if user.data and user.data["role"] == "admin":
            raise HTTPException(status_code=403, detail="Cannot delete admin user")

        # Delete from DB (cascades to profiles)
        supabase_admin.table("users").delete().eq("id", user_id).execute()

        return {"message": "User deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Delete error: {str(e)}")
