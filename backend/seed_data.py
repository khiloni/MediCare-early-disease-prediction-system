"""
Medicare AI — Seed Data Script (FINAL FIXED)
Creates users in Supabase Auth + public.users table correctly.

Usage:
    python seed_data.py
"""

import os
import sys
from dotenv import load_dotenv
from supabase import create_client

# ─────────────────────────────────────────────
# 🔐 Load ENV
# ─────────────────────────────────────────────
load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    print("❌ Error: Set SUPABASE_URL and SUPABASE_SERVICE_KEY in .env")
    sys.exit(1)

# Admin client (IMPORTANT: use SERVICE KEY)
admin_client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

DEFAULT_PASSWORD = "Medicare@123"


# ─────────────────────────────────────────────
# 🔍 Check if user exists in AUTH
# ─────────────────────────────────────────────
def get_auth_user(email: str):
    try:
        users = admin_client.auth.admin.list_users()
        for u in users:
            if u.email == email:
                return u
        return None
    except Exception as e:
        print(f"❌ Error checking auth user: {e}")
        return None


# ─────────────────────────────────────────────
# 👤 Create user (AUTH + DB sync)
# ─────────────────────────────────────────────
def create_user(email: str, password: str, role: str) -> str:
    try:
        # ✅ Step 1: Check AUTH
        existing_user = get_auth_user(email)

        if existing_user:
            print(f"  ⚠️ Auth user exists: {email}")
            user_id = existing_user.id

            # ✅ Ensure exists in public.users
            admin_client.table("users").upsert({
                "id": user_id,
                "email": email,
                "role": role,
            }).execute()

            return user_id

        # ✅ Step 2: Create in AUTH
        auth_response = admin_client.auth.admin.create_user({
            "email": email,
            "password": password,
            "email_confirm": True
        })

        if not auth_response.user:
            print(f"  ❌ Failed to create auth user: {email}")
            return None

        user_id = auth_response.user.id

        # ✅ Step 3: Insert into public.users
        admin_client.table("users").insert({
            "id": user_id,
            "email": email,
            "role": role,
        }).execute()

        print(f"  ✅ Created {role}: {email}")
        return user_id

    except Exception as e:
        print(f"  ❌ Error creating {email}: {e}")
        return None


# ─────────────────────────────────────────────
# 🌱 SEED DATA
# ─────────────────────────────────────────────
def seed():
    print("=" * 60)
    print("🏥 Medicare AI — Seeding Database (FINAL)")
    print("=" * 60)

    # ─── 1. Admin ─────────────────────────────
    print("\n📌 Creating Admin...")
    admin_id = create_user("admin@medicare.ai", DEFAULT_PASSWORD, "admin")

    # ─── 2. Doctors ───────────────────────────
    print("\n📌 Creating Doctors...")
    doctors = [
        {"email": "dr.sharma@medicare.ai", "name": "Dr. Priya Sharma", "license": "MCI-2024-001", "spec": "General Medicine"},
        {"email": "dr.patel@medicare.ai", "name": "Dr. Ravi Patel", "license": "MCI-2024-002", "spec": "Pulmonology"},
        {"email": "dr.khan@medicare.ai", "name": "Dr. Aisha Khan", "license": "MCI-2024-003", "spec": "Dermatology"},
    ]

    for doc in doctors:
        doc_id = create_user(doc["email"], DEFAULT_PASSWORD, "doctor")
        if doc_id:
            admin_client.table("doctor_profiles").upsert({
                "user_id": doc_id,
                "name": doc["name"],
                "license_number": doc["license"],
                "specialization": doc["spec"],
                "verified": False,
            }).execute()
            print(f"    → Profile: {doc['name']} ({doc['spec']})")

    # ─── 3. Patients ──────────────────────────
    print("\n📌 Creating Patients...")
    patients = [
        {"email": "rahul@gmail.com", "name": "Rahul Verma", "age": 28, "gender": "Male", "blood": "B+", "allergies": "None"},
        {"email": "sneha@gmail.com", "name": "Sneha Gupta", "age": 34, "gender": "Female", "blood": "A+", "allergies": "Penicillin"},
        {"email": "amit@gmail.com", "name": "Amit Kumar", "age": 45, "gender": "Male", "blood": "O+", "allergies": "Sulfa drugs"},
        {"email": "priya@gmail.com", "name": "Priya Singh", "age": 22, "gender": "Female", "blood": "AB+", "allergies": "None"},
        {"email": "vikram@gmail.com", "name": "Vikram Joshi", "age": 38, "gender": "Male", "blood": "O-", "allergies": "Aspirin"},
    ]

    for pat in patients:
        pat_id = create_user(pat["email"], DEFAULT_PASSWORD, "patient")
        if pat_id:
            admin_client.table("patient_profiles").upsert({
                "user_id": pat_id,
                "name": pat["name"],
                "age": pat["age"],
                "gender": pat["gender"],
                "blood_group": pat["blood"],
                "allergies": pat["allergies"],
            }).execute()
            print(f"    → Profile: {pat['name']} (Age: {pat['age']})")

    print("\n" + "=" * 60)
    print("✅ Seeding Complete!")
    print(f"🔑 Default password: {DEFAULT_PASSWORD}")
    print("=" * 60)


# ─────────────────────────────────────────────
# 🚀 RUN
# ─────────────────────────────────────────────
if __name__ == "__main__":
    seed()