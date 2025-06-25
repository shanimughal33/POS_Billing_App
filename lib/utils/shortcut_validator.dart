class ShortcutParseResult {
  final bool isValid;
  final String? error;
  final String? category;
  final int? code;
  final double? quantity;

  const ShortcutParseResult({
    required this.isValid,
    this.error,
    this.category,
    this.code,
    this.quantity,
  });
}

class ShortcutValidator {
  static const _validCategories = ['A', 'B', 'C', 'D'];
  static const _maxShortcutLength = 6; // A999x99 format
  static const _shortcutPattern = r'^[A-D](?:[0-9]{1,3})(?:x[0-9]{1,2})?$';

  static bool isValidCategory(String category) {
    return _validCategories.contains(category.toUpperCase());
  }

  static bool isValidShortcutFormat(String shortcut) {
    final normalized = shortcut.trim().toUpperCase();
    return RegExp(_shortcutPattern).hasMatch(normalized);
  }

  static ShortcutParseResult parseShortcut(String input) {
    final normalized = input.trim().toUpperCase();

    if (normalized.isEmpty) {
      return const ShortcutParseResult(
        isValid: false,
        error: 'Shortcut cannot be empty',
      );
    }

    if (normalized.length > _maxShortcutLength) {
      return const ShortcutParseResult(
        isValid: false,
        error: 'Shortcut too long',
      );
    }

    final category = normalized[0];
    if (!isValidCategory(category)) {
      return const ShortcutParseResult(
        isValid: false,
        error: 'Invalid category: must be A, B, C, or D',
      );
    }

    // Handle basic category-only shortcut
    if (normalized.length == 1) {
      return ShortcutParseResult(
        isValid: true,
        category: category,
        code: 0,
        quantity: 1.0,
      );
    }

    // Parse parts (code and optional quantity)
    final parts = normalized.substring(1).split('x');
    if (parts.isEmpty || parts[0].isEmpty) {
      return const ShortcutParseResult(
        isValid: false,
        error: 'Invalid format: category must be followed by a number',
      );
    }

    // Parse code
    final code = int.tryParse(parts[0]);
    if (code == null || code < 0) {
      return const ShortcutParseResult(
        isValid: false,
        error: 'Invalid code: must be a positive number',
      );
    }

    // Parse quantity if present
    double quantity = 1.0;
    if (parts.length > 1) {
      final parsedQty = int.tryParse(parts[1]);
      if (parsedQty == null || parsedQty <= 0) {
        return const ShortcutParseResult(
          isValid: false,
          error: 'Invalid quantity: must be a positive number',
        );
      }
      quantity = parsedQty.toDouble();
    }

    return ShortcutParseResult(
      isValid: true,
      category: category,
      code: code,
      quantity: quantity,
    );
  }

  static String? validateForInventory(String? shortcut) {
    if (shortcut == null || shortcut.isEmpty) {
      return null; // Empty shortcuts are allowed in inventory
    }

    final normalized = shortcut.trim().toUpperCase();
    if (!isValidCategory(normalized[0])) {
      return 'Shortcut must start with A, B, C, or D';
    }

    if (normalized.length > 1) {
      final code = normalized.substring(1);
      final number = int.tryParse(code);
      if (number == null || number < 0) {
        return 'Shortcut code must be a non-negative number';
      }
    }

    return null;
  }
}
