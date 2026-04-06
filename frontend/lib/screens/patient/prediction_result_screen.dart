import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../config/app_theme.dart';

class PredictionResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;

  const PredictionResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final disease = result['disease'] ?? 'Unknown';
    final confidence = (result['confidence'] ?? 0).toDouble();
    final precautions = result['precautions'] as List? ?? [];
    final tests = result['recommended_tests'] as List? ?? [];
    final medicines = result['medicines'] ?? '';
    final status = result['status'] ?? 'PENDING';
    final predictionId = result['prediction_id'] ?? '';
    final pdfUrl = result['pdf_url'];

    final confPercent = confidence * 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Prediction Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Confidence + Disease Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  CircularPercentIndicator(
                    radius: 70,
                    lineWidth: 10,
                    percent: confidence.clamp(0, 1),
                    center: Text(
                      '${confPercent.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.darkText),
                    ),
                    progressColor: confPercent > 80
                        ? AppTheme.successGreen
                        : confPercent > 50
                            ? AppTheme.warningOrange
                            : AppTheme.errorRed,
                    backgroundColor: AppTheme.lightGrey,
                    circularStrokeCap: CircularStrokeCap.round,
                  ),
                  const SizedBox(height: 16),
                  Text('AI Confidence', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.greyText)),
                  const SizedBox(height: 12),
                  Text(
                    disease,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.darkText),
                  ),
                  const SizedBox(height: 12),
                  AppTheme.statusBadge(status),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Medicines
            _buildSection(
              title: 'Prescribed Medicines',
              icon: Icons.medication,
              iconColor: AppTheme.primaryBlue,
              child: Text(
                medicines.toString().isNotEmpty ? medicines : 'Consult a doctor',
                style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkText, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),

            // Precautions
            _buildSection(
              title: 'Precautions',
              icon: Icons.shield_outlined,
              iconColor: AppTheme.secondaryGreen,
              child: Column(
                children: precautions.map((p) => _bulletItem(p.toString())).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Tests
            _buildSection(
              title: 'Recommended Tests',
              icon: Icons.biotech_outlined,
              iconColor: Colors.purple,
              child: Column(
                children: tests.map((t) => _bulletItem(t.toString())).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                if (predictionId.isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/prescription/$predictionId'),
                      icon: const Icon(Icons.description),
                      label: const Text('View Prescription'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/dashboard'),
                icon: const Icon(Icons.home),
                label: const Text('Back to Dashboard'),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Disclaimer: This is an AI prediction. Please consult a doctor for actual diagnosis.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.greyText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.darkText)),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _bulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 18, color: AppTheme.successGreen),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 14, height: 1.4))),
        ],
      ),
    );
  }
}
