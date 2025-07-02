import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:forward_billing_app/screens/Calculator.dart';
import 'package:forward_billing_app/screens/inventory_screen.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:forward_billing_app/screens/peoples_screen.dart';
import 'package:forward_billing_app/screens/purchase_screen.dart';
import 'package:forward_billing_app/screens/sales_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> _imageUrls = [
    // All working, HD, solo, royalty-free food images (unsplash)
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=800&q=80', // Vegetables
    'https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg', // Bread
    'https://images.pexels.com/photos/965990/pexels-photo-965990.jpeg', // Milk
    'https://images.pexels.com/photos/12327603/pexels-photo-12327603.jpeg', // Fruits
    'https://images.pexels.com/photos/1362534/pexels-photo-1362534.jpeg', // Eggs
    'https://images.pexels.com/photos/6957827/pexels-photo-6957827.jpeg', // Vegetables (repeat for diversity)
    'https://images.pexels.com/photos/5966434/pexels-photo-5966434.jpeg', // Vegetables (repeat for diversity)
  ];

  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  // For bottom navigation bar
  final iconList = <IconData>[
    Icons.home_rounded,
    Icons.history_rounded,
    Icons.info_outline_rounded,
    Icons.bar_chart_rounded,
  ];
  int _bottomNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    final Color accentGreen = const Color(0xFF128C7E);

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        children: [
          // Modern AppBar/Hero Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 20, top: 0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentGreen,
                  accentGreen.withOpacity(0.95),
                  const Color(0xFF25D366),
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
              image: DecorationImage(
                image: AssetImage(
                  'assets/pattern.png',
                ), // Add a subtle pattern asset if available
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.white.withOpacity(0.07),
                  BlendMode.dstATop,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Material(
                          color: Colors.white.withOpacity(0.18),
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(
                              Icons.menu,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {},
                            tooltip: 'Menu',
                          ),
                        ),
                        Row(
                          children: [
                            Material(
                              color: Colors.white.withOpacity(0.18),
                              shape: const CircleBorder(),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.notifications,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                onPressed: () {},
                                tooltip: 'Notifications',
                              ),
                            ),
                            Material(
                              color: Colors.white.withOpacity(0.18),
                              shape: const CircleBorder(),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.account_circle,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                onPressed: () {},
                                tooltip: 'Menu',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      top: 8,
                      right: 24,
                      bottom: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              "Welcome !!",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black38,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: accentGreen,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shadowColor: accentGreen.withOpacity(0.12),
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                "Add Users",
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: () {
                                Navigator.of(context).pushNamed('/sales');
                              },
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: accentGreen,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shadowColor: accentGreen.withOpacity(0.12),
                              ),
                              icon: const Icon(Icons.logout, size: 16),
                              label: const Text(
                                "Log Out",
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const InventoryScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 0,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: "Search...",
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: accentGreen,
                            size: 18,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          // Carousel Slider
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: CarouselSlider(
              options: CarouselOptions(
                height: 210,
                autoPlay: true,
                autoPlayInterval: const Duration(milliseconds: 2500),
                autoPlayAnimationDuration: const Duration(milliseconds: 900),
                enlargeCenterPage: true,
                viewportFraction: 0.85,
                aspectRatio: 16 / 9,
                onPageChanged: (index, reason) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              ),
              items: _imageUrls.map((url) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    memCacheHeight: 400,
                    memCacheWidth: 800,
                  ),
                );
              }).toList(),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _imageUrls.asMap().entries.map((entry) {
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentIndex == entry.key
                      ? accentGreen
                      : Colors.grey.shade300,
                ),
              );
            }).toList(),
          ),
          // Modern Grid Menu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.05,
              children: [
                _ModernMenuCard(
                  icon: Icons.inventory_2_rounded,
                  iconColor: Colors.teal,
                  label: 'Inventory',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const InventoryScreen(),
                      ),
                    );
                  },
                ),
                _ModernMenuCard(
                  icon: Icons.shopping_cart_rounded,
                  iconColor: Colors.deepPurple,
                  label: 'Purchase',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PurchaseScreen()),
                    );
                  },
                ),
                _ModernMenuCard(
                  icon: Icons.point_of_sale_rounded,
                  iconColor: Colors.green,
                  label: 'Sales',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SalesScreen()),
                    );
                  },
                ),
                _ModernMenuCard(
                  icon: Icons.calculate_rounded,
                  iconColor: Colors.orange,
                  label: 'Calculator',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CalculatorScreen(),
                      ),
                    );
                  },
                ),
                _ModernMenuCard(
                  icon: Icons.people_alt_rounded,
                  iconColor: Colors.blue,
                  label: 'Peoples',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PeoplesScreen()),
                    );
                  },
                ),
                _ModernMenuCard(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: Colors.indigo,
                  label: 'Digital Khata',
                  onTap: () {},
                ),
                _ModernMenuCard(
                  icon: Icons.money_off_csred_rounded,
                  iconColor: Colors.red,
                  label: 'Expense',
                  onTap: () {},
                ),
                _ModernMenuCard(
                  icon: Icons.bar_chart_rounded,
                  iconColor: Colors.brown,
                  label: 'Reports',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      floatingActionButton: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        child: FloatingActionButton(
          backgroundColor: accentGreen,
          elevation: 8,
          child: const Icon(Icons.settings, color: Colors.white, size: 28),
          onPressed: () {
            setState(() {
              _bottomNavIndex = 2; // Settings index
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Settings tapped!'),
                duration: Duration(milliseconds: 800),
              ),
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AnimatedBottomNavigationBar(
        icons: [
          Icons.home_rounded,
          Icons.history_rounded,
          Icons.info_outline_rounded,
          Icons.bar_chart_rounded,
        ],
        activeIndex: _bottomNavIndex > 1
            ? _bottomNavIndex - 1
            : _bottomNavIndex,
        gapLocation: GapLocation.center,
        notchSmoothness: NotchSmoothness.softEdge,
        leftCornerRadius: 24,
        rightCornerRadius: 24,
        backgroundColor: Colors.white,
        activeColor: accentGreen,
        inactiveColor: Colors.grey.shade400,
        iconSize: 28,
        elevation: 16,
        splashColor: accentGreen.withOpacity(0.15),
        splashSpeedInMilliseconds: 350,
        onTap: (index) {
          setState(() {
            // Adjust index to account for FAB (Settings) in the center
            _bottomNavIndex = index >= 2 ? index + 1 : index;
          });
          // Handle navigation or actions for each tab
          switch (index >= 2 ? index + 1 : index) {
            case 0:
              // Home
              break;
            case 1:
              // History
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('History tapped!'),
                  duration: Duration(milliseconds: 800),
                ),
              );
              break;
            case 2:
              // Settings (handled by FAB)
              break;
            case 3:
              // About
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('About tapped!'),
                  duration: Duration(milliseconds: 800),
                ),
              );
              break;
            case 4:
              // Reports
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reports tapped!'),
                  duration: Duration(milliseconds: 800),
                ),
              );
              break;
          }
        },
        splashRadius: 28,
        shadow: BoxShadow(
          color: Colors.black.withOpacity(0.07),
          blurRadius: 12,
          offset: const Offset(0, -2),
        ),
      ),
    );
  }
}

// Modern Home menu card widget
class _ModernMenuCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _ModernMenuCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade100, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                  letterSpacing: 0.7,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
