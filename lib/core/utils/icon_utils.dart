import 'package:flutter/material.dart';

class IconUtils {
  static const List<IconData> categoryIcons = [
    Icons.category,
    Icons.work,
    Icons.home,
    Icons.school,
    Icons.flight,
    Icons.local_cafe,
    Icons.local_grocery_store,
    Icons.fitness_center,
    Icons.local_hospital,
    Icons.code,
    Icons.build,
    Icons.pets,
    Icons.local_florist,
    Icons.wifi,
    Icons.local_dining,
    Icons.directions_car,
    Icons.directions_bus,
    Icons.directions_bike,
    Icons.directions_boat,
    Icons.local_mall,
    Icons.local_offer,
  ];

  static IconData getIconData(int codePoint) {
    try {
      return categoryIcons.firstWhere(
        (icon) => icon.codePoint == codePoint,
        orElse: () => Icons.category,
      );
    } catch (_) {
      return Icons.category;
    }
  }
}
