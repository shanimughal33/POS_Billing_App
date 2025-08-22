import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/settings_repository.dart';
import '../models/settings.dart';

class BusinessInfo {
  final String name;
  final String address;
  final String phone;
  final String email;
  final String currency;
  final String taxRate;
  final String supportPhone;
  final String businessLogoPath;
  final String customFooter;
  final bool enableDiscounts;
  final double defaultDiscount;

  BusinessInfo({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.currency,
    required this.taxRate,
    required this.supportPhone,
    required this.businessLogoPath,
    required this.customFooter,
    required this.enableDiscounts,
    required this.defaultDiscount,
  });

  static Future<BusinessInfo> load() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('current_uid');
    if (uid == null || uid.isEmpty) {
      // Return default business info if no user is logged in
      return BusinessInfo(
        name: 'Business Name',
        address: 'Business Address',
        phone: 'N/A',
        email: 'Business Email',
        currency: 'Rs',
        taxRate: '0',
        supportPhone: 'N/A',
        businessLogoPath: '',
        customFooter: 'Thank you for your business!',
        enableDiscounts: true,
        defaultDiscount: 0.0,
      );
    }
    final settings = await SettingsRepository().getSettings(uid);
    if (settings == null) {
      // Return default business info if no settings found
      return BusinessInfo(
        name: 'Business Name',
        address: 'Business Address',
        phone: 'N/A',
        email: 'Business Email',
        currency: 'Rs',
        taxRate: '0',
        supportPhone: 'N/A',
        businessLogoPath: '',
        customFooter: 'Thank you for your business!',
        enableDiscounts: true,
        defaultDiscount: 0.0,
      );
    }
    return BusinessInfo(
      name: settings.businessName ?? 'Business Name',
      address: settings.businessAddress ?? 'Business Address',
      phone: settings.businessPhone ?? 'N/A',
      email: settings.businessEmail ?? 'Business Email',
      currency: settings.currency ?? 'Rs',
      taxRate: settings.taxRate ?? '0',
      supportPhone: settings.supportPhone ?? (settings.businessPhone ?? 'N/A'),
      businessLogoPath: settings.businessLogoPath ?? '',
      customFooter: settings.customFooter ?? 'Thank you for your business!',
      enableDiscounts: settings.enableDiscounts ?? true,
      defaultDiscount: settings.defaultDiscount ?? 0.0,
    );
  }
}
