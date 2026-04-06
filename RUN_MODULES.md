# 🚀 How to Run Medicare AI Modules

Follow these steps to run each part of the system independently.

## 1. Start the Backend (FastAPI)
Open a terminal in the `backend` directory and run:
```bash
python main.py
```
*The API will be available at `http://localhost:8000`.*

---

## 2. Start the Frontend Modules (Flutter)
Open a terminal in the `frontend` directory. 

### 👨‍⚕️ Patient Module (Mobile/Web)
Run this command to launch the Patient app:
```bash
flutter run -t lib/main_patient.dart
```

### 🩺 Doctor Module (Web)
Run this command to launch the Doctor app:
```bash
flutter run -t lib/main_doctor.dart -d chrome
```

### 🛡️ Admin Module (Web)
Run this command to launch the Admin app:
```bash
flutter run -t lib/main_admin.dart -d chrome
```

---

## ⚠️ Important Configuration
1. **Supabase**: Ensure you have applied the [fix_schema.sql](file:///d:/Degree_GLS/sem%205/Capstone/project/backend/fix_schema.sql) in your Supabase SQL Editor.
2. **Ports**: If you run on a different port than `8000`, update `backendUrl` in [app_config.dart](file:///d:/Degree_GLS/sem%205/Capstone/project/frontend/lib/config/app_config.dart).
3. **Redirects**: Ensure your Supabase Dashboard "Site URL" matches your local Flutter port (usually `http://localhost:XXXX`). See [SUPABASE_CONFIG.md](file:///d:/Degree_GLS/sem%205/Capstone/project/SUPABASE_CONFIG.md) for details.
