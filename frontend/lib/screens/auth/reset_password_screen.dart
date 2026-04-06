import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ ADDED
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/error_box.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  bool _isDone = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    // _handleRecovery(); // REMOVED: Conflicted with AuthProvider
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final supabase = Supabase.instance.client;

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception("Session expired. Please request a new link.");
      }

      final success = await auth.updatePassword(
        _passwordController.text.trim(),
      );
      
      if (!success) {
        throw Exception(auth.error ?? "Failed to update password");
      }

      auth.clearPasswordRecovery();

      setState(() {
        _isSubmitting = false;
        _isDone = true;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.go('/login');
      });

    } catch (e) {
      auth.clearError();
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _isDone
                  ? _buildSuccessState()
                  : _buildFormState(auth),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 52,
              color: AppTheme.successGreen,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Password Updated!',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your password has been changed successfully.\nRedirecting you to login…',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppTheme.greyText,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.login_rounded, size: 20),
              label: const Text('Go to Login'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormState(AuthProvider auth) {
    final hasRecoverySession =
        auth.isPasswordRecovery;
        //  || Uri.base.queryParameters.containsKey('code');

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: AppTheme.cardShadow,
      ),
      child: hasRecoverySession
          ? _buildPasswordForm(auth)
          : _buildInvalidLinkState(),
    );
  }

  Widget _buildInvalidLinkState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppTheme.errorRed.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.link_off_rounded,
            size: 48,
            color: AppTheme.errorRed,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Link Expired or Invalid',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkText,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'This password reset link has expired or is invalid.\nPlease request a new one.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AppTheme.greyText,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.go('/forgot-password'),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Request New Link'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go('/login'),
          child: Text(
            'Back to Login',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordForm(AuthProvider auth) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppTheme.elevatedShadow,
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Set New Password',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a strong password with at least 6 characters.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.greyText),
            
          ),
          const SizedBox(height: 32),

          if (auth.error != null) ...[
            ErrorBox(
              message: auth.error!,
              onDismiss: auth.clearError,
            ),
            const SizedBox(height: 20),
          ],

        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'New Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please confirm your password';
                if (v != _passwordController.text) return 'Passwords do not match';
                return null;
              },
          ),

          const SizedBox(height: 32),

          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Update Password'),
            ),
          ),
        ],
      ),
    );
  }
}