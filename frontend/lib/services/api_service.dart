import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Service for backend API calls (business logic only — auth is handled by Supabase directly)
class ApiService {
  static const String _baseUrl = AppConfig.backendUrl;

  // ─── Auth Helpers (backend-assisted) ──────────────────────

  /// Fetch user role from backend by Supabase user ID
  Future<Map<String, dynamic>> getUserRole(String userId) async {
    return _get('/auth/role/$userId');
  }

  /// Check doctor verification status
  Future<Map<String, dynamic>> getDoctorStatus(String userId) async {
    return _get('/auth/doctor-status/$userId');
  }

  /// Register user profile after Supabase signup
  Future<Map<String, dynamic>> registerProfile(Map<String, dynamic> data) async {
    return _post('/auth/register-profile', data);
  }

  /// Admin-only login (custom backend — NOT Supabase)
  Future<Map<String, dynamic>> adminLogin({
    required String email,
    required String password,
  }) async {
    return _post('/auth/admin/login', {'email': email, 'password': password});
  }

  /// Get current user info (works with both Supabase JWT and admin token)
  Future<Map<String, dynamic>> getCurrentUser(String token) async {
    return _get('/auth/me', token: token);
  }

  // ─── Patient ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getPatientProfile(String token) async {
    return _get('/patient/profile', token: token);
  }

  Future<Map<String, dynamic>> savePatientProfile(
    String token, Map<String, dynamic> profile,
  ) async {
    return _post('/patient/profile', profile, token: token);
  }

  Future<Map<String, dynamic>> predictDisease(String token, String symptoms) async {
    return _post('/patient/predict', {'symptoms': symptoms}, token: token);
  }

  Future<Map<String, dynamic>> getHistory(String token) async {
    return _get('/patient/history', token: token);
  }

  Future<Map<String, dynamic>> getPrescription(String token, String predictionId) async {
    return _get('/patient/prescription/$predictionId', token: token);
  }

  // ─── Doctor ───────────────────────────────────────────────

  Future<Map<String, dynamic>> getDoctorDashboard(String token) async {
    return _get('/doctor/dashboard', token: token);
  }

  Future<Map<String, dynamic>> getDoctorCases(String token) async {
    return _get('/doctor/cases', token: token);
  }

  Future<Map<String, dynamic>> getCaseDetail(String token, String predictionId) async {
    return _get('/doctor/cases/$predictionId', token: token);
  }

  Future<Map<String, dynamic>> submitReview(
    String token, Map<String, dynamic> review,
  ) async {
    return _post('/doctor/review', review, token: token);
  }

  // ─── Admin ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAdminDashboard(String token) async {
    return _get('/admin/dashboard', token: token);
  }

  Future<Map<String, dynamic>> getAllDoctors(String token) async {
    return _get('/admin/doctors', token: token);
  }

  Future<Map<String, dynamic>> verifyDoctor(
    String token, String userId, bool verified,
  ) async {
    return _post('/admin/doctors/$userId/verify', {'verified': verified}, token: token);
  }

  Future<Map<String, dynamic>> getAllUsers(String token) async {
    return _get('/admin/users', token: token);
  }

  // ─── HTTP Helpers ─────────────────────────────────────────

  Future<Map<String, dynamic>> _get(String path, {String? token}) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse('$_baseUrl$path'),
        headers: headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Request failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path, Map<String, dynamic> body, {String? token}
  ) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Request failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }
}
