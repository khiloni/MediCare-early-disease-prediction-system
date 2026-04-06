import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final result = await _api.getPatientProfile(auth.token!);
      if (!mounted) return;
      setState(() {
        _profile = result['profile'];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.go('/profile-setup'),
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? Center(child: Text('Profile not set up', style: GoogleFonts.inter(color: AppTheme.greyText)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          (_profile!['name'] ?? 'U')[0].toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _profile!['name'] ?? 'Unknown',
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      Text(auth.email ?? '', style: GoogleFonts.inter(color: AppTheme.greyText)),
                      const SizedBox(height: 32),

                      _profileItem(Icons.cake, 'Age', '${_profile!['age'] ?? 'N/A'} years'),
                      _profileItem(Icons.wc, 'Gender', _profile!['gender'] ?? 'N/A'),
                      _profileItem(Icons.bloodtype, 'Blood Group', _profile!['blood_group'] ?? 'N/A'),
                      _profileItem(Icons.warning_amber, 'Allergies', _profile!['allergies'] ?? 'None'),

                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await auth.logout();
                            if (mounted) context.go('/');
                          },
                          icon: const Icon(Icons.logout, color: AppTheme.errorRed),
                          label: const Text('Logout', style: TextStyle(color: AppTheme.errorRed)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.errorRed),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _profileItem(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.greyText)),
              Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
