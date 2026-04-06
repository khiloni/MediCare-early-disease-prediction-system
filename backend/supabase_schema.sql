-- ============================================================
-- MEDICARE AI — Supabase Database Schema
-- Run this in Supabase SQL Editor
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── Core Tables ────────────────────────────────────────────

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('patient', 'doctor', 'admin')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE patient_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    age INT,
    gender TEXT,
    blood_group TEXT,
    allergies TEXT
);

CREATE TABLE doctor_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    license_number TEXT UNIQUE NOT NULL,
    specialization TEXT NOT NULL,
    verified BOOLEAN DEFAULT FALSE
);

CREATE TABLE symptom_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID REFERENCES users(id),
    symptoms TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE predictions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID REFERENCES users(id),
    symptom_log_id UUID REFERENCES symptom_logs(id),
    predicted_disease TEXT,
    confidence NUMERIC,
    status TEXT DEFAULT 'PENDING_DOCTOR_VERIFICATION',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE prescriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prediction_id UUID REFERENCES predictions(id),
    doctor_id UUID REFERENCES users(id),
    disease TEXT,
    medicines TEXT,
    precautions TEXT,
    tests TEXT,
    verification_status TEXT DEFAULT 'PENDING_DOCTOR_VERIFICATION',
    pdf_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE doctor_reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prediction_id UUID REFERENCES predictions(id),
    doctor_id UUID REFERENCES users(id),
    decision TEXT CHECK (decision IN ('APPROVED','MODIFIED','REJECTED')),
    notes TEXT,
    updated_prescription TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ─── Row Level Security (RLS) ──────────────────────────────

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE doctor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE symptom_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE predictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE doctor_reviews ENABLE ROW LEVEL SECURITY;

-- Users: users can read their own row
CREATE POLICY "Users can view own data" ON users
    FOR SELECT USING (auth.uid() = id);

-- Patient profiles: patients can manage own profile
CREATE POLICY "Patients manage own profile" ON patient_profiles
    FOR ALL USING (auth.uid() = user_id);

-- Doctor profiles: doctors can view own profile
CREATE POLICY "Doctors view own profile" ON doctor_profiles
    FOR SELECT USING (auth.uid() = user_id);

-- Symptom logs: patients can manage own logs
CREATE POLICY "Patients manage own symptom logs" ON symptom_logs
    FOR ALL USING (auth.uid() = patient_id);

-- Predictions: patients can view own predictions
CREATE POLICY "Patients view own predictions" ON predictions
    FOR SELECT USING (auth.uid() = patient_id);

-- Predictions: doctors can view all predictions (for review)
CREATE POLICY "Doctors view all predictions" ON predictions
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'doctor')
    );

-- Prescriptions: patients can view own prescriptions
CREATE POLICY "Patients view own prescriptions" ON prescriptions
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM predictions WHERE predictions.id = prescriptions.prediction_id AND predictions.patient_id = auth.uid())
    );

-- Doctor reviews: doctors can manage reviews
CREATE POLICY "Doctors manage reviews" ON doctor_reviews
    FOR ALL USING (auth.uid() = doctor_id);

-- Admin full access policies (using service role key bypasses RLS)
-- No explicit admin policies needed since admin uses service role key
