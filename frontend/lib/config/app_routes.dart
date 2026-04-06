import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

// Shared auth screens
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/auth/reset_password_screen.dart';

// Patient screens
import '../screens/patient/login_screen.dart';
import '../screens/patient/signup_screen.dart';
import '../screens/patient/profile_setup_screen.dart';
import '../screens/patient/dashboard_screen.dart';
import '../screens/patient/symptom_form_screen.dart';
import '../screens/patient/prediction_result_screen.dart';
import '../screens/patient/prescription_screen.dart';
import '../screens/patient/history_screen.dart';
import '../screens/patient/profile_screen.dart';

// Doctor screens
import '../screens/doctor/doctor_login_screen.dart';
import '../screens/doctor/doctor_dashboard_screen.dart';
import '../screens/doctor/pending_cases_screen.dart';
import '../screens/doctor/case_detail_screen.dart';

// Admin screens
import '../screens/admin/admin_login_screen.dart';
import '../screens/admin/doctor_verification_screen.dart';
import '../screens/admin/user_management_screen.dart';

class AppRoutes {
  static GoRouter patientRouter(AuthProvider auth) {
    return GoRouter(
      initialLocation: '/login',
      refreshListenable: auth,
      redirect: (context, state) {
        if (!auth.isInitialized) return null;

        final path = state.uri.path;

        // 1. Critical Fix: Enforce recovery session redirect universally.
        if (auth.isPasswordRecovery) {
          if (path != '/reset-password') return '/reset-password';
          return null; // allow rendering the reset-password screen
        }

        final isPublicPage = path == '/login' ||
            path == '/signup' ||
            path == '/forgot-password' ||
            path == '/verify-email' ||
            path == '/reset-password' ||
            path == '/profile-setup';

        final loggedIn = auth.isLoggedIn && auth.role == 'patient';

        if (loggedIn && (path == '/login' || path == '/signup')) {
          return '/dashboard';
        }

        if (!loggedIn && !isPublicPage && !auth.isLoading) {
          return '/login';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
        GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
        GoRoute(path: '/verify-email', builder: (_, __) => const VerifyEmailScreen()),
        GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordScreen()),
        GoRoute(path: '/profile-setup', builder: (_, __) => const ProfileSetupScreen()),
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/symptoms', builder: (_, __) => const SymptomFormScreen()),
        GoRoute(
          path: '/result',
          builder: (context, state) {
            final result = state.extra as Map<String, dynamic>?;
            return PredictionResultScreen(result: result ?? {});
          },
        ),
        GoRoute(
          path: '/prescription/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return PrescriptionScreen(predictionId: id);
          },
        ),
        GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    );
  }

  static GoRouter doctorRouter(AuthProvider auth) {
    return GoRouter(
      initialLocation: '/login',
      refreshListenable: auth,
      redirect: (context, state) {
        if (!auth.isInitialized) return null;

        final path = state.uri.path;

        // 1. Critical Fix: Enforce recovery session redirect universally.
        if (auth.isPasswordRecovery) {
          if (path != '/reset-password') return '/reset-password';
          return null; // allow rendering the reset-password screen
        }

        final isAuthPage = path == '/login' ||
            path == '/forgot-password' ||
            path == '/reset-password';

        final loggedIn = auth.isLoggedIn && auth.role == 'doctor';

        if (loggedIn && !auth.isDoctorApproved) {
          if (path != '/login') return '/login';
          return null;
        }

        if (loggedIn && auth.isDoctorApproved && isAuthPage) {
          return '/dashboard';
        }

        if (!loggedIn && !isAuthPage && !auth.isLoading) {
          return '/login';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const DoctorLoginScreen()),
        GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
        GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordScreen()),
        GoRoute(path: '/dashboard', builder: (_, __) => const DoctorDashboardScreen()),
        GoRoute(path: '/cases', builder: (_, __) => const PendingCasesScreen()),
        GoRoute(
          path: '/cases/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return CaseDetailScreen(predictionId: id);
          },
        ),
      ],
    );
  }

  static GoRouter adminRouter(AuthProvider auth) {
    return GoRouter(
      initialLocation: '/login',
      refreshListenable: auth,
      redirect: (context, state) {
        if (!auth.isInitialized) return null;

        final path = state.uri.path;

        // 1. Critical Fix: Enforce recovery session redirect universally.
        if (auth.isPasswordRecovery) {
          if (path != '/reset-password') return '/reset-password';
          return null; // allow rendering the reset-password screen
        }

        final loggedIn = auth.isLoggedIn && auth.role == 'admin';

        final isLoginPage = path == '/login' ||
            path == '/forgot-password' ||
            path == '/reset-password';

        if (loggedIn && isLoginPage) return '/doctors';
        if (!loggedIn && !isLoginPage && !auth.isLoading) return '/login';

        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const AdminLoginScreen()),
        GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
        GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordScreen()),
        GoRoute(path: '/doctors', builder: (_, __) => const DoctorVerificationScreen()),
        GoRoute(path: '/users', builder: (_, __) => const UserManagementScreen()),
      ],
    );
  }
}