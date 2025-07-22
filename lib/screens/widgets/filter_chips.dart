import 'package:flutter/material.dart';

class FilterChipsWidget extends StatelessWidget {
  final List<String> categories;
  final List<String> paymentMethods;
  final List<String> locations;
  final String? selectedCategory;
  final String? selectedPaymentMethod;
  final String? selectedLocation;
  final void Function(String category)? onCategorySelected;
  final void Function(String paymentMethod)? onPaymentMethodSelected;
  final void Function(String location)? onLocationSelected;

  const FilterChipsWidget({
    Key? key,
    required this.categories,
    required this.paymentMethods,
    required this.locations,
    this.selectedCategory,
    this.selectedPaymentMethod,
    this.selectedLocation,
    this.onCategorySelected,
    this.onPaymentMethodSelected,
    this.onLocationSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ...categories.map(
          (cat) => FilterChip(
            label: Text(cat),
            selected: selectedCategory == cat,
            onSelected: (_) => onCategorySelected?.call(cat),
          ),
        ),
        ...paymentMethods.map(
          (pm) => FilterChip(
            label: Text(pm),
            selected: selectedPaymentMethod == pm,
            onSelected: (_) => onPaymentMethodSelected?.call(pm),
          ),
        ),
        ...locations.map(
          (loc) => FilterChip(
            label: Text(loc),
            selected: selectedLocation == loc,
            onSelected: (_) => onLocationSelected?.call(loc),
          ),
        ),
      ],
    );
  }
}
