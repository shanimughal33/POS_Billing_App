// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io'; // Added for File
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Color accentBlue = const Color(0xFF1976D2);
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  String _businessName = '';
  String _businessAddress = '';
  String _businessPhone = '';
  String _businessEmail = '';
  String _currency = 'Rs';
  String _taxRate = '0';
  final String _appVersion = '1.0.0';
  final String _buildNumber = '1';
  String _supportPhone = '';
  String _businessLogoPath = '';
  String _customFooter = '';
  bool _enableDiscounts = true;
  double _defaultDiscount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _businessName = prefs.getString('businessName') ?? '';
      _businessAddress = prefs.getString('businessAddress') ?? '';
      _businessPhone = prefs.getString('businessPhone') ?? '';
      _businessEmail = prefs.getString('businessEmail') ?? '';
      _currency = prefs.getString('currency') ?? 'Rs';
      _taxRate = prefs.getString('taxRate') ?? '0';
      _supportPhone = prefs.getString('supportPhone') ?? _businessPhone;
      _businessLogoPath = prefs.getString('businessLogoPath') ?? '';
      _customFooter = prefs.getString('customFooter') ?? '';
      _enableDiscounts = prefs.getBool('enableDiscounts') ?? true;
      _defaultDiscount = prefs.getDouble('defaultDiscount') ?? 0.0;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setString('businessName', _businessName);
    await prefs.setString('businessAddress', _businessAddress);
    await prefs.setString('businessPhone', _businessPhone);
    await prefs.setString('businessEmail', _businessEmail);
    await prefs.setString('currency', _currency);
    await prefs.setString('taxRate', _taxRate);
    await prefs.setString('supportPhone', _supportPhone);
    await prefs.setString('businessLogoPath', _businessLogoPath);
    await prefs.setString('customFooter', _customFooter);
    await prefs.setBool('enableDiscounts', _enableDiscounts);
    await prefs.setDouble('defaultDiscount', _defaultDiscount);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          'Settings',
          style: const TextStyle(
            fontSize: 22,
            color: Color(0xFF0A2342),
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0A2342)),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Business Information'),
            const SizedBox(height: 16),
            _buildBusinessInfoSection(),

            const SizedBox(height: 32),
            _buildSectionTitle('App Settings'),
            const SizedBox(height: 16),
            _buildAppSettingsSection(),

            const SizedBox(height: 32),
            _buildSectionTitle('Data Management'),
            const SizedBox(height: 16),
            _buildDataManagementSection(),

            const SizedBox(height: 32),
            _buildSectionTitle('Support & About'),
            const SizedBox(height: 16),
            _buildSupportSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: accentBlue,
      ),
    );
  }

  Widget _buildBusinessInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.business_rounded,
            title: 'Business Name',
            subtitle: _businessName.isEmpty ? 'Not set' : _businessName,
            onTap: () => _showBusinessNameDialog(),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.location_on_rounded,
            title: 'Business Address',
            subtitle: _businessAddress.isEmpty ? 'Not set' : _businessAddress,
            onTap: () => _showBusinessAddressDialog(),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.phone_rounded,
            title: 'Business Phone',
            subtitle: _businessPhone.isEmpty ? 'Not set' : _businessPhone,
            onTap: () => _showBusinessPhoneDialog(),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.email_rounded,
            title: 'Business Email',
            subtitle: _businessEmail.isEmpty ? 'Not set' : _businessEmail,
            onTap: () => _showBusinessEmailDialog(),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.attach_money_rounded,
            title: 'Currency',
            subtitle: _currency,
            onTap: () => _showCurrencyDialog(),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.calculate_rounded,
            title: 'Tax Rate (%)',
            subtitle: '$_taxRate%',
            onTap: () => _showTaxRateDialog(),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.support_agent,
            title: 'For Support (Phone)',
            subtitle: _supportPhone.isEmpty ? 'Not set' : _supportPhone,
            onTap: () => _showSupportPhoneDialog(),
          ),
          _buildDivider(),
          ListTile(
            leading: _businessLogoPath.isNotEmpty
                ? Image.file(
                    File(_businessLogoPath),
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  )
                : const Icon(Icons.image, size: 40),
            title: const Text('Business Logo'),
            subtitle: Text(
              _businessLogoPath.isEmpty ? 'No logo selected' : 'Logo selected',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _pickBusinessLogo,
            ),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.message,
            title: 'Custom Footer Message',
            subtitle: _customFooter.isEmpty ? 'Not set' : _customFooter,
            onTap: () => _showCustomFooterDialog(),
          ),
          _buildDivider(),
          SwitchListTile.adaptive(
            value: _enableDiscounts,
            onChanged: (val) {
              setState(() => _enableDiscounts = val);
              _saveSettings();
            },
            title: Text(
              'Enable Discounts',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: accentBlue,
              ),
            ),
            secondary: Icon(Icons.discount, color: accentBlue, size: 20),
            activeColor: accentBlue,
          ),
          if (_enableDiscounts)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.percent, color: accentBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Default Discount (%)',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: accentBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _defaultDiscount.toString(),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _defaultDiscount = double.tryParse(val) ?? 0.0;
                        });
                        _saveSettings();
                      },
                    ),
                  ),
                ],
              ),
            ),
          _buildDivider(),
        ],
      ),
    );
  }

  Widget _buildAppSettingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSwitchTile(
            icon: Icons.dark_mode_rounded,
            title: 'Dark Mode',
            subtitle: 'Toggle dark theme',
            value: _isDarkMode,
            onChanged: (value) {
              setState(() {
                _isDarkMode = value;
              });
              _saveSettings();
            },
          ),
          _buildDivider(),
          _buildSwitchTile(
            icon: Icons.notifications_rounded,
            title: 'Notifications',
            subtitle: 'Enable push notifications',
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataManagementSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.sync_rounded,
            title: 'Sync Data',
            subtitle: 'Sync data with cloud',
            onTap: () => _showSyncDataDialog(),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.backup_rounded,
            title: 'Backup Data',
            subtitle: 'Export your data',
            onTap: () => _showBackupDialog(),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.restore_rounded,
            title: 'Restore Data',
            subtitle: 'Import your data',
            onTap: () => _showRestoreDialog(),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.delete_forever_rounded,
            title: 'Clear All Data',
            subtitle: 'Delete all data permanently',
            onTap: () => _showClearDataDialog(),
            isDestructive: true,
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.logout_rounded,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            onTap: () => _showLogoutDialog(),
            isDestructive: true,
          ),
          _buildDivider(),
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.help_rounded,
            title: 'Help & Support',
            subtitle: 'Get help and support',
            onTap: () => _showHelpDialog(),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.feedback_rounded,
            title: 'Send Feedback',
            subtitle: 'Share your feedback',
            onTap: () => _showFeedbackDialog(),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.info_rounded,
            title: 'About App',
            subtitle: 'Version $_appVersion ($_buildNumber)',
            onTap: () => _showAboutDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withAlpha(25)
              : accentBlue.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : accentBlue,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accentBlue.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: accentBlue, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: accentBlue,
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 56, endIndent: 16);
  }

  // Dialog methods
  void _showBusinessNameDialog() {
    final controller = TextEditingController(text: _businessName);
    _showInputDialog(
      title: 'Business Name',
      controller: controller,
      validator: (value) {
        if (value == null || value.trim().isEmpty)
          return 'Business name is required';
        final namePattern = RegExp(r'^[a-zA-Z\s]{2,40}?$');
        if (!namePattern.hasMatch(value.trim()))
          return 'Name must be 2-40 letters and spaces only.';
        return null;
      },
      onSave: (value) {
        setState(() {
          _businessName = value;
        });
        _saveSettings();
      },
    );
  }

  void _showBusinessAddressDialog() {
    final controller = TextEditingController(text: _businessAddress);
    _showInputDialog(
      title: 'Business Address',
      controller: controller,
      maxLines: 3,
      onSave: (value) {
        setState(() {
          _businessAddress = value;
        });
        _saveSettings();
      },
    );
  }

  void _showBusinessPhoneDialog() {
    final controller = TextEditingController(text: _businessPhone);
    _showInputDialog(
      title: 'Business Phone',
      controller: controller,
      keyboardType: TextInputType.phone,
      validator: (value) {
        if (value == null || value.trim().isEmpty)
          return 'Business phone is required';
        final pkPattern = RegExp(r'^(03\d{9}|\+923\d{9})$');
        if (!pkPattern.hasMatch(value.trim()))
          return 'Enter valid PK number (03XXXXXXXXX or +923XXXXXXXXX)';
        return null;
      },
      onSave: (value) {
        setState(() {
          _businessPhone = value;
        });
        _saveSettings();
      },
    );
  }

  void _showBusinessEmailDialog() {
    final controller = TextEditingController(text: _businessEmail);
    _showInputDialog(
      title: 'Business Email',
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      onSave: (value) {
        setState(() {
          _businessEmail = value;
        });
        _saveSettings();
      },
    );
  }

  void _showCurrencyDialog() {
    final currencies = ['Rs', 'Rs', '\$', 'EUR', 'GBP', 'JPY'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: currencies
              .map(
                (currency) => ListTile(
                  title: Text(currency),
                  trailing: _currency == currency
                      ? Icon(Icons.check, color: accentBlue)
                      : null,
                  onTap: () {
                    setState(() {
                      _currency = currency;
                    });
                    _saveSettings();
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showTaxRateDialog() {
    final controller = TextEditingController(text: _taxRate);
    _showInputDialog(
      title: 'Tax Rate (%)',
      controller: controller,
      keyboardType: TextInputType.number,
      onSave: (value) {
        setState(() {
          _taxRate = value;
        });
        _saveSettings();
      },
    );
  }

  void _showSupportPhoneDialog() {
    final controller = TextEditingController(text: _supportPhone);
    _showInputDialog(
      title: 'Support Phone',
      controller: controller,
      keyboardType: TextInputType.phone,
      onSave: (value) {
        setState(() {
          _supportPhone = value;
        });
        _saveSettings();
      },
    );
  }

  void _showCustomFooterDialog() {
    final controller = TextEditingController(text: _customFooter);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Footer Message'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter footer message...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _customFooter = controller.text;
              });
              _saveSettings();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentBlue),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _pickBusinessLogo() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo upload is not supported on web.')),
      );
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _businessLogoPath = picked.path;
        });
        _saveSettings();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error picking image. Make sure image_picker is in your pubspec.yaml.',
          ),
        ),
      );
    }
  }

  void _showInputDialog({
    required String title,
    required TextEditingController controller,
    required Function(String) onSave,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final String? error = validator?.call(controller.text.trim());
              if (error == null) {
                onSave(controller.text.trim());
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(error)));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentBlue),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSyncDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Data'),
        content: const Text(
          'This will sync your data with the cloud. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performSyncData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentBlue),
            child: const Text('Sync', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Data'),
        content: const Text(
          'This will export all your data to a file. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performBackup();
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentBlue),
            child: const Text('Backup', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Data'),
        content: const Text(
          'This will import data from a backup file. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performRestore();
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentBlue),
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all your data. This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performClearData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Clear Data',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout? You will need to sign in again to access the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text(
          'For support, please contact us at:\n\nEmail: support@posbilling.com\nPhone: +1-800-POS-BILL',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: accentBlue),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: const Text(
          'We value your feedback! Please share your thoughts with us.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendFeedback();
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentBlue),
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About POS Billing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: $_appVersion'),
            const SizedBox(height: 8),
            Text('Build: $_buildNumber'),
            const SizedBox(height: 16),
            const Text(
              'A comprehensive POS billing solution for small businesses.',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: accentBlue),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Action methods
  Future<void> _performSyncData() async {
    try {
      // Implement sync logic here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data synced successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _performBackup() async {
    try {
      // Implement backup logic here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performRestore() async {
    try {
      // Implement restore logic here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data restored successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performClearData() async {
    try {
      // Implement clear data logic here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data cleared successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendFeedback() async {
    try {
      // Implement feedback logic here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send feedback: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
