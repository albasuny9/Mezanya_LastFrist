// BudgetIconBadge
//
// Purpose: A square badge widget displaying an icon from the app's icon set,
// with a background color derived from a hex color string.
//
// Responsibility: Pure UI — renders a styled Container with a centered icon.
// Includes a local color-parsing helper (_colorFromHex) that converts hex
// strings to Flutter Colors. No business logic, no side effects.
//
// Dependencies: Flutter Material, AppIconPickerDialog (for icon rendering).
//
// Why this file exists: Extracted from budget_tracking_screen.dart
// (_iconBadge and _colorFromHex) to enable reuse across budget widgets.
//
// Must never: Perform calculations, access state, call Cubit methods,
// or contain any business rules.

import 'package:flutter/material.dart';
import 'package:mezanya_app/core/widgets/app_icon_picker_dialog.dart';

class BudgetIconBadge extends StatelessWidget {
  const BudgetIconBadge(
    this.iconName,
    this.colorHex, {
    super.key,
    this.size = 54,
    this.solid = false,
  });

  final String iconName;
  final String colorHex;
  final double size;
  final bool solid;

  /// Converts a hex color string (with or without '#', 6 or 8 digits) to a
  /// Flutter Color. Falls back to the app's default green on parse failure.
  static Color colorFromHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.tryParse(normalized, radix: 16) ?? 0xFF0F9D7A);
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(colorHex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: AppIconPickerDialog.iconWidgetForName(
          iconName,
          color: solid ? Colors.white : color,
          size: size * 0.42,
        ),
      ),
    );
  }
}
