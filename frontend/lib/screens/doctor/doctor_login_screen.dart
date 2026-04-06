import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/error_box.dart';

class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({super.key});

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _showSignup = false;

  // Signup fields
  final _nameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _specController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _licenseController.dispose();
    _specController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.clearError();

    final success = await auth.loginWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
      expectedRole: 'doctor',
    );

    if (!mounted) return;
    if (success && auth.isDoctorApproved) {
      context.go('/dashboard');
    }
    // If success but not approved → UI below handles the pending state
    // If failed (rejected) → error is shown via ErrorBox
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.clearError();

    final success = await auth.signupWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: 'doctor',
      name: _nameController.text.trim(),
      licenseId: _licenseController.text.trim(),
      specialization: _specController.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      setState(() => _showSignup = false);
      // successMessage will be displayed via SuccessBox
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    // ─── LOGGED IN + PENDING APPROVAL → blocking screen ───
    if (auth.isLoggedIn && auth.role == 'doctor' && auth.doctorStatus == 'pending') {
      return _buildPendingScreen(auth);
    }

    // ─── LOGGED IN + REJECTED → blocking screen ───
    if (auth.isLoggedIn && auth.role == 'doctor' && auth.doctorStatus == 'rejected') {
      return _buildRejectedScreen(auth);
    }

    // ─── LOGIN / SIGNUP FORM ───
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.medical_services,
                        size: 64, color: AppTheme.primaryBlue),
                    const SizedBox(height: 16),
                    Text(
                      _showSignup ? 'Doctor Registration' : 'Doctor Portal',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _showSignup
                          ? 'Create your doctor account'
                          : 'Sign in to your doctor portal',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppTheme.greyText),
                    ),
                    const SizedBox(height: 28),

                    // Error display
                    if (auth.error != null) ...[
                      ErrorBox(
                        message: auth.error!,
                        onDismiss: () => auth.clearError(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Success display
                    if (auth.successMessage != null) ...[
                      SuccessBox(message: auth.successMessage!),
                      const SizedBox(height: 20),
                    ],

                    // Signup-only fields
                    if (_showSignup) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person_outlined)),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _licenseController,
                        decoration: const InputDecoration(
                            labelText: 'License ID',
                            prefixIcon: Icon(Icons.badge_outlined)),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter license ID'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _specController,
                        decoration: const InputDecoration(
                            labelText: 'Specialization',
                            prefixIcon: Icon(Icons.local_hospital_outlined)),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter specialization'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined)),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter valid email'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Min 6 characters' : null,
                    ),

                    // Confirm password (signup only)
                    if (_showSignup) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: Icon(Icons.lock_outlined)),
                        validator: (v) => v != _passwordController.text
                            ? 'Passwords do not match'
                            : null,
                      ),
                    ],

                    // Forgot password (login only)
                    if (!_showSignup)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/forgot-password'),
                          child: Text('Forgot Password?',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: AppTheme.primaryBlue)),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Action button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: auth.isLoading
                            ? null
                            : (_showSignup ? _signup : _login),
                        child: auth.isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(_showSignup ? 'Create Account' : 'Sign In'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Toggle login/signup
                    TextButton(
                      onPressed: () => setState(() {
                        _showSignup = !_showSignup;
                        auth.clearError();
                      }),
                      child: Text(
                        _showSignup
                            ? 'Already have an account? Sign In'
                            : 'New doctor? Register here',
                        style: GoogleFonts.inter(color: AppTheme.primaryBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── PENDING APPROVAL SCREEN ───
  Widget _buildPendingScreen(AuthProvider auth) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top_rounded,
                  size: 80, color: AppTheme.warningOrange),
              const SizedBox(height: 24),
              Text(
                'Pending Approval',
                style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkText),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.warningOrange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppTheme.warningOrange, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your account is pending admin approval. You will be notified once approved.',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.warningOrange,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => auth.init(expectedRole: 'doctor'),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check Status'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => auth.logout(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.greyText),
                  child: const Text('Logout / Switch Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── REJECTED SCREEN ───
  Widget _buildRejectedScreen(AuthProvider auth) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cancel_rounded,
                  size: 80, color: AppTheme.errorRed),
              const SizedBox(height: 24),
              Text(
                'Account Rejected',
                style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkText),
              ),
              const SizedBox(height: 16),
              ErrorBox(
                message:
                    'Your account has been rejected by admin. Please contact support if you believe this is an error.',
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => auth.logout(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.greyText),
                  child: const Text('Logout / Switch Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
