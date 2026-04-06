import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class SymptomFormScreen extends StatefulWidget {
  const SymptomFormScreen({super.key});

  @override
  State<SymptomFormScreen> createState() => _SymptomFormScreenState();
}

class _SymptomFormScreenState extends State<SymptomFormScreen> {
  final _symptomController = TextEditingController();
  final ApiService _api = ApiService();
  bool _isLoading = false;

  @override
  void dispose() {
    _symptomController.dispose();
    super.dispose();
  }

  Future<void> _predict() async {
    final symptoms = _symptomController.text.trim();
    if (symptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your symptoms')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final result = await _api.predictDisease(token, symptoms);
      if (!mounted) return;
      context.go('/result', extra: result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryBlue),
              const SizedBox(height: 24),
              Text('Analyzing Symptoms...', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Our AI is processing your input', style: GoogleFonts.inter(color: AppTheme.greyText)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Symptom Check'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What are you experiencing?',
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.darkText),
            ),
            const SizedBox(height: 8),
            Text(
              'Describe all your symptoms in detail for an accurate AI prediction.',
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.greyText),
            ),
            const SizedBox(height: 24),

            // Symptom examples
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Text('Examples:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.primaryBlue)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• "I have high fever, chills, and sweating"\n'
                    '• "Experiencing itchy skin, skin rash, and patches"\n'
                    '• "Persistent cough, chest pain, difficulty breathing"',
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Input field
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                boxShadow: AppTheme.cardShadow,
              ),
              child: TextField(
                controller: _symptomController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Enter your symptoms here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _predict,
                icon: const Icon(Icons.psychology),
                label: const Text('Predict Disease'),
              ),
            ),

            const SizedBox(height: 20),
            Text(
              'Disclaimer: AI predictions are for reference only. Always consult a qualified healthcare professional.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.greyText),
            ),
          ],
        ),
      ),
    );
  }
}
