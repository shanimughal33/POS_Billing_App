// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/auth_utils.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../repositories/settings_repository.dart';
import '../models/settings.dart';
import '../services/theme_service.dart';
import '../themes/app_theme.dart';

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
  String _businessPhone = 'N/A';
  String _businessEmail = '';
  String _currency = 'Rs';
  String _taxRate = '0';
  final String _appVersion = '1.0.0';
  final String _buildNumber = '1';
  String _supportPhone = 'N/A';
  String _businessLogoPath = '';
  String _customFooter = 'Thank you for your business!';
  bool _enableDiscounts = true;
  double _defaultDiscount = 0.0;
  final SettingsRepository _settingsRepo = SettingsRepository();
  Settings? _settings;
  late TextEditingController _discountController;

  @override
  void initState() {
    super.initState();
    _discountController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = await getCurrentUserUid();
    if (uid == null || uid.isEmpty) return;
    final settings = await _settingsRepo.getSettings(uid);
    setState(() {
      _settings = settings ?? Settings(userId: uid);
      _discountController.text = (_settings?.defaultDiscount ?? 0.0).toString();
    });
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;
    await _settingsRepo.saveSettings(_settings!);
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A2342) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A2233) : Colors.white,
        centerTitle: true,
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 22,
            color: isDark ? Colors.white : Color(0xFF013A63),
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Color(0xFF013A63),
        ),
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
            _buildSectionTitle('Business Information', isDark),
            const SizedBox(height: 16),
            _buildBusinessInfoSection(isDark),

            const SizedBox(height: 32),
            _buildSectionTitle('App Settings', isDark),
            const SizedBox(height: 16),
            _buildAppSettingsSection(isDark),

            const SizedBox(height: 32),
            _buildSectionTitle('Support & About', isDark),
            const SizedBox(height: 16),
            _buildSupportSection(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Color(0xFF013A63),
      ),
    );
  }

  Widget _buildBusinessInfoSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF013A63) : Colors.white,
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
            subtitle: ((_settings?.businessName ?? '').isEmpty)
                ? 'Not set'
                : (_settings?.businessName ?? ''),
            onTap: () => _showBusinessNameDialog(),
            isDark: isDark,
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.location_on_rounded,
            title: 'Business Address',
            subtitle: ((_settings?.businessAddress ?? '').isEmpty)
                ? 'Not set'
                : (_settings?.businessAddress ?? ''),
            onTap: () => _showBusinessAddressDialog(),
            isDark: isDark,
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.phone_rounded,
            title: 'Business Phone',
            subtitle: ((_settings?.businessPhone ?? '').isEmpty)
                ? 'Not set'
                : (_settings?.businessPhone ?? ''),
            onTap: () => _showBusinessPhoneDialog(),
            isDark: isDark,
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.email_rounded,
            title: 'Business Email',
            subtitle: ((_settings?.businessEmail ?? '').isEmpty)
                ? 'Not set'
                : (_settings?.businessEmail ?? ''),
            onTap: () => _showBusinessEmailDialog(),
            isDark: isDark,
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.attach_money_rounded,
            title: 'Currency',
            subtitle: _settings?.currency ?? 'Rs',
            onTap: () => _showCurrencyDialog(),
            isDark: isDark,
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.calculate_rounded,
            title: 'Tax Rate (%)',
            subtitle: '${_settings?.taxRate ?? '0'}%',
            onTap: () => _showTaxRateDialog(),
            isDark: isDark,
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.support_agent,
            title: 'For Support (Phone)',
            subtitle: ((_settings?.supportPhone ?? '').isEmpty)
                ? 'Not set'
                : (_settings?.supportPhone ?? ''),
            onTap: () => _showSupportPhoneDialog(),
            isDark: isDark,
          ),
          _buildDivider(),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentBlue.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _settings?.businessLogoPath.isNotEmpty ?? false
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        File(_settings!.businessLogoPath),
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      Icons.image,
                      color: isDark ? accentBlue : accentBlue,
                      size: 20,
                    ),
            ),
            title: Text(
              'Business Logo',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Color(0xFF013A63),
              ),
            ),
            subtitle: Text(
              _settings?.businessLogoPath.isEmpty ?? true
                  ? 'No logo selected'
                  : 'Logo selected',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            trailing: IconButton(
              icon: Icon(Icons.edit, color: isDark ? Colors.white : accentBlue),
              onPressed: _pickBusinessLogo,
            ),
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.message,
            title: 'Custom Footer Message',
            subtitle: ((_settings?.customFooter ?? '').isEmpty)
                ? 'Not set'
                : (_settings?.customFooter ?? ''),
            onTap: () => _showCustomFooterDialog(),
            isDark: isDark,
          ),
          _buildDivider(),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            value: _settings?.enableDiscounts ?? true,
            onChanged: (val) {
              setState(() {
                _settings = _settings!.copyWith(enableDiscounts: val);
              });
              _saveSettings();
              if (val) {
                // When enabling discounts, prompt user to set default via bottom sheet
                Future.microtask(_showDiscountBottomSheet);
              }
            },
            title: Text(
              'Enable Discounts',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Color(0xFF013A63),
              ),
            ),
            secondary: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentBlue.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.discount,
                color: isDark ? accentBlue : accentBlue,
                size: 20,
              ),
            ),
            activeColor: accentBlue,
            activeTrackColor: accentBlue.withAlpha(100),
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.transparent,
          ),
          if (_settings?.enableDiscounts ?? true)
            _buildSettingTile(
              icon: Icons.percent,
              title: 'Default Discount (%)',
              subtitle:
                  '${(_settings?.defaultDiscount ?? 0).toStringAsFixed(2)}%',
              onTap: _showDiscountBottomSheet,
              isDark: isDark,
            ),
          _buildDivider(),
        ],
      ),
    );
  }

  Widget _buildAppSettingsSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF013A63) : Colors.white,
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
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.themeNotifier,
            builder: (context, themeMode, _) {
              return SwitchListTile.adaptive(
                title: Text(
                  'Dark Mode',
                  style: TextStyle(
                    color: isDark ? Colors.white : Color(0xFF013A63),
                    fontWeight: FontWeight.w600,
                  ),
                ),

                secondary: Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentBlue.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.dark_mode,
                    color: Color(0xFF1976D2),
                    size: 20,
                  ),
                ),
                value: themeMode == ThemeMode.dark,
                onChanged: (bool value) async {
                  if (value) {
                    // Force dark mode (manual)
                    await ThemeService.setFollowSystem(false);
                    await ThemeService.setManualMode(ThemeMode.dark);
                  } else {
                    // Follow system when turned off
                    await ThemeService.setFollowSystem(true);
                  }
                },
                activeColor: accentBlue,
                activeTrackColor: accentBlue.withAlpha(100),
                inactiveThumbColor: Colors.grey.shade400,
                inactiveTrackColor: Colors.transparent,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF013A63) : Colors.white,
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
            onTap: _showHelpDialog,
            isDark: isDark,
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.feedback_rounded,
            title: 'Send Feedback',
            subtitle: 'Share your feedback',
            onTap: _showFeedbackDialog,
            isDark: isDark,
          ),
          _buildDivider(),
          _buildSettingTile(
            icon: Icons.info_rounded,
            title: 'About App',
            subtitle: 'Version $_appVersion ($_buildNumber)',
            onTap: _showAboutDialog,
            isDark: isDark,
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
    bool isDark = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
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
          color: isDark ? Colors.white : Color(0xFF013A63),
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
    bool isDark = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accentBlue.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: isDark ? Colors.white : accentBlue, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Color(0xFF013A63),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: accentBlue,
        activeTrackColor: accentBlue.withAlpha(100),
        inactiveThumbColor: Colors.grey.shade400,
        inactiveTrackColor: Colors.grey.shade300,
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 56, endIndent: 16);
  }

  // Dialog methods
  void _showBusinessNameDialog() {
    final controller = TextEditingController(
      text: _settings?.businessName ?? '',
    );
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
          _settings = _settings!.copyWith(businessName: value);
        });
        _saveSettings();
      },
    );
  }

  void _showBusinessAddressDialog() {
    final controller = TextEditingController(
      text: _settings?.businessAddress ?? '',
    );
    _showInputDialog(
      title: 'Business Address',
      controller: controller,
      maxLines: 3,
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Address is required';
        if (value.trim().length < 5) return 'Enter a valid address';
        return null;
      },
      onSave: (value) {
        setState(() {
          _settings = _settings!.copyWith(businessAddress: value);
        });
        _saveSettings();
      },
    );
  }

  void _showBusinessPhoneDialog() {
    final controller = TextEditingController(
      text: _settings?.businessPhone ?? '',
    );
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
          _settings = _settings!.copyWith(businessPhone: value);
        });
        _saveSettings();
      },
    );
  }

  void _showBusinessEmailDialog() {
    final controller = TextEditingController(
      text: _settings?.businessEmail ?? '',
    );
    _showInputDialog(
      title: 'Business Email',
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Email is required';
        final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
        if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
        return null;
      },
      onSave: (value) {
        setState(() {
          _settings = _settings!.copyWith(businessEmail: value);
        });
        _saveSettings();
      },
    );
  }

  void _showCurrencyDialog() {
    final currencies = ['Rs', '\$', 'EUR', 'GBP', 'JPY'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select Currency',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF013A63),
          ),
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: currencies
                .map(
                  (currency) => Container(
                    margin: EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: _settings?.currency == currency
                          ? Color(0xFF1976D2).withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: _settings?.currency == currency
                          ? Border.all(color: Color(0xFF1976D2), width: 1)
                          : null,
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      title: Text(
                        currency,
                        style: GoogleFonts.poppins(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Color(0xFF013A63),
                          fontWeight: _settings?.currency == currency
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      trailing: _settings?.currency == currency
                          ? Icon(
                              Icons.check_circle,
                              color: accentBlue,
                              size: 20,
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          _settings = _settings!.copyWith(currency: currency);
                        });
                        _saveSettings();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: accentBlue),
            ),
          ),
        ],
      ),
    );
  }

  void _showTaxRateDialog() {
    final controller = TextEditingController(text: _settings?.taxRate ?? '0');
    _showInputDialog(
      title: 'Tax Rate (%)',
      controller: controller,
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Enter a value';
        final v = double.tryParse(value.trim());
        if (v == null) return 'Enter a valid number';
        if (v < 0 || v > 100) return 'Must be between 0 and 100';
        return null;
      },
      onSave: (value) {
        setState(() {
          _settings = _settings!.copyWith(taxRate: value);
        });
        _saveSettings();
      },
    );
  }

  void _showSupportPhoneDialog() {
    final controller = TextEditingController(
      text: _settings?.supportPhone ?? '',
    );
    _showInputDialog(
      title: 'Support Phone',
      controller: controller,
      keyboardType: TextInputType.phone,
      onSave: (value) {
        setState(() {
          _settings = _settings!.copyWith(supportPhone: value);
        });
        _saveSettings();
      },
    );
  }

  void _showCustomFooterDialog() {
    final controller = TextEditingController(
      text: _settings?.customFooter ?? '',
    );
    _showInputDialog(
      title: 'Custom Footer Message',
      controller: controller,
      maxLines: 3,
      onSave: (value) {
        setState(() {
          _settings = _settings!.copyWith(customFooter: value);
        });
        _saveSettings();
      },
    );
  }

  void _pickBusinessLogo() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logo upload is not supported on web.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
        ),
      );
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _settings = _settings!.copyWith(businessLogoPath: picked.path);
        });
        _saveSettings();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error picking image. Make sure image_picker is in your pubspec.yaml.',
            style: GoogleFonts.poppins(color: Colors.white),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 48),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF013A63),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Form(
                    key: formKey,
                    child: TextFormField(
                      controller: controller,
                      keyboardType: keyboardType,
                      maxLines: maxLines,
                      autofocus: true,
                      validator: validator,
                      style: GoogleFonts.poppins(
                        color: isDark ? Colors.white : const Color(0xFF013A63),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter ${title.toLowerCase()}',
                        hintStyle: GoogleFonts.poppins(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF0F172A)
                            : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF1976D2),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF013A63),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (validator != null) {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                          }
                          onSave(controller.text.trim());
                          Navigator.pop(context);
                        },
                        style:
                            ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              elevation: 0,
                              backgroundColor: Colors.transparent,
                            ).copyWith(
                              overlayColor: MaterialStateProperty.all(
                                Colors.transparent,
                              ),
                            ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF0A2342),
                                Color(0xFF123060),
                                Color(0xFF1976D2),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: Text(
                            'Save',
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDiscountBottomSheet() {
    final controller = TextEditingController(
      text: (_settings?.defaultDiscount ?? 0.0).toStringAsFixed(2),
    );
    _showInputDialog(
      title: 'Default Discount (%)',
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Enter a value';
        final v = double.tryParse(value.trim());
        if (v == null) return 'Enter a valid number';
        if (v < 0 || v > 100) return 'Must be between 0 and 100';
        return null;
      },
      onSave: (value) {
        final v = double.tryParse(value) ?? 0.0;
        setState(() {
          _settings = _settings!.copyWith(defaultDiscount: v);
          _discountController.text = v.toStringAsFixed(2);
        });
        _saveSettings();
      },
    );
  }

  void _showSyncDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sync Data',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF1976D2),
          ),
        ),
        content: Text(
          'This will sync your data with the cloud. Continue?',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF1976D2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: accentBlue),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performSyncData();
            },
            style:
                ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                ).copyWith(
                  backgroundColor: MaterialStateProperty.all(
                    Colors.transparent,
                  ),
                  overlayColor: MaterialStateProperty.all(Colors.transparent),
                ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0A2342), // deep navy blue
                    Color(0xFF123060), // dark blue
                    Color(0xFF1976D2), // vibrant blue
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Sync',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Backup Data',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF1976D2),
          ),
        ),
        content: Text(
          'This will export all your data to a file. Continue?',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF1976D2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: accentBlue),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performBackup();
            },
            style:
                ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                ).copyWith(
                  backgroundColor: MaterialStateProperty.all(
                    Colors.transparent,
                  ),
                  overlayColor: MaterialStateProperty.all(Colors.transparent),
                ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0A2342), // deep navy blue
                    Color(0xFF123060), // dark blue
                    Color(0xFF1976D2), // vibrant blue
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Backup',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Restore Data',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF1976D2),
          ),
        ),
        content: Text(
          'This will import data from a backup file. Continue?',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF1976D2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: accentBlue),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performRestore();
            },
            style:
                ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                ).copyWith(
                  backgroundColor: MaterialStateProperty.all(
                    Colors.transparent,
                  ),
                  overlayColor: MaterialStateProperty.all(Colors.transparent),
                ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0A2342), // deep navy blue
                    Color(0xFF123060), // dark blue
                    Color(0xFF1976D2), // vibrant blue
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Restore',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Clear All Data',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF1976D2),
          ),
        ),
        content: Text(
          'This will permanently delete all your data. This action cannot be undone. Are you sure?',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF1976D2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: accentBlue),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performClearData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            child: Text(
              'Clear Data',
              style: GoogleFonts.poppins(color: Colors.white),
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
        title: Text(
          'Logout',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF1976D2),
          ),
        ),
        content: Text(
          'Are you sure you want to logout? You will need to sign in again to access the app.',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF1976D2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: accentBlue),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Help & Support',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF1976D2),
          ),
        ),
        content: Text(
          'For help with Forward Billing POS, contact us at:\n\nsupport@yourposapp.com\n\nWe are here to help you with any issues or questions!',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF1976D2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white : Colors.blueAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@yourposapp.com',
      query: 'subject=Feedback for Forward Billing POS',
    );
    // Use url_launcher to open email app
    // import 'package:url_launcher/url_launcher.dart';
    // await launchUrl(emailLaunchUri);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Send Feedback',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF1976D2),
          ),
        ),
        content: Text(
          'To send feedback, email us at:\n\nsupport@yourposapp.com',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF1976D2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white : Colors.blueAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'About Forward Billing POS',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF1976D2),
          ),
        ),
        content: Text(
          'Forward Billing POS\nVersion 1.0.0\n\nA modern POS solution for your business.\n\nFor more info, visit our website or contact support.',
          style: GoogleFonts.poppins(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Color(0xFF1976D2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white : Colors.blueAccent,
              ),
            ),
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
        SnackBar(
          content: Text(
            'Data synced successfully!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sync failed: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performBackup() async {
    try {
      // Implement backup logic here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup completed successfully!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup failed: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performRestore() async {
    try {
      // Implement restore logic here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Data restored successfully!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restore failed: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performClearData() async {
    try {
      // Implement clear data logic here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'All data cleared successfully!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to clear data: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendFeedback() async {
    try {
      // Implement feedback logic here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Feedback sent successfully!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to send feedback: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      try {
        final google = GoogleSignIn();
        await google.signOut();
        await google.disconnect();
      } catch (_) {}
      await clearUserUid();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged out successfully!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logout failed: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
