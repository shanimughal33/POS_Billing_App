import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../repositories/people_repository.dart';
import '../models/people.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../models/activity.dart';
import '../repositories/activity_repository.dart';
import '../utils/app_theme.dart';

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

  // Add filter state
  String _sortBy =
      'name_asc'; // name_asc, name_desc, balance_asc, balance_desc, last_txn_asc, last_txn_desc
  String _balanceFilter = 'all'; // all, positive, negative, zero

  // Track if we need to rebuild tabs
  bool _needsTabRebuild = false;

  static const TextStyle filterTextStyle = TextStyle(
    color: Colors.black,
    fontSize: 16,
  );

  @override
  void initState() {
    super.initState();
    _initializeTabController();
    _filteredPeople = [];
    _tabController.addListener(_onTabChanged);
    _loadPeopleFromDb();
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
    super.dispose();
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
            builder: (context, setModalState) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Sort by:', style: filterTextStyle),
                    RadioListTile<String>(
                      value: 'name_asc',
                      groupValue: tempSortBy,
                      onChanged: (v) => setModalState(() => tempSortBy = v!),
                      title: const Text('Name (A-Z)', style: filterTextStyle),
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
                      title: const Text('Name (Z-A)', style: filterTextStyle),
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
                      title: const Text(
                        'Balance (High-Low)',
                        style: filterTextStyle,
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
                      title: const Text(
                        'Balance (Low-High)',
                        style: filterTextStyle,
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
                      title: const Text(
                        'Last Transaction (Newest)',
                        style: filterTextStyle,
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
                      title: const Text(
                        'Last Transaction (Oldest)',
                        style: filterTextStyle,
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 8,
                      ),
                    ),
                    const Divider(),
                    const Text('Balance filter:', style: filterTextStyle),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: DropdownButton2<String>(
                        value: tempBalanceFilter,
                        isExpanded: true,
                        style: filterTextStyle,
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All', style: filterTextStyle),
                          ),
                          DropdownMenuItem(
                            value: 'positive',
                            child: Text(
                              'Positive (> 0)',
                              style: filterTextStyle,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'negative',
                            child: Text(
                              'Negative (< 0)',
                              style: filterTextStyle,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'zero',
                            child: Text('Zero', style: filterTextStyle),
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
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

      final people = await _peopleRepo.getAllPeople();

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
                      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
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
              color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
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
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Color(0xFF1976D2),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              side: BorderSide.none,
                            ),
                            onPressed: () async {
                              // Disable button to prevent multiple presses
                              if (!mounted) return;

                              try {
                                String typeToUse = selectedType;

                                // Handle custom category creation
                                if (showOtherInput &&
                                    newCategoryController.text
                                        .trim()
                                        .isNotEmpty) {
                                  typeToUse = newCategoryController.text
                                      .trim()
                                      .toLowerCase();

                                  // Validate custom category name
                                  if (typeToUse.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please enter a valid category name',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  if (typeToUse == 'customer' ||
                                      typeToUse == 'supplier') {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Category name cannot be "customer" or "supplier"',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  if (_otherCategories.contains(typeToUse)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Category "$typeToUse" already exists',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                }

                                // Validate form
                                if (!formKey.currentState!.validate()) {
                                  return;
                                }

                                // Show loading indicator
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Saving...'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );

                                if (isEdit) {
                                  // Update existing person
                                  final updatedPerson = People(
                                    id: person!.id,
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
                                        notesController.text.trim().isNotEmpty
                                        ? notesController.text.trim()
                                        : null,
                                  );

                                  await _peopleRepo.updatePerson(updatedPerson);
                                  await ActivityRepository().logActivity(
                                    Activity(
                                      type: 'people_edit',
                                      description:
                                          'Edited person: ${nameController.text.trim()} (${phoneController.text.trim()})',
                                      timestamp: DateTime.now(),
                                      metadata: {
                                        'id': person!.id,
                                        'name': nameController.text.trim(),
                                        'phone': phoneController.text.trim(),
                                        'category': typeToUse,
                                        'balance': balanceController.text
                                            .trim(),
                                      },
                                    ),
                                  );
                                  await _loadPeopleFromDb();

                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Person updated successfully',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } else {
                                  // Create new person
                                  final newPerson = People(
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
                                        notesController.text.trim().isNotEmpty
                                        ? notesController.text.trim()
                                        : null,
                                  );

                                  final id = await _peopleRepo.insertPerson(
                                    newPerson,
                                  );

                                  if (id > 0) {
                                    // Add new category to list if it's custom
                                    if (showOtherInput &&
                                        newCategoryController.text
                                            .trim()
                                            .isNotEmpty) {
                                      final newCategory = newCategoryController
                                          .text
                                          .trim()
                                          .toLowerCase();
                                      if (!_otherCategories.contains(
                                        newCategory,
                                      )) {
                                        setState(() {
                                          _otherCategories.add(newCategory);
                                          _needsTabRebuild = true;
                                        });
                                      }
                                    }

                                    // Reload data
                                    await _loadPeopleFromDb();

                                    // Log activity for adding a person (ensure this is always called)
                                    try {
                                      await ActivityRepository().logActivity(
                                        Activity(
                                          type: 'people_add',
                                          description:
                                              'Added person: ${nameController.text.trim()} (${phoneController.text.trim()})',
                                          timestamp: DateTime.now(),
                                          metadata: {
                                            'id': id, // Use the returned id
                                            'name': nameController.text.trim(),
                                            'phone': phoneController.text
                                                .trim(),
                                            'category': typeToUse,
                                            'balance': balanceController.text
                                                .trim(),
                                          },
                                        ),
                                      );
                                    } catch (e) {
                                      print(
                                        'Error logging add person activity: ${e.toString()}',
                                      );
                                    }

                                    if (mounted) {
                                      Navigator.pop(context);

                                      // Switch to new category tab if it's custom
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
                                                      _otherCategories.indexOf(
                                                        newCategory,
                                                      ) +
                                                      3;
                                                  if (newCategoryIndex >= 3 &&
                                                      newCategoryIndex <
                                                          _tabController
                                                              .length) {
                                                    _tabController.animateTo(
                                                      newCategoryIndex,
                                                    );
                                                  }
                                                } catch (e) {
                                                  print(
                                                    'Error switching to new category tab: $e',
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
                                }
                              } catch (e) {
                                print('Error in save operation: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error saving person: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(
                              isEdit ? 'Save' : 'Add',
                              style: const TextStyle(color: Color(0xFF1976D2)),
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
    await _peopleRepo.deletePerson(person.id!);
    await ActivityRepository().logActivity(
      Activity(
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
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F0F0F) : Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A2233) : Colors.white,
            centerTitle: true,
            title: Text(
              'People',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0A2342),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            iconTheme: IconThemeData(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(0xFF0A2342)),
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
                    labelColor: Color(0xFF1976D2),
                    unselectedLabelColor: Color(0xFF1976D2),
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
                                style: TextStyle(color: Color(0xFF1976D2)),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _deleteOtherCategory(entry.key),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Color(0xFF1976D2),
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
                    suffixIcon: IconButton(
                      icon: Icon(Icons.filter_alt, color: accentGreen),
                      tooltip: 'Filter & Sort',
                      onPressed: _showFilterDialog,
                    ),
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
              Expanded(
                child: _filteredPeople.isEmpty
                    ? Center(
                        child: Text(
                          'No Peoples Found',
                          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 16),
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
                                  color: Theme.of(context).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.delete,
                                  color: Theme.of(context).colorScheme.error,
                                  size: 32,
                                ),
                              ),
                              onDismissed: (direction) {
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
                                      color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF232A36) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                person.phone,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Theme.of(context).textTheme.bodyMedium?.color,
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
                                                      color: Theme.of(context).textTheme.bodyMedium?.color,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Rs ${person.balance.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: person.balance < 0
                                                          ? Theme.of(context).colorScheme.error
                                                          : Theme.of(context).colorScheme.primary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      DateFormat(
                                                        'dd MMM, yyyy',
                                                      ).format(
                                                        person
                                                            .lastTransactionDate,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Theme.of(context).textTheme.bodySmall?.color,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
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
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.receipt_long,
                                                  color: Color(0xFF1976D2),
                                                  size: 20,
                                                ),
                                                onPressed: () {},
                                                tooltip: 'Ledger',
                                              ),
                                              PopupMenuButton<String>(
                                                icon: Icon(
                                                  Icons.more_vert,
                                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                                  size: 22,
                                                ),
                                                onSelected: (value) {
                                                  if (value == 'call') {
                                                    // Implement call logic here
                                                  } else if (value ==
                                                      'whatsapp') {
                                                    // Implement WhatsApp logic here
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
                                                                          FontWeight
                                                                              .bold,
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
                                                                    height: 14,
                                                                  ),
                                                                  Text(
                                                                    'Notes:',
                                                                    style: TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
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
                                                          color: Theme.of(context).colorScheme.primary,
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
                                                          color: Theme.of(context).colorScheme.primary,
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
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final mainColor = isDark ? Colors.white : Color(0xFF1976D2);
  final veryLightBlue = isDark ? Color(0xFF90CAF9) : Color(0xFFB3D8FD);
  return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
    validator: validator,
      onTap: onTap,
      onChanged: onChanged,
    style: TextStyle(color: mainColor),
      decoration: InputDecoration(
        labelText: label,
      labelStyle: TextStyle(color: mainColor, fontWeight: FontWeight.w600),
      hintText: label,
      hintStyle: TextStyle(color: veryLightBlue),
      prefixIcon: Icon(icon, color: mainColor),
        suffixIcon: suffixIcon != null
            ? GestureDetector(
                onTap: onSuffixIconTap,
              child: Icon(suffixIcon, color: mainColor),
              )
            : null,
      filled: true,
      fillColor: isDark ? Colors.black : Colors.white,
        border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: veryLightBlue),
        ),
        enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: veryLightBlue),
        ),
        focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: veryLightBlue, width: 2),
      ),
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
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final mainColor = isDark ? Colors.white : Color(0xFF1976D2);
  return Material(
    elevation: 1.0,
    borderRadius: BorderRadius.circular(10),
    shadowColor: Theme.of(context).shadowColor,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isDark ? Colors.black : Colors.white,
      ),
      child: DropdownButtonFormField2<String>(
        value: value,
        isExpanded: true,
        style: TextStyle(
          fontSize: 14,
          color: mainColor,
          fontWeight: FontWeight.w500,
        ),
        dropdownStyleData: DropdownStyleData(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isDark ? Colors.black : Colors.white,
            boxShadow: [
              BoxShadow(
                color: mainColor.withAlpha((0.1 * 255).toInt()),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          offset: const Offset(0, -4),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: mainColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(icon, color: mainColor, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: mainColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: mainColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: mainColor, width: 1.5),
          ),
          filled: true,
          fillColor: isDark ? Colors.black : Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 12,
          ),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              getDisplayName?.call(item) ?? item,
              style: TextStyle(fontSize: 14, color: mainColor),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    ),
  );
}
