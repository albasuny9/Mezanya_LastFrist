import 'package:flutter/material.dart';

import '../../../../../core/constants/transaction_types.dart';

/// Income / expense segmented toggle at the top of the entry form.
class TypeSection extends StatelessWidget {
  const TypeSection({
    super.key,
    required this.type,
    required this.locked,
    required this.onTypeChanged,
  });

  final String type;
  final bool locked;
  final void Function(String newType) onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeOnRight = type == TransactionType.income.value;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Stack(
        children: [
          // Animated selection pill
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment:
                activeOnRight ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: MediaQuery.of(context).size.width > 420 ? 190 : 165,
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E7F5C),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33207B5A),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
            ),
          ),
          // Labels
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: locked
                      ? null
                      : () => onTypeChanged(TransactionType.expense.value),
                  child: Center(
                    child: Text(
                      'مصروف',
                      style: TextStyle(
                        color: activeOnRight ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: locked
                      ? null
                      : () => onTypeChanged(TransactionType.income.value),
                  child: Center(
                    child: Text(
                      'دخل',
                      style: TextStyle(
                        color: activeOnRight ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
