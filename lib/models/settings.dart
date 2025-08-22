class Settings {
  final String userId;
  final String businessName;
  final String businessAddress;
  final String businessPhone;
  final String businessEmail;
  final String currency;
  final String taxRate;
  final String supportPhone;
  final String businessLogoPath;
  final String customFooter;
  final bool isDarkMode;
  final bool notificationsEnabled;
  final bool enableDiscounts;
  final double defaultDiscount;

  Settings({
    required this.userId,
    this.businessName = '',
    this.businessAddress = '',
    this.businessPhone = 'N/A',
    this.businessEmail = '',
    this.currency = 'Rs',
    this.taxRate = '0',
    this.supportPhone = 'N/A',
    this.businessLogoPath = '',
    this.customFooter = 'Thank you for your business!',
    this.isDarkMode = false,
    this.notificationsEnabled = true,
    this.enableDiscounts = true,
    this.defaultDiscount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'businessName': businessName,
      'businessAddress': businessAddress,
      'businessPhone': businessPhone,
      'businessEmail': businessEmail,
      'currency': currency,
      'taxRate': taxRate,
      'supportPhone': supportPhone,
      'businessLogoPath': businessLogoPath,
      'customFooter': customFooter,
      'isDarkMode': isDarkMode,
      'notificationsEnabled': notificationsEnabled,
      'enableDiscounts': enableDiscounts,
      'defaultDiscount': defaultDiscount,
    };
  }

  factory Settings.fromMap(Map<String, dynamic> map) {
    return Settings(
      userId: map['userId'] ?? '',
      businessName: map['businessName'] ?? '',
      businessAddress: map['businessAddress'] ?? '',
      businessPhone: map['businessPhone'] ?? 'N/A',
      businessEmail: map['businessEmail'] ?? '',
      currency: map['currency'] ?? 'Rs',
      taxRate: map['taxRate'] ?? '0',
      supportPhone: map['supportPhone'] ?? 'N/A',
      businessLogoPath: map['businessLogoPath'] ?? '',
      customFooter: map['customFooter'] ?? 'Thank you for your business!',
      isDarkMode: map['isDarkMode'] ?? false,
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      enableDiscounts: map['enableDiscounts'] ?? true,
      defaultDiscount: (map['defaultDiscount'] is num)
          ? (map['defaultDiscount'] as num).toDouble()
          : 0.0,
    );
  }

  Settings copyWith({
    String? userId,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
    String? currency,
    String? taxRate,
    String? supportPhone,
    String? businessLogoPath,
    String? customFooter,
    bool? isDarkMode,
    bool? notificationsEnabled,
    bool? enableDiscounts,
    double? defaultDiscount,
  }) {
    return Settings(
      userId: userId ?? this.userId,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      businessPhone: businessPhone ?? this.businessPhone,
      businessEmail: businessEmail ?? this.businessEmail,
      currency: currency ?? this.currency,
      taxRate: taxRate ?? this.taxRate,
      supportPhone: supportPhone ?? this.supportPhone,
      businessLogoPath: businessLogoPath ?? this.businessLogoPath,
      customFooter: customFooter ?? this.customFooter,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      enableDiscounts: enableDiscounts ?? this.enableDiscounts,
      defaultDiscount: defaultDiscount ?? this.defaultDiscount,
    );
  }
}
