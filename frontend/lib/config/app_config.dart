/// Medicare AI — Application Configuration
class AppConfig {
  // ─── Supabase ─────────────────────────────────────────────
  // ⚠️ Replace with your actual Supabase credentials
  static const String supabaseUrl = 'https://dkhupmtqbibudgurrieb.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRraHVwbXRxYmlidWRndXJyaWViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwNzAyMDAsImV4cCI6MjA4ODY0NjIwMH0.CFg8eqR3_63GHXf-gAht24ng53JiqWeMZdyUVwinUTE';

  // ─── Backend API ──────────────────────────────────────────
  // Use 10.0.2.2 for Android emulator, localhost for web/iOS
  static const String backendUrl = 'http://localhost:8000';

  // ─── App Info ─────────────────────────────────────────────
  static const String appName = 'Medicare AI';
  static const String appVersion = '2.0.0';
  static const String appTagline = 'AI-Powered Health Assistant';
}
