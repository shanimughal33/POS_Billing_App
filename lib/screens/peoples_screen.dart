import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../repositories/people_repository.dart';
import '../models/people.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../models/activity.dart';
import '../repositories/activity_repository.dart';
import '../themes/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/auth_utils.dart';
import '../utils/refresh_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

// Dummy data model
class Person {
  final int id;
  final String name;
  final String phone;
  final double balance;
  final DateTime lastTransactionDate;
  final String type; // 'customer', 'supplier', or custom

  Person({
    required this.id,
    required this.name,
    required this.phone,
    required this.balance,
    required this.lastTransactionDate,
    required this.type,
  });
}

class PeoplesScreen extends StatefulWidget {
  const PeoplesScreen({Key? key}) : super(key: key);

  @override
  State<PeoplesScreen> createState() => _PeoplesScreenState();
}

class _PeoplesScreenState extends State<PeoplesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<People> _allPeople = [];
  List<People> _filteredPeople = [];
  List<String> _otherCategories = [];
  final int _tabCount = 3; // ALL, Customers, Suppliers
  final PeopleRepository _peopleRepo = PeopleRepository();
  RefreshManager? _refreshManager;

  // Add filter state
  String _sortBy =
      'name_asc'; // name_asc, name_desc, balance_asc, balance_desc, last_txn_asc, last_txn_desc
  String _balanceFilter = 'all'; // all, positive, negative, zero

  // Track if we need to rebuild tabs
  bool _needsTabRebuild = false;

  // Theme-aware text style for filter dialog content
  TextStyle _filterTextStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16);
  }

  @override
  void initState() {
    super.initState();
    _initializeTabController();
    _filteredPeople = [];
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['tab'] is int) {
        final tabIndex = args['tab'] as int;
        if (tabIndex >= 0 && tabIndex < _tabController.length) {
          _tabController.index = tabIndex;
        }
      }

      // Initialize refresh manager
      _refreshManager = Provider.of<RefreshManager>(context, listen: false);
      _refreshManager!.addListener(_onRefreshRequested);
    });
    _loadPeopleFromDb();
  }

  void _onRefreshRequested() {
    if (_refreshManager != null && _refreshManager!.shouldRefreshPeople) {
      debugPrint('PeoplesScreen: Refresh requested, reloading data');
      _loadPeopleFromDb();
      _refreshManager!.clearPeopleRefresh();
    }
  }

  void _initializeTabController() {
    try {
      _tabController = TabController(
        length: _tabCount + _otherCategories.length,
        vsync: this,
      );
    } catch (e) {
      print('Error initializing tab controller: $e');
      // Fallback to minimum length
      _tabController = TabController(length: _tabCount, vsync: this);
    }
  }

  @override
  void dispose() {
    try {
      _tabController.dispose();
    } catch (e) {
      print('Error disposing tab controller: $e');
    }
    _searchController.dispose();
    if (_refreshManager != null) {
      _refreshManager!.removeListener(_onRefreshRequested);
    }
    super.dispose();
  }

  // Validate phone number
  bool _isValidPhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return false;

    // Remove all non-digit characters except +
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Check if it's a valid phone number (at least 10 digits)
    if (cleanNumber.startsWith('+')) {
      return cleanNumber.length >= 12; // +91 + 10 digits
    } else {
      return cleanNumber.length >= 10; // At least 10 digits
    }
  }

  // Debug method to check permissions and capabilities
  Future<void> _debugPermissions() async {
    try {
      final phoneStatus = await Permission.phone.status;
      final phoneRequest = await Permission.phone.request();

      debugPrint('Phone Permission Status: $phoneStatus');
      debugPrint('Phone Permission Request Result: $phoneRequest');

      // Test URL launching capabilities
      final testUri = Uri(scheme: 'tel', path: '1234567890');
      final canLaunchTel = await canLaunchUrl(testUri);
      debugPrint('Can launch tel: URLs: $canLaunchTel');

      final whatsappUri = Uri.parse('https://wa.me/');
      final canLaunchWhatsApp = await canLaunchUrl(whatsappUri);
      debugPrint('Can launch WhatsApp URLs: $canLaunchWhatsApp');
    } catch (e) {
      debugPrint('Error in debug permissions: $e');
    }
  }

  // Request phone permission
  Future<bool> _requestPhonePermission() async {
    try {
      final status = await Permission.phone.request();
      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        _showErrorSnackBar(
          'Phone permission is permanently denied. Please enable it in app settings.',
        );
        return false;
      } else {
        _showErrorSnackBar('Phone permission is required to make calls');
        return false;
      }
    } catch (e) {
      debugPrint('Error requesting phone permission: $e');
      _showErrorSnackBar('Error requesting phone permission');
      return false;
    }
  }

  // Call functionality with confirmation
  Future<void> _makePhoneCall(String phoneNumber) async {
    if (!_isValidPhoneNumber(phoneNumber)) {
      _showErrorSnackBar('Invalid phone number');
      return;
    }

    // Check and request phone permission for Android 6.0+
    if (!await _requestPhonePermission()) {
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.phone, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Make Call?'),
          ],
        ),
        content: Text(
          'Do you want to call ${phoneNumber}?',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Call'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Remove any non-digit characters except + for international numbers
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      debugPrint('Attempting to call: $cleanNumber');

      // Create tel: URL
      final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);
      debugPrint('Phone URI: $phoneUri');

      // Check if we can launch the URL
      final canLaunch = await canLaunchUrl(phoneUri);
      debugPrint('Can launch phone URI: $canLaunch');

      if (canLaunch) {
        final launched = await launchUrl(phoneUri);
        debugPrint('Phone call launched successfully: $launched');
        if (launched) {
          _showSuccessSnackBar('Opening phone dialer...');
        } else {
          _showErrorSnackBar('Failed to open phone dialer');
        }
      } else {
        debugPrint('Could not launch phone call for: $cleanNumber');
        _showErrorSnackBar(
          'Could not open phone dialer. Please check your device settings.',
        );
      }
    } catch (e) {
      debugPrint('Error making phone call: $e');
      _showErrorSnackBar('Error opening phone dialer: ${e.toString()}');
    }
  }

  // Check if WhatsApp is installed
  Future<bool> _isWhatsAppInstalled() async {
    try {
      final Uri whatsappUri = Uri.parse('https://wa.me/');
      return await canLaunchUrl(whatsappUri);
    } catch (e) {
      debugPrint('Error checking WhatsApp installation: $e');
      return false;
    }
  }

  // WhatsApp functionality
  Future<void> _openWhatsApp(String phoneNumber) async {
    if (!_isValidPhoneNumber(phoneNumber)) {
      _showErrorSnackBar('Invalid phone number');
      return;
    }

    // Check if WhatsApp is installed
    if (!await _isWhatsAppInstalled()) {
      _showErrorSnackBar('WhatsApp is not installed on your device');
      return;
    }

    try {
      // Remove any non-digit characters except + for international numbers
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // Remove + if present and add country code if not present
      if (cleanNumber.startsWith('+')) {
        cleanNumber = cleanNumber.substring(1);
      }

      // If number doesn't start with country code, assume it's Indian (+91)
      if (!cleanNumber.startsWith('91') && cleanNumber.length == 10) {
        cleanNumber = '91$cleanNumber';
      }

      // Create WhatsApp URL
      final Uri whatsappUri = Uri.parse('https://wa.me/$cleanNumber');

      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        debugPrint('WhatsApp launched for: $cleanNumber');
        _showSuccessSnackBar('Opening WhatsApp...');
      } else {
        debugPrint('Could not launch WhatsApp for: $cleanNumber');
        _showErrorSnackBar(
          'Could not open WhatsApp. Please make sure WhatsApp is installed.',
        );
      }
    } catch (e) {
      debugPrint('Error opening WhatsApp: $e');
      _showErrorSnackBar('Error opening WhatsApp');
    }
  }

  // Show success snackbar
  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Show error snackbar
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _onTabChanged() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _filterPeople();
    });
  }

  // Safe method to get current tab index
  int _getCurrentTabIndex() {
    try {
      if (!mounted || _tabController.length == 0) {
        return 0;
      }
      final index = _tabController.index;
      if (index < 0 || index >= _tabController.length) {
        return 0;
      }
      return index;
    } catch (e) {
      print('Error getting tab index: $e');
      return 0;
    }
  }

  void _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        String tempSortBy = _sortBy;
        String tempBalanceFilter = _balanceFilter;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Filter & Sort'),
          content: StatefulBuilder(
            builder: (context, setModalState) => SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.45,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                shrinkWrap: true,
                children: [
                  Text('Sort by:', style: _filterTextStyle(context)),
                  RadioListTile<String>(
                    value: 'name_asc',
                    groupValue: tempSortBy,
                    onChanged: (v) => setModalState(() => tempSortBy = v!),
                    title: Text('Name (A-Z)', style: _filterTextStyle(context)),
                    dense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 8,
                    ),
                  ),
                  RadioListTile<String>(
                    value: 'name_desc',
                    groupValue: tempSortBy,
                    onChanged: (v) => setModalState(() => tempSortBy = v!),
                    title: Text('Name (Z-A)', style: _filterTextStyle(context)),
                    dense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 8,
                    ),
                  ),
                  RadioListTile<String>(
                    value: 'balance_desc',
                    groupValue: tempSortBy,
                    onChanged: (v) => setModalState(() => tempSortBy = v!),
                    title: Text(
                      'Balance (High-Low)',
                      style: _filterTextStyle(context),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 8,
                    ),
                  ),
                  RadioListTile<String>(
                    value: 'balance_asc',
                    groupValue: tempSortBy,
                    onChanged: (v) => setModalState(() => tempSortBy = v!),
                    title: Text(
                      'Balance (Low-High)',
                      style: _filterTextStyle(context),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 8,
                    ),
                  ),
                  RadioListTile<String>(
                    value: 'last_txn_desc',
                    groupValue: tempSortBy,
                    onChanged: (v) => setModalState(() => tempSortBy = v!),
                    title: Text(
                      'Last Transaction (Newest)',
                      style: _filterTextStyle(context),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 8,
                    ),
                  ),
                  RadioListTile<String>(
                    value: 'last_txn_asc',
                    groupValue: tempSortBy,
                    onChanged: (v) => setModalState(() => tempSortBy = v!),
                    title: Text(
                      'Last Transaction (Oldest)',
                      style: _filterTextStyle(context),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 8,
                    ),
                  ),
                  const Divider(),
                  Text('Balance filter:', style: _filterTextStyle(context)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: DropdownButton2<String>(
                      value: tempBalanceFilter,
                      isExpanded: true,
                      style: _filterTextStyle(context),
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All', style: _filterTextStyle(context)),
                        ),
                        DropdownMenuItem(
                          value: 'positive',
                          child: Text(
                            'Positive (> 0)',
                            style: _filterTextStyle(context),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'negative',
                          child: Text(
                            'Negative (< 0)',
                            style: _filterTextStyle(context),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'zero',
                          child: Text('Zero', style: _filterTextStyle(context)),
                        ),
                      ],
                      onChanged: (v) =>
                          setModalState(() => tempBalanceFilter = v!),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: AppTheme.getStandardCancelButtonStyle(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _sortBy = tempSortBy;
                  _balanceFilter = tempBalanceFilter;
                  _filterPeople();
                });
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _filterPeople() {
    try {
      if (!mounted) return;

      int idx = _getCurrentTabIndex();
      List<People> filtered = [];

      if (idx == 0) {
        filtered = _allPeople
            .where(
              (p) =>
                  p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  p.phone.contains(_searchQuery),
            )
            .toList();
      } else if (idx == 1) {
        filtered = _allPeople
            .where(
              (p) =>
                  p.category == 'customer' &&
                  (p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      p.phone.contains(_searchQuery)),
            )
            .toList();
      } else if (idx == 2) {
        filtered = _allPeople
            .where(
              (p) =>
                  p.category == 'supplier' &&
                  (p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      p.phone.contains(_searchQuery)),
            )
            .toList();
      } else if (idx >= 3 && idx - 3 < _otherCategories.length) {
        String otherType = _otherCategories[idx - 3];
        filtered = _allPeople
            .where(
              (p) =>
                  p.category == otherType &&
                  (p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      p.phone.contains(_searchQuery)),
            )
            .toList();
      }

      // Apply balance filter
      if (_balanceFilter == 'positive') {
        filtered = filtered.where((p) => p.balance > 0).toList();
      } else if (_balanceFilter == 'negative') {
        filtered = filtered.where((p) => p.balance < 0).toList();
      } else if (_balanceFilter == 'zero') {
        filtered = filtered.where((p) => p.balance == 0).toList();
      }

      // Apply sorting
      switch (_sortBy) {
        case 'name_asc':
          filtered.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          break;
        case 'name_desc':
          filtered.sort(
            (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
          );
          break;
        case 'balance_asc':
          filtered.sort((a, b) => a.balance.compareTo(b.balance));
          break;
        case 'balance_desc':
          filtered.sort((a, b) => b.balance.compareTo(a.balance));
          break;
        case 'last_txn_asc':
          filtered.sort(
            (a, b) => a.lastTransactionDate.compareTo(b.lastTransactionDate),
          );
          break;
        case 'last_txn_desc':
          filtered.sort(
            (a, b) => b.lastTransactionDate.compareTo(a.lastTransactionDate),
          );
          break;
      }

      if (mounted) {
        setState(() {
          _filteredPeople = filtered;
        });
      }
    } catch (e) {
      print('Error filtering people: $e');
    }
  }

  Future<void> _loadPeopleFromDb() async {
    try {
      if (!mounted) return;
      final uid = await getCurrentUserUid();
      debugPrint('PeoplesScreen: _loadPeopleFromDb fetched UID: $uid');
      if (uid == null || uid.isEmpty) {
        setState(() {
          _allPeople = [];
          _otherCategories = [];
        });
        return;
      }
      final people = await _peopleRepo.getAllPeople(uid);

      // Extract unique custom categories from DB
      final customCats = people
          .map((p) => p.category)
          .where((cat) => cat != 'customer' && cat != 'supplier')
          .toSet()
          .toList();

      if (!mounted) return;

      // Check if we need to rebuild tabs
      final needsRebuild =
          _needsTabRebuild ||
          _tabController.length != _tabCount + customCats.length;

      setState(() {
        _allPeople = people;
        _otherCategories = customCats;
      });

      // Rebuild tab controller outside setState to avoid conflicts
      if (needsRebuild && mounted) {
        try {
          _tabController.dispose();
          _initializeTabController();
          _tabController.addListener(_onTabChanged);
          _needsTabRebuild = false;

          // Force rebuild
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          print('Error rebuilding tab controller: $e');
          _needsTabRebuild = false;
        }
      }

      if (mounted) {
        _filterPeople();
      }

      print('--- All People in DB on PeoplesScreen open ---');
      for (final p in people) {
        print(p.toMap());
      }
      print('---------------------------------------------');
    } catch (e) {
      print('Error loading people from DB: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _getTotalBalance(String type) {
    if (type == 'all') {
      return _allPeople.fold(0.0, (sum, p) => sum + p.balance);
    }
    return _allPeople
        .where((p) => p.category == type)
        .fold(0.0, (sum, p) => sum + p.balance);
  }

  // Get all available categories including custom ones
  List<String> _getAllCategories() {
    final baseCategories = ['customer', 'supplier'];
    final allCategories = [...baseCategories, ..._otherCategories, 'other'];
    return allCategories.toSet().toList(); // Remove duplicates
  }

  // Get display names for categories
  String _getCategoryDisplayName(String category) {
    switch (category.toLowerCase()) {
      case 'customer':
        return 'Customer';
      case 'supplier':
        return 'Supplier';
      case 'other':
        return 'Other (Custom Category)';
      default:
        return category.capitalize();
    }
  }

  void _showAddEditPerson({People? person}) async {
    final isEdit = person != null;
    final nameController = TextEditingController(text: person?.name ?? '');
    final phoneController = TextEditingController(text: person?.phone ?? '');
    final balanceController = TextEditingController(
      text: person?.balance.toString() ?? '',
    );
    final notesController = TextEditingController(text: person?.notes ?? '');

    String selectedType = person?.category ?? 'customer';
    bool showOtherInput = false;
    final formKey = GlobalKey<FormState>();
    final newCategoryController = TextEditingController();

    // Determine initial category based on current tab
    if (!isEdit) {
      int idx = _tabController.index;
      if (idx == 1) {
        selectedType = 'customer';
      } else if (idx == 2) {
        selectedType = 'supplier';
      } else if (idx >= 3) {
        selectedType = _otherCategories[idx - 3];
      }
    }

    Future<void> _pickContact() async {
      if (await FlutterContacts.requestPermission(readonly: false)) {
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
        );
        if (contacts.isNotEmpty) {
          final contact = await showGeneralDialog<Contact?>(
            context: context,
            barrierDismissible: true,
            barrierLabel: 'Contacts',
            transitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (context, anim1, anim2) {
              final maxHeight = MediaQuery.of(context).size.height * 0.6;
              return Align(
                alignment: Alignment.center,
                child: Material(
                  color: Colors.transparent,
                  child: FadeTransition(
                    opacity: anim1,
                    child: Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : Colors.white,
                      child: Container(
                        constraints: BoxConstraints(
                          maxHeight: maxHeight > 350 ? 350 : maxHeight,
                          minWidth: 260,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 10,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Select a contact',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF128C7E),
                              ),
                            ),
                            const Divider(height: 18, thickness: 1),
                            Expanded(
                              child: Scrollbar(
                                child: ListView.separated(
                                  itemCount: contacts
                                      .where((c) => c.phones.isNotEmpty)
                                      .length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: Colors.grey[200],
                                  ),
                                  itemBuilder: (context, i) {
                                    final c = contacts
                                        .where((c) => c.phones.isNotEmpty)
                                        .toList()[i];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Color(
                                          0xFF128C7E,
                                        ).withAlpha((0.13 * 255).toInt()),
                                        child: Text(
                                          c.displayName.isNotEmpty
                                              ? c.displayName[0].toUpperCase()
                                              : '',
                                          style: const TextStyle(
                                            color: Color(0xFF128C7E),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        c.displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      subtitle: Text(
                                        c.phones.first.number,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      onTap: () => Navigator.pop(context, c),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            transitionBuilder: (context, anim1, anim2, child) {
              return FadeTransition(opacity: anim1, child: child);
            },
          );
          if (contact != null && contact.phones.isNotEmpty) {
            phoneController.text = contact.phones.first.number;
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact permission denied.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 48),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(context),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Edit Person' : 'Add Person',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _buildAttractiveTextField(
                        context,
                        nameController,
                        'Name',
                        Icons.person,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Name is required';
                          final namePattern = RegExp(r'^[a-zA-Z\-\s]{2,50}$');
                          if (!namePattern.hasMatch(val.trim()))
                            return 'Name must be 2-50 letters, spaces, or dashes only.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildAttractiveTextField(
                        context,
                        phoneController,
                        'Contact No',
                        Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Contact No is required';
                          final phone = val.trim();
                          final pkPattern = RegExp(r'^(03\d{9}|\+923\d{9})$');
                          if (!pkPattern.hasMatch(phone)) {
                            return 'Enter valid PK number (03XXXXXXXXX or +923XXXXXXXXX)';
                          }
                          return null;
                        },
                        suffixIcon: Icons.contacts,
                        onTap: null, // Only open contact picker from suffixIcon
                        onSuffixIconTap: _pickContact,
                      ),
                      const SizedBox(height: 18),
                      _buildAttractiveTextField(
                        context,
                        balanceController,
                        'Balance',
                        Icons.account_balance_wallet,
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Balance is required';
                          if (double.tryParse(val.trim()) == null)
                            return 'Enter a valid number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildAttractiveTextField(
                        context,
                        notesController,
                        'Notes',
                        Icons.note,
                        maxLines: 2,
                        validator: (val) {
                          if (val != null && val.length > 100) {
                            return 'Notes can be at most 100 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildAttractiveDropdown(
                        context,
                        selectedType,
                        'Category',
                        Icons.category,
                        _getAllCategories(),
                        (value) {
                          setModalState(() {
                            selectedType = value!;
                            showOtherInput = value == 'other';
                            if (showOtherInput) {
                              newCategoryController.clear();
                            }
                          });
                        },
                        getDisplayName: _getCategoryDisplayName,
                      ),
                      if (showOtherInput)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildAttractiveTextField(
                            context,
                            newCategoryController,
                            'New Category Name',
                            Icons.category,
                            onChanged: (value) {
                              // newOtherType = value; // This variable was removed
                            },
                            validator: (val) {
                              if (showOtherInput &&
                                  (val == null || val.trim().isEmpty))
                                return 'Category name required';
                              if (val != null && val.trim().isNotEmpty) {
                                final trimmedValue = val.trim().toLowerCase();
                                if (trimmedValue == 'customer' ||
                                    trimmedValue == 'supplier') {
                                  return 'Category name cannot be "customer" or "supplier"';
                                }
                                if (_otherCategories.contains(trimmedValue)) {
                                  return 'Category already exists';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Color(0xFF1976D2),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: AppTheme.getGradientDecoration(),
                            child: ElevatedButton(
                              style: AppTheme.getGradientSaveButtonStyle(
                                context,
                              ),

                              // Refactored People Save Button without async/await for offline-first approach
                              onPressed: () {
                                if (!mounted) return;
                                getCurrentUserUid()
                                    .then((uid) {
                                      debugPrint(
                                        'PeoplesScreen: Save/Add pressed, fetched UID: \$uid',
                                      );
                                      if (uid == null || uid.isEmpty) {
                                        debugPrint(
                                          'PeoplesScreen: ERROR: UID is null or empty!',
                                        );
                                        return;
                                      }

                                      String typeToUse = selectedType;

                                      if (showOtherInput &&
                                          newCategoryController.text
                                              .trim()
                                              .isNotEmpty) {
                                        typeToUse = newCategoryController.text
                                            .trim()
                                            .toLowerCase();

                                        if (typeToUse.isEmpty ||
                                            typeToUse == 'customer' ||
                                            typeToUse == 'supplier') {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                typeToUse.isEmpty
                                                    ? 'Please enter a valid category name'
                                                    : 'Category name cannot be "customer" or "supplier"',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }

                                        if (_otherCategories.contains(
                                          typeToUse,
                                        )) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Category "\$typeToUse" already exists',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }
                                      }

                                      if (!formKey.currentState!.validate())
                                        return;

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Saving...'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );

                                      if (isEdit) {
                                        final updatedPerson = People(
                                          id: person!.id,
                                          userId: uid,
                                          name: nameController.text.trim(),
                                          phone: phoneController.text.trim(),
                                          category: typeToUse,
                                          balance:
                                              double.tryParse(
                                                balanceController.text.trim(),
                                              ) ??
                                              0,
                                          lastTransactionDate: DateTime.now(),
                                          notes:
                                              notesController.text
                                                  .trim()
                                                  .isNotEmpty
                                              ? notesController.text.trim()
                                              : null,
                                        );

                                        _peopleRepo.updatePerson(updatedPerson).then((
                                          _,
                                        ) {
                                          ActivityRepository().logActivity(
                                            Activity(
                                              userId: uid,
                                              type: 'people_edit',
                                              description:
                                                  'Edited person: ${updatedPerson.name} (${updatedPerson.phone})',
                                              timestamp: DateTime.now(),
                                              metadata: {
                                                'id': updatedPerson.id,
                                                'name': updatedPerson.name,
                                                'phone': updatedPerson.phone,
                                                'category':
                                                    updatedPerson.category,
                                                'balance': updatedPerson.balance
                                                    .toString(),
                                              },
                                            ),
                                          );
                                          _loadPeopleFromDb();
                                          if (mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Person updated successfully',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        });
                                      } else {
                                        final newPerson = People(
                                          userId: uid,
                                          name: nameController.text.trim(),
                                          phone: phoneController.text.trim(),
                                          category: typeToUse,
                                          balance:
                                              double.tryParse(
                                                balanceController.text.trim(),
                                              ) ??
                                              0,
                                          lastTransactionDate: DateTime.now(),
                                          notes:
                                              notesController.text
                                                  .trim()
                                                  .isNotEmpty
                                              ? notesController.text.trim()
                                              : null,
                                        );

                                        _peopleRepo.insertPerson(newPerson).then((
                                          id,
                                        ) {
                                          RefreshManager().refreshPeople();
                                          RefreshManager().refreshDashboard();

                                          if (id.isNotEmpty) {
                                            if (showOtherInput &&
                                                newCategoryController.text
                                                    .trim()
                                                    .isNotEmpty) {
                                              final newCategory =
                                                  newCategoryController.text
                                                      .trim()
                                                      .toLowerCase();
                                              if (!_otherCategories.contains(
                                                newCategory,
                                              )) {
                                                setState(() {
                                                  _otherCategories.add(
                                                    newCategory,
                                                  );
                                                  _needsTabRebuild = true;
                                                });
                                              }
                                            }

                                            _loadPeopleFromDb();

                                            SharedPreferences.getInstance().then((
                                              prefs,
                                            ) {
                                              final userId =
                                                  prefs.getString(
                                                    'current_uid',
                                                  ) ??
                                                  '';
                                              ActivityRepository().logActivity(
                                                Activity(
                                                  userId: userId,
                                                  type: 'people_add',
                                                  description:
                                                      'Added person: ${newPerson.name} (${newPerson.phone})',
                                                  timestamp: DateTime.now(),
                                                  metadata: {
                                                    'id': id,
                                                    'name': newPerson.name,
                                                    'phone': newPerson.phone,
                                                    'category':
                                                        newPerson.category,
                                                    'balance': newPerson.balance
                                                        .toString(),
                                                  },
                                                ),
                                              );
                                            });

                                            if (mounted) {
                                              Navigator.pop(context);
                                              if (showOtherInput &&
                                                  newCategoryController.text
                                                      .trim()
                                                      .isNotEmpty) {
                                                final newCategory =
                                                    newCategoryController.text
                                                        .trim()
                                                        .toLowerCase();
                                                WidgetsBinding.instance
                                                    .addPostFrameCallback((_) {
                                                      if (mounted) {
                                                        try {
                                                          final newCategoryIndex =
                                                              _otherCategories
                                                                  .indexOf(
                                                                    newCategory,
                                                                  ) +
                                                              3;
                                                          if (newCategoryIndex >=
                                                                  3 &&
                                                              newCategoryIndex <
                                                                  _tabController
                                                                      .length) {
                                                            _tabController
                                                                .animateTo(
                                                                  newCategoryIndex,
                                                                );
                                                          }
                                                        } catch (e) {
                                                          print(
                                                            'Error switching to new category tab: \$e',
                                                          );
                                                        }
                                                      }
                                                    });
                                              }

                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Person added successfully',
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } else {
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Failed to save person',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        });
                                      }
                                    })
                                    .catchError((e) {
                                      print('Error in save operation: \$e');
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error saving person: \$e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    });
                              },

                              child: Text(isEdit ? 'Save' : 'Add'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _deletePerson(People person) async {
    final uid = await getCurrentUserUid();
    debugPrint('PeoplesScreen: _deletePerson fetched UID: $uid');
    if (uid == null || uid.isEmpty) return;
    await _peopleRepo.deletePerson(person.id! as String, uid);

    // Trigger refresh for all screens
    RefreshManager().refreshPeople();
    await ActivityRepository().logActivity(
      Activity(
        userId: uid,
        type: 'people_delete',
        description: 'Deleted person: ${person.name} (${person.phone})',
        timestamp: DateTime.now(),
        metadata: {
          'id': person.id,
          'name': person.name,
          'phone': person.phone,
          'category': person.category,
          'balance': person.balance,
        },
      ),
    );
    await _loadPeopleFromDb();
  }

  void _deleteOtherCategory(int idx) async {
    try {
      final categoryToDelete = _otherCategories[idx];

      // First, update all people in this category to 'customer'
      final peopleInCategory = _allPeople
          .where((p) => p.category == categoryToDelete)
          .toList();
      for (final person in peopleInCategory) {
        final updatedPerson = person.copyWith(category: 'customer');
        await _peopleRepo.updatePerson(updatedPerson);
      }

      // Then remove the category and rebuild
      setState(() {
        _otherCategories.removeAt(idx);
        _needsTabRebuild = true;
      });

      await _loadPeopleFromDb();
    } catch (e) {
      print('Error deleting category: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting category: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accentGreen = const Color(0xFF128C7E);
    int idx = _getCurrentTabIndex();
    try {
      String type = idx == 0
          ? 'all'
          : idx == 1
          ? 'customer'
          : idx == 2
          ? 'supplier'
          : idx >= 3 && idx - 3 < _otherCategories.length
          ? _otherCategories[idx - 3]
          : '';
      String totalLabel = idx == 0
          ? 'Total Balance'
          : idx == 1
          ? 'Total Receivables'
          : idx == 2
          ? 'Total Payables'
          : idx >= 3 && idx - 3 < _otherCategories.length
          ? '${type.capitalize()} Total'
          : '';
      final tabLength = _tabCount + _otherCategories.length;
      return DefaultTabController(
        length: tabLength,
        child: Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0A2342)
              : Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1A2233)
                : Colors.white,
            centerTitle: true,
            title: Text(
              'People',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Color(0xFF0A2342),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            iconTheme: IconThemeData(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Color(0xFF0A2342),
            ),
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: BouncingScrollPhysics(),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicator: UnderlineTabIndicator(
                      borderSide: BorderSide(
                        width: 3,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                    labelColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Color(0xFF1976D2),
                    unselectedLabelColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.7)
                        : Color(0xFF1976D2),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 15,
                    ),
                    tabs: [
                      const Tab(text: 'ALL'),
                      const Tab(text: 'Customers'),
                      const Tab(text: 'Suppliers'),
                      ..._otherCategories.asMap().entries.map(
                        (entry) => Tab(
                          child: Row(
                            children: [
                              Text(
                                entry.value.capitalize(),
                                style: TextStyle(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Color(0xFF1976D2),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _deleteOtherCategory(entry.key),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Color(0xFF1976D2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Container(
                    width: double.infinity,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF0A2342),
                          Color(0xFF123060),
                          Color(0xFF1976D2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          flex: 2,
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  totalLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    letterSpacing: 0.5,
                                    overflow: TextOverflow.ellipsis,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          flex: 1,
                          child: Text(
                            'Rs ${_getTotalBalance(type).toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 0.5,
                              overflow: TextOverflow.ellipsis,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                            _filterPeople();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone...',
                          prefixIcon: Icon(Icons.search, color: accentGreen),
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF0A2342),
                            Color(0xFF123060),
                            Color(0xFF1976D2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.filter_alt, color: Colors.white),
                        onPressed: _showFilterDialog,
                        tooltip: 'Filter & Sort',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _filteredPeople.isEmpty
                    ? Center(
                        child: Text(
                          'No Peoples Found',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredPeople.length,
                        itemBuilder: (context, idx) {
                          final person = _filteredPeople[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Dismissible(
                              key: ValueKey(person.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFDC3545)
                                      : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.delete,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.red,
                                  size: 32,
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withAlpha(
                                              (0.1 * 255).toInt(),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.warning_rounded,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Delete Person?'),
                                      ],
                                    ),
                                    content: Text(
                                      'Are you sure you want to delete "${person.name}"? This action cannot be undone.',
                                      style: TextStyle(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                return confirmed;
                              },
                              onDismissed: (direction) {
                                setState(() {
                                  _filteredPeople.removeAt(idx);
                                });
                                _deletePerson(person);
                              },
                              child: Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () =>
                                      _showAddEditPerson(person: person),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    constraints: const BoxConstraints(
                                      minHeight: 72,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFF013A63)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Color(
                                            0xFF1976D2,
                                          ).withAlpha((0.12 * 255).toInt()),
                                          child: Icon(
                                            person.category == 'customer'
                                                ? Icons.person
                                                : person.category == 'supplier'
                                                ? Icons.local_shipping
                                                : Icons.category,
                                            color: Color(0xFF1976D2),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                person.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color:
                                                      Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                person.phone,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? Colors.white
                                                            .withOpacity(0.8)
                                                      : Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.color,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Text(
                                                    'Balance: ',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color:
                                                          Theme.of(
                                                                context,
                                                              ).brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                                .withOpacity(
                                                                  0.8,
                                                                )
                                                          : Theme.of(context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.color,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Rs ${person.balance.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: person.balance < 0
                                                          ? Colors.red
                                                          : Theme.of(
                                                                  context,
                                                                ).brightness ==
                                                                Brightness.dark
                                                          ? Colors.white
                                                          : Theme.of(context)
                                                                .colorScheme
                                                                .primary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Container(
                                                alignment: Alignment.bottomLeft,
                                                child: Text(
                                                  DateFormat(
                                                    'dd MMM, yyyy',
                                                  ).format(
                                                    person.lastTransactionDate,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.dark
                                                        ? Colors.white
                                                              .withOpacity(0.6)
                                                        : Theme.of(context)
                                                              .textTheme
                                                              .bodySmall
                                                              ?.color,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            minWidth: 10,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Container(
                                                alignment: Alignment.center,
                                                child: PopupMenuButton<String>(
                                                  icon: Icon(
                                                    Icons.more_vert,
                                                    color:
                                                        Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.dark
                                                        ? Colors.white
                                                        : Theme.of(context)
                                                              .textTheme
                                                              .bodySmall
                                                              ?.color,
                                                    size: 22,
                                                  ),
                                                  onSelected: (value) {
                                                    if (value == 'call') {
                                                      _makePhoneCall(
                                                        person.phone,
                                                      );
                                                    } else if (value ==
                                                        'whatsapp') {
                                                      _openWhatsApp(
                                                        person.phone,
                                                      );
                                                    } else if (value ==
                                                        'details') {
                                                      showDialog(
                                                        context: context,
                                                        builder: (ctx) => AlertDialog(
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  18,
                                                                ),
                                                          ),
                                                          content: SizedBox(
                                                            height:
                                                                MediaQuery.of(
                                                                          context,
                                                                        ).size.height *
                                                                        0.5 >
                                                                    300
                                                                ? 300
                                                                : MediaQuery.of(
                                                                        context,
                                                                      ).size.height *
                                                                      0.5,
                                                            child: Scrollbar(
                                                              thumbVisibility:
                                                                  true,
                                                              child: SingleChildScrollView(
                                                                padding:
                                                                    EdgeInsets.all(
                                                                      18,
                                                                    ),
                                                                child: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      'Description:',
                                                                      style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: Color(
                                                                          0xFF128C7E,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    SizedBox(
                                                                      height: 6,
                                                                    ),
                                                                    Text(
                                                                      person.description ??
                                                                          'No description',
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            15,
                                                                      ),
                                                                    ),
                                                                    SizedBox(
                                                                      height:
                                                                          14,
                                                                    ),
                                                                    Text(
                                                                      'Notes:',
                                                                      style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: Color(
                                                                          0xFF128C7E,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    SizedBox(
                                                                      height: 6,
                                                                    ),
                                                                    Text(
                                                                      person.notes ??
                                                                          'No notes',
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            15,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    ctx,
                                                                  ),
                                                              child: Text(
                                                                'Close',
                                                                style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    PopupMenuItem(
                                                      value: 'details',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.info_outline,
                                                            color: Color(
                                                              0xFF128C7E,
                                                            ),
                                                            size: 18,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text('Details'),
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'call',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.call,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
                                                            size: 18,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text('Call'),
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'whatsapp',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            FontAwesomeIcons
                                                                .whatsapp,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
                                                            size: 18,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text('WhatsApp'),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0A2342),
                  Color(0xFF123060),
                  Color(0xFF1976D2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.add, color: Colors.white, size: 32),
              onPressed: () => _showAddEditPerson(),
              tooltip: 'Add Person',
            ),
          ),
        ),
      );
    } catch (e) {
      print('Error in build method: ' + e.toString());
      return Scaffold(
        appBar: AppBar(
          title: const Text('Peoples'),
          backgroundColor: const Color(0xFF128C7E),
        ),
        body: const Center(
          child: Text('Error loading screen. Please restart the app.'),
        ),
      );
    }
  }
}

extension StringCasingExtension on String {
  String capitalize() =>
      isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
}

Widget _buildAttractiveTextField(
  BuildContext context,
  TextEditingController controller,
  String label,
  IconData icon, {
  TextInputType? keyboardType,
  int maxLines = 1,
  String? Function(String?)? validator,
  IconData? suffixIcon,
  VoidCallback? onTap,
  VoidCallback? onSuffixIconTap,
  ValueChanged<String>? onChanged,
}) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    validator: validator,
    onTap: onTap,
    onChanged: onChanged,
    style: TextStyle(color: AppTheme.getTextColor(context)),
    decoration: AppTheme.getStandardInputDecoration(
      context,
      labelText: label,
      hintText: label,
      prefixIcon: icon,
      suffixIcon: suffixIcon,
      onSuffixIconTap: onSuffixIconTap,
    ),
  );
}

Widget _buildAttractiveDropdown(
  BuildContext context,
  String value,
  String label,
  IconData icon,
  List<String> items,
  void Function(String?) onChanged, {
  String Function(String)? getDisplayName,
}) {
  return Material(
    elevation: 1.0,
    borderRadius: BorderRadius.circular(12),
    shadowColor: AppTheme.getShadowColor(context),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.getBackgroundColor(context),
      ),
      child: DropdownButtonFormField2<String>(
        value: value,
        isExpanded: true,
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.getTextColor(context),
          fontWeight: FontWeight.w500,
        ),
        dropdownStyleData: DropdownStyleData(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.getBackgroundColor(context),
            boxShadow: [
              BoxShadow(
                color: AppTheme.getShadowColor(context),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          offset: const Offset(0, -4),
        ),
        decoration: AppTheme.getStandardInputDecoration(
          context,
          labelText: label,
          hintText: label,
          prefixIcon: icon,
          isDropdown: true,
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              getDisplayName?.call(item) ?? item,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getTextColor(context),
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    ),
  );
}
