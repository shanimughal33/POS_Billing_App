import 'package:shared_preferences/shared_preferences.dart';

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
    String taxRate = prefs.getString('taxRate') ?? '0';
    double defaultDiscount = prefs.getDouble('defaultDiscount') ?? 0.0;
    String phone = prefs.getString('businessPhone') ?? 'N/A';
    String customFooter = prefs.getString('customFooter') ?? 'Thank you for your business!';

    return BusinessInfo(
      name: prefs.getString('businessName') ?? 'Business Name',
      address: prefs.getString('businessAddress') ?? 'Business Address',
      phone: phone,
      email: prefs.getString('businessEmail') ?? 'Business Email',
      currency: prefs.getString('currency') ?? 'Rs',
      taxRate: taxRate,
      supportPhone:
          prefs.getString('supportPhone') ??
          phone,
      businessLogoPath: prefs.getString('businessLogoPath') ?? '',
      customFooter: customFooter,
      enableDiscounts: prefs.getBool('enableDiscounts') ?? true,
      defaultDiscount: defaultDiscount,
    );
  }
}
