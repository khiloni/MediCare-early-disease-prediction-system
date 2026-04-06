from fastapi import APIRouter, HTTPException, Depends
from config import supabase, supabase_admin
from models import LoginRequest, AuthResponse
from auth import get_current_user
import hashlib
import secrets
import time

router = APIRouter(prefix="/auth", tags=["Authentication"])

# ─── In-memory admin token store (use Redis in production) ────
_admin_tokens = {}

# Pre-configured admin credentials (loaded from DB in production)
ADMIN_EMAIL = "admin@medicare.ai"
ADMIN_PASSWORD_HASH = hashlib.sha256("Medicare@123".encode()).hexdigest()


@router.post("/admin/login")
async def admin_login(request: LoginRequest):
    """Admin-only login — custom backend auth, NOT Supabase."""
    # Verify credentials
    password_hash = hashlib.sha256(request.password.encode()).hexdigest()

    # Check against DB first
    try:
        admin_data = supabase_admin.table("users").select("*").eq(
            "email", request.email
        ).eq("role", "admin").execute()

        if not admin_data.data:
            raise HTTPException(status_code=401, detail="Invalid admin credentials")

        admin_user = admin_data.data[0]

        # For seeded admin, verify with known password hash
        # In production, store hashed passwords in a separate admin_credentials table
        if request.email == ADMIN_EMAIL and password_hash != ADMIN_PASSWORD_HASH:
            raise HTTPException(status_code=401, detail="Invalid admin credentials")

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Admin login error: {str(e)}")

    # Generate custom admin token
    token = secrets.token_hex(32)
    _admin_tokens[token] = {
        "user_id": admin_user["id"],
        "email": admin_user["email"],
        "role": "admin",
        "created_at": time.time(),
    }

    return {
        "access_token": token,
        "user_id": admin_user["id"],
        "email": admin_user["email"],
        "role": "admin",
    }


@router.post("/register-profile")
async def register_profile(data: dict):
    """
    Called AFTER Supabase auth signup.
    Frontend sends Supabase user_id + role + profile data.
    Inserts into users table and role-specific profile table.
    """
    user_id = data.get("user_id")
    email = data.get("email")
    role = data.get("role")

    if not user_id or not email or not role:
        raise HTTPException(status_code=400, detail="user_id, email, and role are required")

    if role not in ("patient", "doctor"):
        raise HTTPException(status_code=400, detail="Role must be 'patient' or 'doctor'")

    try:
        # Check if user already exists in our DB
        existing = supabase_admin.table("users").select("id").eq("id", user_id).execute()
        if existing.data:
            return {"message": "Profile already registered", "user_id": user_id}

        # Insert into users table
        supabase_admin.table("users").insert({
            "id": user_id,
            "email": email,
            "role": role,
        }).execute()

        # Create role-specific profile
        if role == "doctor":
            name = data.get("name", "Doctor Name")
            license_id = data.get("license_id", "PENDING")
            specialization = data.get("specialization", "General")

            # Insert or update
            supabase_admin.table("doctor_profiles").insert({
                "user_id": user_id,
                "name": name,
                "license_number": license_id,
                "specialization": specialization,
                "verified": False,
            }).execute()
        elif role == "patient":
            # Optional: handle patient profile initialization if needed
            pass

        return {"message": "Profile registered successfully", "user_id": user_id}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Registration error: {str(e)}")


@router.get("/me")
async def get_current_user_info(current_user: dict = Depends(get_current_user)):
    """Get current user info from token (works for both Supabase JWT and admin token)."""
    user_id = current_user["user_id"]
    role = current_user["role"]

    result = {
        "user_id": user_id,
        "email": current_user["email"],
        "role": role,
    }

    # Attach profile if exists
    try:
        if role == "patient":
            profile = supabase_admin.table("patient_profiles").select("*").eq("user_id", user_id).execute()
            result["profile"] = profile.data[0] if profile.data else None
        elif role == "doctor":
            profile = supabase_admin.table("doctor_profiles").select("*").eq("user_id", user_id).execute()
            result["profile"] = profile.data[0] if profile.data else None
            # Include verification status
            if result["profile"]:
                result["verified"] = result["profile"].get("verified", False)
    except Exception:
        result["profile"] = None

    return result


@router.get("/role/{user_id}")
async def get_user_role(user_id: str):
    """Fetch user role by Supabase user ID. Called after Supabase auth."""
    try:
        result = supabase_admin.table("users").select("role").eq("id", user_id).execute()
        if not result.data:
            return {"role": None, "exists": False}
        return {"role": result.data[0]["role"], "exists": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching role: {str(e)}")


@router.get("/doctor-status/{user_id}")
async def get_doctor_verification_status(user_id: str):
    """Check if a doctor is verified. Called after Supabase login."""
    try:
        result = supabase_admin.table("doctor_profiles").select("verified").eq("user_id", user_id).execute()
        if not result.data:
            return {"verified": False, "exists": False}
        return {"verified": result.data[0]["verified"], "exists": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")


def verify_admin_token(token: str) -> dict | None:
    """Verify a custom admin token. Returns user data or None."""
    data = _admin_tokens.get(token)
    if not data:
        return None
    # Expire after 24 hours
    if time.time() - data["created_at"] > 86400:
        del _admin_tokens[token]
        return None
    return data
