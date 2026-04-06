from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime


# ─── Auth Models ─────────────────────────────────────────────

class SignupRequest(BaseModel):
    email: EmailStr
    password: str
    confirm_password: str
    role: str  # 'patient' or 'doctor'
    # Doctor-only fields
    license_id: Optional[str] = None
    name: Optional[str] = None
    specialization: Optional[str] = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class AuthResponse(BaseModel):
    access_token: str
    user_id: str
    email: str
    role: str


# ─── Patient Models ─────────────────────────────────────────

class PatientProfileCreate(BaseModel):
    name: str
    age: Optional[int] = None
    gender: Optional[str] = None
    blood_group: Optional[str] = None
    allergies: Optional[str] = None


class PatientProfileResponse(BaseModel):
    user_id: str
    name: str
    age: Optional[int] = None
    gender: Optional[str] = None
    blood_group: Optional[str] = None
    allergies: Optional[str] = None


# ─── Doctor Models ───────────────────────────────────────────

class DoctorProfileResponse(BaseModel):
    user_id: str
    name: str
    license_number: str
    specialization: str
    verified: bool


# ─── Symptom / Prediction Models ────────────────────────────

class SymptomInput(BaseModel):
    symptoms: str


class PredictionResponse(BaseModel):
    prediction_id: str
    disease: str
    confidence: float
    precautions: list[str]
    recommended_tests: list[str]
    medicines: str
    status: str
    prescription_id: Optional[str] = None
    pdf_url: Optional[str] = None


# ─── Prescription Models ────────────────────────────────────

class PrescriptionResponse(BaseModel):
    id: str
    prediction_id: str
    disease: str
    medicines: Optional[str] = None
    precautions: Optional[str] = None
    tests: Optional[str] = None
    verification_status: str
    pdf_url: Optional[str] = None
    doctor_id: Optional[str] = None
    created_at: Optional[str] = None


# ─── Doctor Review Models ───────────────────────────────────

class DoctorReviewRequest(BaseModel):
    prediction_id: str
    decision: str  # APPROVED, MODIFIED, REJECTED
    notes: Optional[str] = None
    updated_medicines: Optional[str] = None
    updated_precautions: Optional[str] = None
    updated_tests: Optional[str] = None


class DoctorReviewResponse(BaseModel):
    id: str
    prediction_id: str
    doctor_id: str
    decision: str
    notes: Optional[str] = None
    updated_prescription: Optional[str] = None
    created_at: Optional[str] = None


# ─── History Models ─────────────────────────────────────────

class HistoryItem(BaseModel):
    prediction_id: str
    symptoms: str
    disease: str
    confidence: float
    status: str
    verification_status: str
    pdf_url: Optional[str] = None
    created_at: str


# ─── Admin Models ───────────────────────────────────────────

class DoctorVerifyRequest(BaseModel):
    verified: bool


class UserListItem(BaseModel):
    id: str
    email: str
    role: str
    created_at: Optional[str] = None
