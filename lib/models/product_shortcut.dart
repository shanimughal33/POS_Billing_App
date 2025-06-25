class ProductShortcut {
  final String key;
  final String name;
  final double price;
  final double defaultQuantity;

  const ProductShortcut({
    required this.key,
    required this.name,
    required this.price,
    this.defaultQuantity = 1.0,
  });
}

class ProductShortcuts {
  static const Map<String, List<ProductShortcut>> shortcuts = {
    'A': [
      ProductShortcut(key: 'A', name: 'Bread', price: 100, defaultQuantity: 1),
      ProductShortcut(
        key: 'A1',
        name: 'White Bread',
        price: 120,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'A2',
        name: 'Brown Bread',
        price: 150,
        defaultQuantity: 1,
      ),
      ProductShortcut(key: 'A3', name: 'Bun', price: 30, defaultQuantity: 6),
      ProductShortcut(key: 'A4', name: 'Rusk', price: 80, defaultQuantity: 1),
      ProductShortcut(key: 'A5', name: 'Cake', price: 800, defaultQuantity: 1),
      ProductShortcut(
        key: 'A6',
        name: 'Biscuit',
        price: 30,
        defaultQuantity: 6,
      ),
      ProductShortcut(key: 'A7', name: 'Pizza', price: 80, defaultQuantity: 1),
      ProductShortcut(
        key: 'A8',
        name: '  Burger',
        price: 800,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'A9',
        name: 'Sandwitch',
        price: 800,
        defaultQuantity: 1,
      ),
    ],
    'B': [
      ProductShortcut(key: 'B', name: 'Eggs', price: 300, defaultQuantity: 12),
      ProductShortcut(
        key: 'B1',
        name: 'Farm Eggs',
        price: 360,
        defaultQuantity: 12,
      ),
      ProductShortcut(
        key: 'B2',
        name: 'Brown Eggs',
        price: 400,
        defaultQuantity: 12,
      ),
      ProductShortcut(
        key: 'B3',
        name: 'Duck Eggs',
        price: 500,
        defaultQuantity: 6,
      ),
      ProductShortcut(
        key: 'B4',
        name: 'Chicken Eggs',
        price: 200,
        defaultQuantity: 24,
      ),
      ProductShortcut(
        key: 'B5',
        name: 'Quail Eggs',
        price: 600,
        defaultQuantity: 12,
      ),
      ProductShortcut(
        key: 'B6',
        name: 'Ostrich Eggs',
        price: 1500,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'B7',
        name: 'Goose Eggs',
        price: 800,
        defaultQuantity: 6,
      ),
      ProductShortcut(
        key: 'B8',
        name: 'Turkey Eggs',
        price: 700,
        defaultQuantity: 6,
      ),
      ProductShortcut(
        key: 'B9',
        name: 'Organic Eggs',
        price: 450,
        defaultQuantity: 12,
      ),
    ],
    'C': [
      ProductShortcut(key: 'C', name: 'Milk', price: 180, defaultQuantity: 1),
      ProductShortcut(
        key: 'C1',
        name: 'Full Cream Milk',
        price: 220,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'C2',
        name: 'Low Fat Milk',
        price: 200,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'C3',
        name: 'Yogurt',
        price: 160,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'C4',
        name: 'Butter',
        price: 250,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'C5',
        name: 'Cheese',
        price: 300,
        defaultQuantity: 1,
      ),
      ProductShortcut(key: 'C6', name: 'Cream', price: 200, defaultQuantity: 1),
      ProductShortcut(
        key: 'C7',
        name: 'Condensed Milk',
        price: 180,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'C8',
        name: 'Ice Cream',
        price: 350,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'C9',
        name: 'Milk Powder',
        price: 400,
        defaultQuantity: 1,
      ),
    ],
    'D': [
      ProductShortcut(key: 'D', name: 'Honey', price: 500, defaultQuantity: 1),
      ProductShortcut(
        key: 'D1',
        name: 'Pure Honey',
        price: 800,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'D2',
        name: 'Forest Honey',
        price: 1200,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'D3',
        name: 'Mixed Honey',
        price: 1500,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'D4',
        name: 'Black Forest Honey',
        price: 2000,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'D5',
        name: 'Wildflower Honey',
        price: 600,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'D6',
        name: 'Clover Honey',
        price: 700,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'D7',
        name: 'Asia Honey',
        price: 900,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'D8',
        name: 'European Honey',
        price: 2500,
        defaultQuantity: 1,
      ),
      ProductShortcut(
        key: 'D9',
        name: 'African Honey',
        price: 1000,
        defaultQuantity: 1,
      ),
    ],
  };

  static ProductShortcut? find(String key) {
    final group = key.substring(0, 1).toUpperCase();
    if (!shortcuts.containsKey(group)) return null;

    return shortcuts[group]?.firstWhere(
      (shortcut) => shortcut.key.toUpperCase() == key.toUpperCase(),
      orElse: () => shortcuts[group]!.first,
    );
  }
}
