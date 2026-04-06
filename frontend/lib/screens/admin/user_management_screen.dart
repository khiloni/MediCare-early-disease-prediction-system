import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final result = await _api.getAllUsers(auth.token!);
      if (!mounted) return;
      setState(() {
        _users = result['users'] ?? [];
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
        title: const Text('User Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/doctors'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return _userTile(user);
                },
              ),
            ),
    );
  }

  Widget _userTile(dynamic user) {
    final role = user['role'] ?? 'unknown';
    Color roleColor;
    IconData roleIcon;

    switch (role) {
      case 'admin':
        roleColor = AppTheme.errorRed;
        roleIcon = Icons.admin_panel_settings;
        break;
      case 'doctor':
        roleColor = AppTheme.primaryBlue;
        roleIcon = Icons.medical_services;
        break;
      default:
        roleColor = AppTheme.secondaryGreen;
        roleIcon = Icons.person;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: roleColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(roleIcon, color: roleColor, size: 22),
        ),
        title: Text(user['email'] ?? 'N/A', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${role.toUpperCase()} • Created: ${(user['created_at'] ?? '').toString().substring(0, 10)}',
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.greyText),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: roleColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            role.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: roleColor),
          ),
        ),
      ),
    );
  }
}
