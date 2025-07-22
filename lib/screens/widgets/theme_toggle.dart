import 'package:flutter/material.dart';

class ThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback? onToggle;

  const ThemeToggleButton({Key? key, this.isDark = false, this.onToggle})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
      tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      onPressed: onToggle,
    );
  }
}
