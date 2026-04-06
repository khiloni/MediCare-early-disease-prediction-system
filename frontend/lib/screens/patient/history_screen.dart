import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (token == null) {
       setState(() => _isLoading = false);
       return;
    }
    
    try {
      final result = await _api.getHistory(token);
      if (!mounted) return;
      setState(() {
        _history = result['history'] ?? [];
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
        title: const Text('Prediction History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: AppTheme.greyText.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('No predictions yet', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.greyText)),
                      const SizedBox(height: 8),
                      Text('Start a symptom check to see your history here.', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.greyText)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      return _buildHistoryTile(item);
                    },
                  ),
                ),
    );
  }

  Widget _buildHistoryTile(dynamic item) {
    final confidence = ((item['confidence'] ?? 0) * 100).toStringAsFixed(1);
    final date = item['created_at']?.toString().substring(0, 10) ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/prescription/${item['prediction_id']}'),
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
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.coronavirus_outlined, color: AppTheme.primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['disease'] ?? 'Unknown',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Confidence: $confidence% • $date',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.greyText),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.greyText),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  AppTheme.statusBadge(item['verification_status'] ?? 'PENDING'),
                  const Spacer(),
                  Text(
                    item['symptoms']?.toString().length != null && item['symptoms'].toString().length > 40
                        ? '${item['symptoms'].toString().substring(0, 40)}...'
                        : item['symptoms'] ?? '',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.greyText, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
