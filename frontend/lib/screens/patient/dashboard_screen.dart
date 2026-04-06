import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _profile;
  List<dynamic> _recentHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final profileResult = await _api.getPatientProfile(auth.token!);
      final historyResult = await _api.getHistory(auth.token!);

      if (!mounted) return;
      setState(() {
        _profile = profileResult['profile'];
        _recentHistory = (historyResult['history'] as List?)?.take(3).toList() ?? [];
        _isLoading = false;
      });

      // If profile not complete, redirect
      if (_profile == null) {
        context.go('/profile-setup');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryBlue),
              const SizedBox(height: 16),
              Text('Loading...', style: GoogleFonts.inter(color: AppTheme.greyText)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Header
                _buildWelcomeHeader(auth),
                const SizedBox(height: 24),

                // Quick Actions
                _buildQuickActions(),
                const SizedBox(height: 24),

                // Health Tip Card
                _buildHealthTip(),
                const SizedBox(height: 24),

                // Recent History
                if (_recentHistory.isNotEmpty) ...[
                  Text('Recent Activity', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ..._recentHistory.map((item) => _buildHistoryCard(item)),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildWelcomeHeader(AuthProvider auth) {
    final name = _profile?['name'] ?? 'Patient';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $name! 👋',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'How are you feeling today?',
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await auth.logout();
              if (mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionCard(
            icon: Icons.psychology,
            label: 'Check\nSymptoms',
            color: AppTheme.primaryBlue,
            onTap: () => context.go('/symptoms'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard(
            icon: Icons.history,
            label: 'View\nHistory',
            color: AppTheme.secondaryGreen,
            onTap: () => context.go('/history'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard(
            icon: Icons.person,
            label: 'My\nProfile',
            color: AppTheme.accentTeal,
            onTap: () => context.go('/profile'),
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthTip() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.secondaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.secondaryGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb, color: AppTheme.secondaryGreen, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Health Tip', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.secondaryGreen)),
                const SizedBox(height: 4),
                Text(
                  'Regular health check-ups help detect problems early. Always describe your symptoms in detail for accurate AI predictions.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(dynamic item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.coronavirus_outlined, color: AppTheme.primaryBlue),
        ),
        title: Text(
          item['disease'] ?? 'Unknown',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Confidence: ${((item['confidence'] ?? 0) * 100).toStringAsFixed(1)}%',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.greyText),
            ),
            const SizedBox(height: 6),
            AppTheme.statusBadge(item['verification_status'] ?? 'PENDING_DOCTOR_VERIFICATION'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.go('/prescription/${item['prediction_id']}');
        },
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home, 'Home', true, () {}),
            _navItem(Icons.psychology, 'Check', false, () => context.go('/symptoms')),
            _navItem(Icons.history, 'History', false, () => context.go('/history')),
            _navItem(Icons.person, 'Profile', false, () => context.go('/profile')),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback onTap) {
    final color = active ? AppTheme.primaryBlue : AppTheme.greyText;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
        ],
      ),
    );
  }
}
