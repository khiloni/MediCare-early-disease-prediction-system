import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mail_outline_rounded, size: 100, color: AppTheme.primaryBlue),
              const SizedBox(height: 32),
              Text(
                'Verify Your Email',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.darkText),
              ),
              const SizedBox(height: 16),
              Text(
                'We\'ve sent a verification link to\n${auth.email}\n\nPlease check your email and click the link to continue.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 16, color: AppTheme.greyText, height: 1.5),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => auth.init(expectedRole: auth.role),
                  child: const Text('I\'ve Verified, Refresh Status'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => auth.logout(),
                child: Text(
                  'Use a different email / Logout',
                  style: GoogleFonts.inter(color: AppTheme.errorRed),
                ),
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  auth.error!,
                  style: GoogleFonts.inter(color: AppTheme.errorRed, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
