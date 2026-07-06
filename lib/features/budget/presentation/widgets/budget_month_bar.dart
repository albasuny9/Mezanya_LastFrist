// BudgetMonthBar
//
// Purpose: The cycle navigation bar at the top of the budget tracking screen,
// allowing the user to navigate between past, current, and future budget cycles.
//
// Responsibility: Pure UI — renders an animated container with the cycle date
// range label and two navigation arrow buttons. All state changes are
// delegated to the screen via [onPrevious] and [onNext] callbacks.
//
// Dependencies: Flutter Material, AppTheme (for date text style).
//
// Why this file exists: Extracted from budget_tracking_screen.dart
// (_monthBar) to reduce file size and isolate this navigation component.
//
// Must never: Perform calculations, modify cycle state directly, call Cubit
// methods, or contain any business rules.

import 'package:flutter/material.dart';
import 'package:mezanya_app/core/theme/app_theme.dart';

class BudgetMonthBar extends StatelessWidget {
  const BudgetMonthBar({
    super.key,
    required this.rangeLabel,
    required this.isCurrent,
    required this.isPast,
    required this.isFuture,
    required this.onPrevious,
    required this.onNext,
  });

  final String rangeLabel;
  final bool isCurrent;
  final bool isPast;
  final bool isFuture;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    Color accent;
    Color background;
    Color border;

    if (isPast || isFuture) {
      accent = const Color(0xFF5C6E53);
      background = const Color(0xFFF6F3EA);
      border = const Color(0xFFC6CFB6);
    } else {
      accent = const Color(0xFF355E3B); // أخضر زيتوني
      background = const Color(0xFFF5F0E6);
      border = const Color(0xFFA7B48E);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // زرار الشهر السابق
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: onPrevious,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0xFF355E3B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              rangeLabel,
              textAlign: TextAlign.center,
              style: AppTheme.dateTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isCurrent ? accent : accent.withValues(alpha: 0.7),
              ),
            ),
          ),
          // زرار الشهر القادم
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: onNext,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0xFF355E3B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
