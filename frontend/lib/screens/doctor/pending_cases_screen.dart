import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class PendingCasesScreen extends StatefulWidget {
  const PendingCasesScreen({super.key});

  @override
  State<PendingCasesScreen> createState() => _PendingCasesScreenState();
}

class _PendingCasesScreenState extends State<PendingCasesScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _cases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final result = await _api.getDoctorCases(auth.token!);
      if (!mounted) return;
      setState(() {
        _cases = result['cases'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Cases'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cases.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: AppTheme.successGreen.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('No pending cases', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.greyText)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCases,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cases.length,
                    itemBuilder: (context, index) {
                      final c = _cases[index];
                      return _caseCard(c);
                    },
                  ),
                ),
    );
  }

  Widget _caseCard(dynamic c) {
    final confidence = ((c['confidence'] ?? 0) * 100).toStringAsFixed(1);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/cases/${c['prediction_id']}'),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warningOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person, color: AppTheme.warningOrange, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['patient_name'] ?? 'Unknown', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(
                          '${c['patient_age'] ?? '?'} yrs • ${c['patient_gender'] ?? '?'}',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.greyText),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.greyText),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Disease: ${c['disease'] ?? 'Unknown'}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Confidence: $confidence%', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.greyText)),
                    const SizedBox(height: 4),
                    Text('Symptoms: ${c['symptoms'] ?? ''}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.greyText, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
