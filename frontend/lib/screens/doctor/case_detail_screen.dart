import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class CaseDetailScreen extends StatefulWidget {
  final String predictionId;
  const CaseDetailScreen({super.key, required this.predictionId});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _caseData;
  bool _isLoading = true;
  bool _isSubmitting = false;

  String _decision = 'APPROVED';
  final _notesController = TextEditingController();
  final _medicinesController = TextEditingController();
  final _precautionsController = TextEditingController();
  final _testsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCase();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _medicinesController.dispose();
    _precautionsController.dispose();
    _testsController.dispose();
    super.dispose();
  }

  Future<void> _loadCase() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final result = await _api.getCaseDetail(auth.token!, widget.predictionId);
      if (!mounted) return;
      setState(() {
        _caseData = result;
        _isLoading = false;

        // Pre-fill with current prescription data
        final rx = result['prescription'];
        if (rx != null) {
          _medicinesController.text = rx['medicines'] ?? '';
          _precautionsController.text = rx['precautions'] ?? '';
          _testsController.text = rx['tests'] ?? '';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      final reviewData = {
        'prediction_id': widget.predictionId,
        'decision': _decision,
        'notes': _notesController.text.trim(),
      };

      if (_decision == 'MODIFIED') {
        reviewData['updated_medicines'] = _medicinesController.text.trim();
        reviewData['updated_precautions'] = _precautionsController.text.trim();
        reviewData['updated_tests'] = _testsController.text.trim();
      }

      await _api.submitReview(auth.token!, reviewData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Review submitted: $_decision'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      context.go('/cases');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Case Review'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/cases'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _caseData == null
              ? Center(child: Text('Case not found', style: GoogleFonts.inter(color: AppTheme.greyText)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Patient Info
                      _sectionTitle('Patient Information'),
                      _infoRow('Name', _caseData!['patient']['name'] ?? 'Unknown'),
                      _infoRow('Age', '${_caseData!['patient']['age'] ?? 'N/A'}'),
                      _infoRow('Gender', _caseData!['patient']['gender'] ?? 'N/A'),
                      _infoRow('Blood Group', _caseData!['patient']['blood_group'] ?? 'N/A'),
                      _infoRow('Allergies', _caseData!['patient']['allergies'] ?? 'None'),
                      const SizedBox(height: 20),

                      // Symptoms
                      _sectionTitle('Reported Symptoms'),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Text(
                          _caseData!['symptoms']['symptoms'] ?? '',
                          style: GoogleFonts.inter(fontSize: 14, fontStyle: FontStyle.italic, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // AI Prediction
                      _sectionTitle('AI Prediction'),
                      _infoRow('Disease', _caseData!['prediction']['predicted_disease'] ?? 'Unknown'),
                      _infoRow('Confidence', '${((_caseData!['prediction']['confidence'] ?? 0) * 100).toStringAsFixed(1)}%'),
                      const SizedBox(height: 20),

                      // Current Prescription
                      _sectionTitle('Current Prescription'),
                      _infoRow('Medicines', _caseData!['prescription']['medicines'] ?? 'N/A'),
                      const SizedBox(height: 24),

                      // Already reviewed?
                      if (_caseData!['review'] != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Already reviewed: ${_caseData!['review']['decision']}',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.successGreen),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Review Panel
                      _sectionTitle('Your Review'),
                      const SizedBox(height: 8),

                      // Decision buttons
                      Row(
                        children: [
                          _decisionChip('APPROVED', Icons.check_circle, AppTheme.successGreen),
                          const SizedBox(width: 8),
                          _decisionChip('MODIFIED', Icons.edit_note, AppTheme.modifiedColor),
                          const SizedBox(width: 8),
                          _decisionChip('REJECTED', Icons.cancel, AppTheme.errorRed),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Doctor Notes',
                          hintText: 'Add your observations...',
                        ),
                      ),

                      if (_decision == 'MODIFIED') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _medicinesController,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Updated Medicines'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _precautionsController,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Updated Precautions'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _testsController,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Updated Tests'),
                        ),
                      ],

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitReview,
                          icon: _isSubmitting
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send),
                          label: Text(_isSubmitting ? 'Submitting...' : 'Submit Review'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.greyText, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _decisionChip(String value, IconData icon, Color color) {
    final selected = _decision == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _decision = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? color : AppTheme.lightGrey, width: selected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : AppTheme.greyText, size: 24),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: selected ? color : AppTheme.greyText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
