import 'package:flutter/material.dart';

const maxCustomExpenseCategories = 3;
const maxCustomCategoryNameLength = 9;

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isBuiltIn = false,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isBuiltIn;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': icon.codePoint,
      'color': color.toARGB32(),
      'isBuiltIn': isBuiltIn,
    };
  }

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: _iconFromCodePoint(json['iconCodePoint'] as int?),
      color: Color(json['color'] as int),
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  static IconData _iconFromCodePoint(int? codePoint) {
    // Release builds can tree-shake icon fonts only when icons are statically
    // reachable, so persisted custom category icons are restored from a fixed
    // allowlist instead of constructing IconData at runtime.
    return switch (codePoint) {
      0xf016f => Icons.shopping_bag_rounded,
      0xf0108 => Icons.restaurant_rounded,
      0xf6b1 => Icons.directions_bus_rounded,
      0xf00e1 => Icons.receipt_long_rounded,
      0xf8d9 => Icons.more_horiz_rounded,
      0xf0077 => Icons.pets_rounded,
      0xf738 => Icons.favorite_rounded,
      0xf866 => Icons.local_cafe_rounded,
      0xf8e7 => Icons.movie_rounded,
      0xf01bc => Icons.sports_esports_rounded,
      0xf012e => Icons.school_rounded,
      0xf02c7 => Icons.work_rounded,
      _ => Icons.more_horiz_rounded,
    };
  }
}
