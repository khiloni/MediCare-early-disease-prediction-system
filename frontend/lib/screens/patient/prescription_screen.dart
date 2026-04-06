import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class PrescriptionScreen extends StatefulWidget {
  final String predictionId;
  const PrescriptionScreen({super.key, required this.predictionId});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _prescription;
  Map<String, dynamic>? _review;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (token == null) return;

    try {
      final result = await _api.getPrescription(token, widget.predictionId);
      if (!mounted) return;
      setState(() {
        _prescription = result['prescription'];
        _review = result['review'];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadPdf() async {
    final url = _prescription?['pdf_url'];
    if (url != null && url.toString().isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF not available yet')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescription'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _prescription == null
              ? Center(child: Text('Prescription not found', style: GoogleFonts.inter(color: AppTheme.greyText)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Status Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppTheme.cardGradient,
                          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.description, size: 40, color: Colors.white),
                            const SizedBox(height: 12),
                            Text(
                              _prescription!['disease'] ?? 'Unknown',
                              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            AppTheme.statusBadge(_prescription!['verification_status'] ?? 'PENDING'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Medicines
                      _infoCard('Medicines', Icons.medication, _prescription!['medicines'] ?? 'N/A'),
                      const SizedBox(height: 12),

                      // Precautions
                      _infoCard('Precautions', Icons.shield, _prescription!['precautions'] ?? 'N/A'),
                      const SizedBox(height: 12),

                      // Tests
                      _infoCard('Recommended Tests', Icons.biotech, _prescription!['tests'] ?? 'N/A'),

                      // Doctor Review
                      if (_review != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.accentTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            border: Border.all(color: AppTheme.accentTeal.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.medical_services, color: AppTheme.accentTeal),
                                  const SizedBox(width: 8),
                                  Text('Doctor Review', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.accentTeal)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('Decision: ${_review!['decision']}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              if (_review!['notes'] != null) ...[
                                const SizedBox(height: 8),
                                Text('Notes: ${_review!['notes']}', style: GoogleFonts.inter(fontSize: 14)),
                              ],
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Download PDF
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _downloadPdf,
                          icon: const Icon(Icons.download),
                          label: const Text('Download PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _infoCard(String title, IconData icon, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkText, height: 1.5)),
        ],
      ),
    );
  }
}
