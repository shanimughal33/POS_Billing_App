import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../repositories/people_repository.dart';
import '../models/people.dart';

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
  final List<String> _otherCategories = [];
  int _tabCount = 4; // ALL, Customers, Suppliers, Others(+)
  final PeopleRepository _peopleRepo = PeopleRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabCount + _otherCategories.length,
      vsync: this,
    );
    _filteredPeople = [];
    _tabController.addListener(_onTabChanged);
    _loadPeopleFromDb();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  void _filterPeople() {
    int idx = _tabController.index;
    if (idx == 0) {
      // ALL
      setState(() {
        _filteredPeople = _allPeople
            .where(
              (p) =>
                  p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  p.phone.contains(_searchQuery),
            )
            .toList();
      });
    } else if (idx == 1) {
      // Customers
      setState(() {
        _filteredPeople = _allPeople
            .where(
              (p) =>
                  p.category == 'customer' &&
                  (p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      p.phone.contains(_searchQuery)),
            )
            .toList();
      });
    } else if (idx == 2) {
      // Suppliers
      setState(() {
        _filteredPeople = _allPeople
            .where(
              (p) =>
                  p.category == 'supplier' &&
                  (p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      p.phone.contains(_searchQuery)),
            )
            .toList();
      });
    } else if (idx == 3) {
      // Others (+)
      setState(() {
        _filteredPeople = [];
      });
    } else {
      // Custom other categories
      String otherType = _otherCategories[idx - 4];
      setState(() {
        _filteredPeople = _allPeople
            .where(
              (p) =>
                  p.category == otherType &&
                  (p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      p.phone.contains(_searchQuery)),
            )
            .toList();
      });
    }
  }

  Future<void> _loadPeopleFromDb() async {
    final people = await _peopleRepo.getAllPeople();
    setState(() {
      _allPeople = people;
      _filterPeople();
    });
    print('--- All People in DB on PeoplesScreen open ---');
    for (final p in people) {
      print(p.toMap());
    }
    print('---------------------------------------------');
  }

  double _getTotalBalance(String type) {
    if (type == 'all') {
      return _allPeople.fold(0.0, (sum, p) => sum + p.balance);
    }
    return _allPeople
        .where((p) => p.category == type)
        .fold(0.0, (sum, p) => sum + p.balance);
  }

  void _showAddEditPerson({People? person}) async {
    final isEdit = person != null;
    final nameController = TextEditingController(text: person?.name ?? '');
    final phoneController = TextEditingController(text: person?.phone ?? '');
    final balanceController = TextEditingController(
      text: person?.balance.toString() ?? '',
    );
    String selectedType =
        person?.category ??
        (_tabController.index == 0
            ? 'customer'
            : _tabController.index == 1
            ? 'customer'
            : _tabController.index == 2
            ? 'supplier'
            : (_tabController.index >= 4
                  ? _otherCategories[_tabController.index - 4]
                  : 'customer'));
    String newOtherType = '';
    bool showOtherInput = false;
    final _formKey = GlobalKey<FormState>();

    // Future<void> _pickContact() async {
    //   try {
    //     final Contact? contact =
    //         await ContactsService.openDeviceContactPicker();
    //     if (contact != null &&
    //         contact.phones != null &&
    //         contact.phones!.isNotEmpty) {
    //       phoneController.text = contact.phones!.first.value ?? '';
    //     }
    //   } catch (e) {
    //     // Handle error or permissions
    //   }
    // }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Edit Person' : 'Add Person',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF128C7E),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty)
                        return 'Name is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.contacts,
                          color: Color(0xFF128C7E),
                        ),
                        tooltip: 'Pick from contacts',
                        onPressed: () {
                          // _pickContact();
                        },
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty)
                        return 'Phone is required';
                      final phone = val.trim();
                      final pkPattern = RegExp(r'^(03\d{9}|\+92\d{10})$');
                      if (!pkPattern.hasMatch(phone)) {
                        return 'Enter valid PK number (03XXXXXXXXX or +92XXXXXXXXXX)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: balanceController,
                    decoration: const InputDecoration(labelText: 'Balance'),
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty)
                        return 'Balance is required';
                      if (double.tryParse(val.trim()) == null)
                        return 'Enter a valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Color(0xFF128C7E)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'customer',
                        child: Text('Customer'),
                      ),
                      const DropdownMenuItem(
                        value: 'supplier',
                        child: Text('Supplier'),
                      ),
                      ..._otherCategories.map(
                        (cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat.capitalize()),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: 'other',
                        child: Text('Other (New Category)'),
                      ),
                    ],
                    onChanged: (val) {
                      setModalState(() {
                        selectedType = val!;
                        showOtherInput = val == 'other';
                      });
                    },
                  ),
                  if (showOtherInput)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'New Category Name',
                        ),
                        onChanged: (val) {
                          newOtherType = val.trim();
                        },
                        validator: (val) {
                          if (showOtherInput &&
                              (val == null || val.trim().isEmpty))
                            return 'Category name required';
                          return null;
                        },
                      ),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF128C7E),
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            String typeToUse = selectedType;
                            if (showOtherInput && newOtherType.isNotEmpty) {
                              typeToUse = newOtherType.toLowerCase();
                              if (!_otherCategories.contains(typeToUse)) {
                                _addOtherCategory(typeToUse);
                                _tabController.index =
                                    3 + 1; // Move to new tab after suppliers
                              }
                            }
                            if (isEdit) {
                              final idx = _allPeople.indexWhere(
                                (p) => p.id == person!.id,
                              );
                              _allPeople[idx] = People(
                                id: person!.id,
                                name: nameController.text,
                                phone: phoneController.text,
                                category: typeToUse,
                                balance:
                                    double.tryParse(balanceController.text) ??
                                    0,
                                lastTransactionDate: DateTime.now(),
                              );
                              _filterPeople();
                              Navigator.pop(context);
                            } else {
                              final newPerson = People(
                                name: nameController.text,
                                phone: phoneController.text,
                                category: typeToUse,
                                balance:
                                    double.tryParse(balanceController.text) ??
                                    0,
                                lastTransactionDate: DateTime.now(),
                              );
                              final id = await _peopleRepo.insertPerson(
                                newPerson,
                              );
                              if (id > 0) {
                                // Fetch all people from DB and update UI
                                final people = await _peopleRepo.getAllPeople();
                                setState(() {
                                  _allPeople = people;
                                  _filterPeople();
                                });
                              }
                              Navigator.pop(context);
                            }
                          }
                        },
                        child: Text(
                          isEdit ? 'Save' : 'Add',
                          style: const TextStyle(color: Colors.white),
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
    );
    // If a new tab was added, switch to it
    if (showOtherInput &&
        newOtherType.isNotEmpty &&
        _otherCategories.contains(newOtherType.toLowerCase())) {
      setState(() {
        _tabController.index = 4; // First custom tab after suppliers
      });
    }
  }

  void _deletePerson(People person) async {
    await _peopleRepo.deletePerson(person.id!);
    await _loadPeopleFromDb();
  }

  void _addOtherCategory(String newCat) {
    setState(() {
      if (!_otherCategories.contains(newCat)) {
        _otherCategories.insert(0, newCat); // Insert at start of others
        _tabController.dispose();
        _tabController = TabController(
          length: _tabCount + _otherCategories.length,
          vsync: this,
        );
        _tabController.addListener(_onTabChanged);
      }
    });
  }

  void _deleteOtherCategory(int idx) {
    setState(() {
      String cat = _otherCategories[idx];
      _allPeople.removeWhere((p) => p.category == cat);
      _otherCategories.removeAt(idx);
      _tabController.dispose();
      _tabController = TabController(
        length: _tabCount + _otherCategories.length,
        vsync: this,
      );
      _tabController.addListener(_onTabChanged);
      _filterPeople();
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color accentGreen = const Color(0xFF128C7E);
    int idx = _tabController.index;
    String type = idx == 0
        ? 'all'
        : idx == 1
        ? 'customer'
        : idx == 2
        ? 'supplier'
        : idx >= 4
        ? _otherCategories[idx - 4]
        : '';
    String totalLabel = idx == 0
        ? 'Total Balance'
        : idx == 1
        ? 'Total Receivables'
        : idx == 2
        ? 'Total Payables'
        : idx >= 4
        ? '${type.capitalize()} Total'
        : '';
    return DefaultTabController(
      length: _tabCount + _otherCategories.length,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: accentGreen,
          title: const Text('Peoples', style: TextStyle(color: Colors.white)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  const Tab(text: 'ALL'),
                  const Tab(text: 'Customers'),
                  const Tab(text: 'Suppliers'),
                  ..._otherCategories.asMap().entries.map(
                    (entry) => Tab(
                      child: Row(
                        children: [
                          Text(entry.value.capitalize()),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _deleteOtherCategory(entry.key),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: Row(
                      children: [
                        const Text('Others'),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            _showAddEditPerson();
                          },
                          child: const Icon(
                            Icons.add,
                            size: 18,
                            color: Colors.white,
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
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Container(
                  width: double.infinity,
                  height: 90,
                  decoration: BoxDecoration(
                    color: accentGreen,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: accentGreen.withOpacity(0.18),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
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
                      const SizedBox(width: 16),
                      Flexible(
                        flex: 1,
                        child: Text(
                          'Rs ${_getTotalBalance(type).toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  fillColor: Colors.grey[100],
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
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
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
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.red,
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
                                onTap: () => _showAddEditPerson(person: person),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  constraints: const BoxConstraints(
                                    minHeight: 72,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: accentGreen
                                            .withOpacity(0.12),
                                        child: Icon(
                                          person.category == 'customer'
                                              ? Icons.person
                                              : person.category == 'supplier'
                                              ? Icons.local_shipping
                                              : Icons.category,
                                          color: accentGreen,
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
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
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
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                Text(
                                                  'Rs ${person.balance.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: person.balance < 0
                                                        ? Colors.red
                                                        : Colors.green,
                                                    fontWeight: FontWeight.bold,
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
                                                      color: Colors.grey[500],
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
                                                color: Colors.blue,
                                                size: 20,
                                              ),
                                              onPressed: () {},
                                              tooltip: 'Ledger',
                                            ),
                                            PopupMenuButton<String>(
                                              icon: const Icon(
                                                Icons.more_vert,
                                                color: Colors.black54,
                                                size: 22,
                                              ),
                                              onSelected: (value) {
                                                if (value == 'call') {
                                                  // Implement call logic here
                                                } else if (value ==
                                                    'whatsapp') {
                                                  // Implement WhatsApp logic here
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                PopupMenuItem(
                                                  value: 'call',
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.call,
                                                        color: Colors.green,
                                                        size: 18,
                                                      ),
                                                      const SizedBox(width: 8),
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
                                                        color: Colors.green,
                                                        size: 18,
                                                      ),
                                                      const SizedBox(width: 8),
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
        floatingActionButton: (idx == 3)
            ? null
            : FloatingActionButton(
                backgroundColor: accentGreen,
                child: const Icon(Icons.add, color: Colors.white),
                onPressed: () => _showAddEditPerson(),
                tooltip: 'Add New',
              ),
      ),
    );
  }
}

extension StringCasingExtension on String {
  String capitalize() =>
      isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
}
