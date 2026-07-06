# 🏥 Medicare AI — AI Health Assistant

A complete end-to-end production-ready AI healthcare system. It predicts diseases based on symptoms through a Natural Language Processing model and provides doctor-verified prescriptions to patients. The entire workflow connects Patients, an AI Engine, Doctors, and System Admins.

---

## System Workflow

1. **Patient Flow**: Patients enter their medical history, then chat with the AI Health Assistant.
2. **AI Inference**: The NLP model processes symptoms and outputs a predicted disease with confidence metrics.
3. **Draft Prescription**: A draft prescription is created and flagged as `PENDING_DOCTOR_VERIFICATION`.
4. **Doctor Review**: Doctors see pending requests in their dashboard. They can Approve, Modify, or Reject the prediction and prescription.
5. **Final Prescription Delivery**: Once approved/modified, the verified prescription is delivered to the patient and generated as a PDF on AWS S3.
6. **Admin Panel**: Admins manage doctor accounts, verifying their licenses before they are allowed onto the platform.

---

## Architecture & Tech Stack

* **Patient App**: Flutter (Mobile First)
* **Doctor Portal**: Flutter
* **Admin Portal**: Flutter
* **Backend API**: Python FastAPI
* **AI Model Pipeline**: HuggingFace Transformers, PyTorch
* **Database**: PostgreSQL (Supabase)
* **Authentication**: Supabase Auth (JWT & RBAC)
* **Storage**: AWS S3 (for Prescription PDFs)

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

Follow these steps exactly to get the entire architecture running locally.

### 1. Database Configuration
1. Create a project on [Supabase.com](https://supabase.com/).
2. Navigate to the SQL Editor and run the queries found in `database/schema.sql`.
3. Go to **Authentication -> Providers** and enable **Email/Password**.
4. Retrieve your Supabase URL and Anon Key from project settings.

### 2. Backend Server (FastAPI)
The backend acts as the core gateway for all interactions and ML inference.

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Create and activate a Virtual Environment:
   * **Windows**: `python -m venv venv` and then `venv\Scripts\activate`
   * **Mac/Linux**: `python3 -m venv venv` and then `source venv/bin/activate`
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Create a `.env` file inside the `backend/` directory:
   ```env
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   JWT_SECRET=supersecretkey
   AWS_ACCESS_KEY_ID=your_key
   AWS_SECRET_ACCESS_KEY=your_secret
   S3_BUCKET_NAME=your_bucket
   ```
5. Start the API Local Server:
   ```bash
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```
   *The Swagger UI documentation will now be available at `http://localhost:8000/docs`.*

### 3. Running the Flutter Apps
There are three isolated Flutter applications in this system. Ensure you have the Flutter SDK installed on your machine.
By default, the apps point to `http://10.0.2.2:8000` (the Android Emulator alias for localhost). If testing on a physical device, update `baseUrl` in `lib/services/api_service.dart` to your computer's local network IP.

#### Running the Patient App
```bash
cd patient_app
flutter pub get
flutter run
```

#### Running the Doctor App
```bash
cd doctor_app
flutter pub get
flutter run
```

#### Running the Admin App
```bash
cd admin_app
flutter pub get
flutter run
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

## AI Model Configuration
We are loading a highly precise NLP HuggingFace Transformer model without the need for cloud inference limits. The `main.py` script automatically targets the `.safetensors` model stored locally at `<root>/model/`.

If you do NOT have the model downloaded, or the predictor fails to locate `model.safetensors`, the system gracefully falls back into a mocked prediction loop to allow your UI flows to continue working without breaking during debugging.

