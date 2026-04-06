# 🏥 Medicare AI — AI Health Assistant

A production-ready AI healthcare system with disease prediction, doctor verification, and prescription management.

## 🛠️ Tech Stack
- **Backend:** Python, FastAPI, PyTorch, Transformers (DistilBERT)
- **Frontend:** Flutter (Mobile + Web)
- **Database & Auth:** Supabase
- **PDF Generation:** ReportLab

---

## 📁 Project Structure

```
project/
├── backend/
│   ├── main.py                    # FastAPI entry + model loading
│   ├── config.py                  # Supabase client config
│   ├── auth.py                    # JWT auth middleware
│   ├── models.py                  # Pydantic request/response models
│   ├── seed_data.py               # Pre-seed users script
│   ├── supabase_schema.sql        # Database schema + RLS
│   ├── disease_info.json          # Disease precautions/tests
│   ├── requirements.txt
│   ├── .env                       # Supabase credentials (you fill in)
│   ├── model/                     # DistilBERT model files
│   ├── routers/
│   │   ├── auth_router.py         # Signup/Login/Me
│   │   ├── patient_router.py      # Profile, Predict, History
│   │   ├── doctor_router.py       # Cases, Review
│   │   └── admin_router.py        # Doctor verification, Users
│   └── services/
│       └── prescription_pdf.py    # PDF generation + upload
│
└── frontend/
    └── lib/
        ├── main.dart
        ├── config/                # Theme, routes, app config
        ├── providers/             # Auth state management
        ├── services/              # API service layer
        └── screens/
            ├── patient/           # 10 patient screens
            ├── doctor/            # 4 doctor screens
            └── admin/             # 3 admin screens
```

---

## 🚀 Setup Guide

### Step 1: Supabase Setup
1. Create a project at [supabase.com](https://supabase.com)
2. Copy your **Project URL**, **anon key**, and **service role key**
3. Go to SQL Editor → Run the contents of `backend/supabase_schema.sql`
4. Go to Storage → Create bucket named `prescriptions` (public access)
5. Enable Email/Password auth in Authentication settings

### Step 2: Backend Setup
```bash
cd backend

# Create .env with your credentials
# SUPABASE_URL=https://xxx.supabase.co
# SUPABASE_KEY=your_anon_key
# SUPABASE_SERVICE_KEY=your_service_role_key

pip install -r requirements.txt
python seed_data.py     # Seeds 1 admin, 3 doctors, 5 patients
python main.py          # Starts at http://0.0.0.0:8000
```

### Step 3: Frontend Setup
```bash
cd frontend

# Update lib/config/app_config.dart with your Supabase credentials + backend URL

flutter pub get
flutter run              # Mobile
flutter run -d chrome    # Web (for doctor/admin panels)
```

---

## 👤 Pre-seeded Users

| Role    | Email                   | Password      |
|---------|-------------------------|---------------|
| Admin   | admin@medicare.ai       | Medicare@123  |
| Doctor  | dr.sharma@medicare.ai   | Medicare@123  |
| Doctor  | dr.patel@medicare.ai    | Medicare@123  |
| Doctor  | dr.khan@medicare.ai     | Medicare@123  |
| Patient | rahul@gmail.com         | Medicare@123  |
| Patient | sneha@gmail.com         | Medicare@123  |

> ⚠️ Doctors must be verified by admin before they can login.

---

## 🔑 API Endpoints

| Method | Endpoint                          | Auth  | Description              |
|--------|-----------------------------------|-------|--------------------------|
| POST   | `/auth/signup`                    | No    | Register patient/doctor  |
| POST   | `/auth/login`                     | No    | Login                    |
| GET    | `/auth/me`                        | Yes   | Current user info        |
| POST   | `/patient/profile`                | Patient | Save profile           |
| POST   | `/patient/predict`                | Patient | AI prediction          |
| GET    | `/patient/history`                | Patient | Prediction history     |
| GET    | `/patient/prescription/{id}`      | Patient | Prescription details   |
| GET    | `/doctor/dashboard`               | Doctor | Dashboard stats        |
| GET    | `/doctor/cases`                   | Doctor | Pending cases          |
| POST   | `/doctor/review`                  | Doctor | Submit review          |
| GET    | `/admin/doctors`                  | Admin | All doctors            |
| POST   | `/admin/doctors/{id}/verify`      | Admin | Verify doctor          |
| GET    | `/admin/users`                    | Admin | All users              |
| POST   | `/predict`                        | No    | Legacy prediction      |

---

## 📋 Workflows

**Patient:** Signup → Profile → Symptoms → AI Prediction → Prescription PDF → View Doctor Review

**Doctor:** Login (if verified) → View Pending Cases → Approve/Modify/Reject → Updated PDF

**Admin:** Login → Verify Doctors → Manage Users
