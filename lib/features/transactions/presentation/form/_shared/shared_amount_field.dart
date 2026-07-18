import 'package:flutter/material.dart';

import '../../../../../core/utils/transaction_display_format.dart';
import '../widgets/amount_calculator_sheet.dart';

/// حقل إدخال المبلغ الموحَّد — بأيقونة آلة حاسبة مدمجة. مستخرَج من
/// `AmountSection` الأصلية (كانت `_AmountField` خاصة بها) ليصبح قابلاً
/// لإعادة الاستخدام في أي شاشة تحتاج إدخال مبلغ بنفس الشكل، دون تكرار
/// الكود أو الاعتماد على `TransactionFormController`.
class SharedAmountField extends StatelessWidget {
  const SharedAmountField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.label = 'المبلغ',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          // ── Label row with calculator icon ──────────────────────────────
          Row(
            children: [
              // Calculator icon — far left, visually subtle
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  // Dismiss keyboard before opening calculator
                  focusNode.unfocus();
                  // Small delay so keyboard hides cleanly before sheet opens
                  await Future<void>.delayed(
                    const Duration(milliseconds: 80),
                  );
                  if (!context.mounted) return;
                  final result = await showAmountCalculatorSheet(context);
                  if (!context.mounted) return;
                  if (result != null) {
                    // Use the canonical amount formatter — same as manual entry
                    controller.text = formatAmountInput(result);
                    // Place cursor at end, keep field unfocused (no autofocus)
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.calculate_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.55),
                  ),
                ),
              ),
              // Centred label
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Invisible spacer to keep the label truly centred
              const SizedBox(width: 22),
            ],
          ),
          // ── Amount text field ───────────────────────────────────────────
          TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: false,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => focusNode.unfocus(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: '0.00',
              hintStyle: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Color(0xFFCCCCCC),
              ),
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
