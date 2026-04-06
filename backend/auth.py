from fastapi import Depends, HTTPException, Header
from config import supabase, supabase_admin


async def get_current_user(authorization: str = Header(...)):
    """
    Validates auth token. Supports both:
    1. Supabase JWT (for patient/doctor)
    2. Custom admin token (for admin)
    """
    try:
        token = authorization.replace("Bearer ", "")

        # First, try Supabase JWT verification
        try:
            user_response = supabase.auth.get_user(token)
            if user_response and user_response.user:
                user = user_response.user
                # Get role from users table
                result = supabase_admin.table("users").select("role").eq("id", str(user.id)).single().execute()
                if not result.data:
                    raise HTTPException(status_code=404, detail="User not found in database")
                return {
                    "user_id": str(user.id),
                    "email": user.email,
                    "role": result.data["role"],
                    "token": token,
                    "auth_type": "supabase",
                }
        except Exception:
            pass  # Not a valid Supabase token, try admin token

        # Second, try custom admin token
        from routers.auth_router import verify_admin_token
        admin_data = verify_admin_token(token)
        if admin_data:
            return {
                "user_id": admin_data["user_id"],
                "email": admin_data["email"],
                "role": "admin",
                "token": token,
                "auth_type": "admin",
            }

        raise HTTPException(status_code=401, detail="Invalid or expired token")

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Authentication failed: {str(e)}")


def require_role(required_role: str):
    """Dependency that checks user role."""
    async def role_checker(current_user: dict = Depends(get_current_user)):
        if current_user["role"] != required_role:
            raise HTTPException(
                status_code=403,
                detail=f"Access denied. Required role: {required_role}"
            )
        return current_user
    return role_checker
