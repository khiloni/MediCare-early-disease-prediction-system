import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Production-ready AuthProvider for Medicare AI.
///
/// Design principles:
/// - Patient: email verification required before login
/// - Doctor: NO email verification, but admin approval required
/// - Admin: Supabase auth with role check, no extra verification
///
/// Doctor statuses: 'pending' | 'approved' | 'rejected'
class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─── State ───────────────────────────────────────
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  String? _successMessage;

  String? _userId;
  String? _email;
  String? _role;
  bool _isEmailVerified = false;
  String _doctorStatus = 'pending'; // 'pending' | 'approved' | 'rejected'

  /// True when Supabase fires AuthChangeEvent.passwordRecovery.
  /// Used by GoRouter to allow unauthenticated access to /reset-password.
  bool _isPasswordRecovery = false;

  // ─── Getters ─────────────────────────────────────
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  String? get successMessage => _successMessage;

  String? get userId => _userId;
  String? get email => _email;
  String? get role => _role;
  String? get token => _supabase.auth.currentSession?.accessToken;

  bool get isLoggedIn => _userId != null;
  bool get isEmailVerified => _isEmailVerified;
  String get doctorStatus => _doctorStatus;
  bool get isPasswordRecovery => _isPasswordRecovery;

  /// Used by doctor router — true only if status == 'approved'
  bool get isDoctorApproved => _doctorStatus == 'approved';

  /// Used by router guards for backward compat
  bool get isVerified => isDoctorApproved;

  void setPasswordRecovery(bool value) {
  _isPasswordRecovery = value;
  notifyListeners();
}

  // ═══════════════════════════════════════════════════
  // INIT (session restore on app start)
  // ═══════════════════════════════════════════════════
  Future<void> init({String? expectedRole}) async {
    _isLoading = true;
    notifyListeners();

    // ─── Listen for auth state changes (runs for the lifetime of the app) ───
    // This is the CRITICAL listener that catches AuthChangeEvent.passwordRecovery.
    // Supabase SDK fires this when it processes the ?code= token in the URL.
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.passwordRecovery) {
        // User arrived via reset-password email link.
        // Set the flag — GoRouter will redirect them to /reset-password.
        _isPasswordRecovery = true;
        _userId = session?.user.id;
        _email = session?.user.email;
        notifyListeners();
      } else if (event == AuthChangeEvent.signedIn && !_isPasswordRecovery) {
        // Normal sign-in (not a recovery flow) — update state.
        if (session != null) {
          _userId = session.user.id;
          _email = session.user.email;
          _isEmailVerified = session.user.emailConfirmedAt != null;
        }
        notifyListeners();
      } else if (event == AuthChangeEvent.signedOut) {
        _resetState();
        notifyListeners();
      } else if (event == AuthChangeEvent.userUpdated) {
        // Password was updated — session refreshed.
        _isPasswordRecovery = false;
        notifyListeners();
      }
    });

    final session = _supabase.auth.currentSession;

    if (session != null) {
      _userId = session.user.id;
      _email = session.user.email;
      _isEmailVerified = session.user.emailConfirmedAt != null;

      await _loadUserProfile();

      // Role restriction: if user opened wrong portal, clear session.
      // SKIP this check if we are in the middle of a password recovery flow
      // (the recovery session has no role profile loaded anyway).
      if (!_isPasswordRecovery &&
          expectedRole != null &&
          _role != null &&
          _role != expectedRole) {
        await logout();
      }
    }

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  /// Call this after a successful password update to clear the recovery flag.
  void clearPasswordRecovery() {
    _isPasswordRecovery = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════
  // LOGIN (Patient / Doctor)
  // ═══════════════════════════════════════════════════
  Future<bool> loginWithEmail(
    String emailInput,
    String password, {
    String? expectedRole,
  }) async {
    try {
      _startLoading();

      final res = await _supabase.auth.signInWithPassword(
        email: emailInput,
        password: password,
      );

      final user = res.user;
      if (user == null) throw Exception("Login failed");

      _userId = user.id;
      _email = user.email;
      _isEmailVerified = user.emailConfirmedAt != null;

      await _loadUserProfile();

      // ─── ROLE CHECK ───
      if (expectedRole != null && _role != expectedRole) {
        await logout();
        throw Exception("Access denied. This account is registered as '${_role ?? 'unknown'}'.");
      }

      // ─── PATIENT: email verification required ───
      if (_role == 'patient' && !_isEmailVerified) {
        await logout();
        throw Exception("Please verify your email before logging in.");
      }

      // ─── DOCTOR: check approval status ───
      if (_role == 'doctor') {
        if (_doctorStatus == 'rejected') {
          await logout();
          throw Exception("Your account has been rejected by admin.");
        }
        // 'pending' is allowed to login but UI will block dashboard access
      }

      return true;
    } on AuthException catch (e) {
      _error = _mapAuthError(e);
      return false;
    } catch (e) {
      _error = _parseError(e);
      return false;
    } finally {
      _stopLoading();
    }
  }

  // ═══════════════════════════════════════════════════
  // ADMIN LOGIN (Supabase auth + role check)
  // ═══════════════════════════════════════════════════
  Future<bool> adminLogin(String emailInput, String password) async {
    try {
      _startLoading();

      final res = await _supabase.auth.signInWithPassword(
        email: emailInput,
        password: password,
      );

      final user = res.user;
      if (user == null) throw Exception("Login failed");

      _userId = user.id;
      _email = user.email;
      _isEmailVerified = true; // Admin doesn't need email verification

      await _loadUserProfile();

      if (_role == null) {
        throw Exception("User role not found in database.");
      }

      if (_role != 'admin') {
        await logout();
        throw Exception("Access denied. You are registered as '$_role'.");
      }

      return true;
    } on AuthException catch (e) {
      _error = _mapAuthError(e);
      return false;
    } catch (e) {
      _error = _parseError(e);
      return false;
    } finally {
      _stopLoading();
    }
  }

  // ═══════════════════════════════════════════════════
  // SIGNUP
  // ═══════════════════════════════════════════════════
  Future<bool> signupWithEmail({
    required String email,
    required String password,
    required String role,
    String? name,
    String? licenseId,
    String? specialization,
  }) async {
    try {
      _startLoading();

      // STEP 1: Create Supabase Auth user (sends verification email)
      // The DB trigger `handle_new_user` automatically inserts into public.users
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'role': role}, // passed to trigger via raw_user_meta_data
      );

      final user = res.user;
      if (user == null) throw Exception("Signup failed");

      final uid = user.id;

      await _supabase.auth.refreshSession();
      await Future.delayed(Duration(milliseconds: 500));

      // STEP 2: Ensure public.users row exists (trigger should have done this,
      // but we upsert to be safe — avoids FK violation on profiles)
      // await _supabase.from('users').upsert({
      //   'id': uid,
      //   'email': email,
      //   'role': role,
      // });

      // STEP 3: Create role-specific profile
      if (role == 'doctor') {
        await _supabase.from('doctor_profiles').insert({
          'user_id': uid,
          'name': (name == null || name.isEmpty) ? 'Doctor' : name,
          'license_number': licenseId ?? '',
          'specialization': specialization ?? 'General',
          'verified': false,
          'status': 'pending',
        });

        _successMessage =
            "Account created! Your account is pending admin approval.";
      } else {
        // Patient profile — minimal insert, full profile in profile-setup
        await _supabase.from('patient_profiles').upsert({
          'user_id': uid,
          'name': (name == null || name.isEmpty) ? 'Patient' : name,
        });

        _successMessage =
            "Account created! Please verify your email before logging in.";
      }

      // Sign out after signup so user must verify email (patient) or wait for approval (doctor)
      await _supabase.auth.signOut();

      return true;
    } on AuthException catch (e) {
      _error = _mapAuthError(e);
      return false;
    } on PostgrestException catch (e) {
      if (e.message.contains("duplicate") ||
          e.message.contains("already exists")) {
        _error = "This email is already registered.";
      } else {
        _error = "Database error: ${e.message}";
  }
  return false;
} catch (e) {
      _error = _parseError(e);
      return false;
    } finally {
      _stopLoading();
    }
  }

  // ═══════════════════════════════════════════════════
  // FORGOT PASSWORD
  // ═══════════════════════════════════════════════════
  Future<bool> forgotPassword(String email) async {
    try {
      _startLoading();

      // Dynamically resolve the app's current origin (scheme + host + port).
      // For Flutter Web, Uri.base gives the actual browser URL regardless of
      // which port the dev server chose. This fixes the hardcoded port problem.
      // In production, this will be your deployed domain (e.g. https://yourapp.com).
      final origin = kIsWeb
          ? Uri.base.origin // e.g. http://localhost:52341
          : 'http://localhost'; // fallback for native (not used for reset)

      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: '$origin/reset-password',
      );

      _successMessage = "Password reset link sent to $email";
      return true;
    } on AuthException catch (e) {
      _error = _mapAuthError(e);
      return false;
    } catch (e) {
      _error = "Failed to send reset email. Please try again.";
      return false;
    } finally {
      _stopLoading();
    }
  }

  /// Alias for screens that use sendResetLink
  Future<bool> sendResetLink(String email) => forgotPassword(email);

  /// Update password (called after deep-link from reset email)
  Future<bool> updatePassword(String newPassword) async {
    try {
      _startLoading();

      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      _successMessage = "Password updated successfully!";
      return true;
    } on AuthException catch (e) {
      _error = _mapAuthError(e);
      return false;
    } catch (e) {
      _error = "Failed to update password.";
      return false;
    } finally {
      _stopLoading();
    }
  }

  // ═══════════════════════════════════════════════════
  // LOGOUT
  // ═══════════════════════════════════════════════════
  Future<void> logout() async {
    await _supabase.auth.signOut();
    _resetState();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════
  // INTERNAL: Load user profile from DB
  // ═══════════════════════════════════════════════════
  Future<void> _loadUserProfile() async {
    if (_userId == null) return;

    try {
      final res = await _supabase
          .from('users')
          .select()
          .eq('id', _userId!)
          .maybeSingle();

      if (res == null) return;

      _role = res['role'];

      // Doctor: fetch approval status
      if (_role == 'doctor') {
        final doc = await _supabase
            .from('doctor_profiles')
            .select('verified, status')
            .eq('user_id', _userId!)
            .maybeSingle();

        if (doc != null) {
          // Use 'status' column if available, fall back to 'verified' boolean
          final status = doc['status'] as String?;
          if (status != null && status.isNotEmpty) {
            _doctorStatus = status;
          } else {
            _doctorStatus = (doc['verified'] == true) ? 'approved' : 'pending';
          }
        } else {
          _doctorStatus = 'pending';
        }
      }
    } catch (e) {
      debugPrint("Error loading user profile: $e");
    }
  }

  // ═══════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════
  void clearError() {
    _error = null;
    _successMessage = null;
    notifyListeners();
  }

  void _startLoading() {
    _isLoading = true;
    _error = null;
    _successMessage = null;
    notifyListeners();
  }

  void _stopLoading() {
    _isLoading = false;
    notifyListeners();
  }

  void _resetState() {
    _userId = null;
    _email = null;
    _role = null;
    _isEmailVerified = false;
    _doctorStatus = 'pending';
    _isPasswordRecovery = false;
    _error = null;
    _successMessage = null;
  }

  String _mapAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains("already registered") ||
        msg.contains("exists") ||
        msg.contains("user_already_exists")) {
      return "This email is already registered. Please sign in instead.";
    }
    if (msg.contains("invalid login credentials") ||
        msg.contains("invalid_credentials")) {
      return "Invalid email or password.";
    }
    if (msg.contains("email not confirmed")) {
      return "Please verify your email before logging in.";
    }
    if (msg.contains("weak_password") || msg.contains("weak password")) {
      return "Password is too weak. Use at least 6 characters.";
    }
    if (msg.contains("rate_limit") || msg.contains("too many")) {
      return "Too many attempts. Please wait a moment and try again.";
    }
    return e.message;
  }

  String _parseError(dynamic e) {
    final msg = e.toString();

    if (msg.contains("user_already_exists")) {
      return "This email is already registered. Please sign in instead.";
    }
    if (msg.contains("Invalid login credentials")) {
      return "Invalid email or password.";
    }
    if (msg.contains("Email not confirmed")) {
      return "Please verify your email before logging in.";
    }
    if (msg.contains("Exception: ")) {
      return msg.replaceFirst("Exception: ", "");
    }

    return "Something went wrong. Please try again.";
  }
}