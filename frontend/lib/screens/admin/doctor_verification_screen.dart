import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class DoctorVerificationScreen extends StatefulWidget {
  const DoctorVerificationScreen({super.key});

  @override
  State<DoctorVerificationScreen> createState() =>
      _DoctorVerificationScreenState();
}

class _DoctorVerificationScreenState extends State<DoctorVerificationScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _doctors = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final docs = await _api.getAllDoctors(auth.token!);
      final stats = await _api.getAdminDashboard(auth.token!);
      if (!mounted) return;
      setState(() {
        _doctors = docs['doctors'] ?? [];
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveDoctor(String userId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await _api.verifyDoctor(auth.token!, userId, true);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doctor approved successfully!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  Future<void> _rejectDoctor(String userId) async {
    // Confirm before rejecting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Doctor?'),
        content: const Text(
            'This will block the doctor from accessing the platform. An email notification will be sent.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await _api.verifyDoctor(auth.token!, userId, false);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doctor rejected.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Text('Admin Panel',
                                style: GoogleFonts.inter(
                                    fontSize: 26, fontWeight: FontWeight.w800)),
                          ),
                          IconButton(
                            onPressed: () async {
                              await auth.logout();
                              if (mounted) context.go('/login');
                            },
                            icon: const Icon(Icons.logout,
                                color: AppTheme.errorRed),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Stats
                      if (_stats != null) ...[
                        Row(
                          children: [
                            Expanded(
                                child: _statCard(
                                    'Patients',
                                    '${_stats!['total_patients'] ?? 0}',
                                    Icons.people,
                                    AppTheme.primaryBlue)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _statCard(
                                    'Doctors',
                                    '${_stats!['total_doctors'] ?? 0}',
                                    Icons.medical_services,
                                    AppTheme.secondaryGreen)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _statCard(
                                    'Unverified',
                                    '${_stats!['unverified_doctors'] ?? 0}',
                                    Icons.warning,
                                    AppTheme.warningOrange)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _statCard(
                                    'Predictions',
                                    '${_stats!['total_predictions'] ?? 0}',
                                    Icons.analytics,
                                    AppTheme.accentTeal)),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Navigation tabs
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon:
                                  const Icon(Icons.verified_user, size: 18),
                              label: const Text('Doctors'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.go('/users'),
                              icon: const Icon(Icons.people, size: 18),
                              label: const Text('Users'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text('Doctor Verification',
                          style: GoogleFonts.inter(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),

                      // Doctor list
                      if (_doctors.isEmpty)
                        Center(
                            child: Text('No doctors registered',
                                style: GoogleFonts.inter(
                                    color: AppTheme.greyText)))
                      else
                        ..._doctors.map((doc) => _doctorCard(doc)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppTheme.greyText)),
        ],
      ),
    );
  }

  Widget _doctorCard(dynamic doc) {
    // Determine status from 'status' column, fallback to 'verified' boolean
    final String status = doc['status'] ?? (doc['verified'] == true ? 'approved' : 'pending');
    final bool isApproved = status == 'approved';
    final bool isRejected = status == 'rejected';
    final bool isPending = status == 'pending';

    // Status badge color/icon
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (isApproved) {
      statusColor = AppTheme.successGreen;
      statusIcon = Icons.verified;
      statusLabel = 'APPROVED';
    } else if (isRejected) {
      statusColor = AppTheme.errorRed;
      statusIcon = Icons.cancel;
      statusLabel = 'REJECTED';
    } else {
      statusColor = AppTheme.warningOrange;
      statusIcon = Icons.pending;
      statusLabel = 'PENDING';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc['name'] ?? 'Unknown',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(doc['specialization'] ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppTheme.greyText)),
                    ],
                  ),
                ),
                AppTheme.statusBadge(statusLabel),
              ],
            ),
            const SizedBox(height: 12),
            Text('License: ${doc['license_number'] ?? 'N/A'}',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.greyText)),
            Text('Email: ${doc['email'] ?? 'N/A'}',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.greyText)),
            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                // APPROVE — show if pending or rejected
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        isApproved ? null : () => _approveDoctor(doc['user_id']),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // REJECT — show if pending or approved
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        isRejected ? null : () => _rejectDoctor(doc['user_id']),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorRed,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
