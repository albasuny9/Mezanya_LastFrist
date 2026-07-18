import 'package:flutter/material.dart';

import '../../../../../core/constants/transaction_types.dart';
import '../../../../../core/widgets/app_icon_picker_dialog.dart';
import '../transaction_form_controller.dart';
import 'scheduling_section.dart';

/// All recurring-specific config fields: name, icon, variable-income toggle,
/// recurrence pattern + details, execution type, reminder, installment anchor.
class RecurringSettingsSection extends StatelessWidget {
  const RecurringSettingsSection({
    super.key,
    required this.ctrl,
    required this.onChanged,
  });

  final TransactionFormController ctrl;

  /// Call this after mutating any field on [ctrl] to trigger a rebuild in
  /// the parent form widget.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Section header ──────────────────────────────────────────────
        _sectionHeader(theme),
        const SizedBox(height: 14),

        // ── Name ────────────────────────────────────────────────────────
        TextField(
          controller: ctrl.recurringNameController,
          decoration: const InputDecoration(
            labelText: 'اسم المعاملة المتكررة',
            prefixIcon: Icon(Icons.label_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),

        // ── Icon / Color ─────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final picked = await AppIconPickerDialog.show(
                context,
                initialIconName: ctrl.recurringIconName,
                initialColorHex: ctrl.recurringIconColor,
                title: 'اختيار أيقونة المعاملة المتكررة',
                name: ctrl.recurringNameController.text,
              );
              if (picked == null) return;
              ctrl.recurringIconName = picked.iconName;
              ctrl.recurringIconColor = picked.colorHex;
              onChanged();
            },
            icon: const Icon(Icons.palette_outlined),
            label: const Text('اختيار الأيقونة واللون'),
          ),
        ),
        const SizedBox(height: 12),

        // ── Variable income toggle ───────────────────────────────────────
        if (ctrl.type == TransactionType.income.value &&
            ctrl.withinBudgetIncome) ...[
          _surfaceSection(
            theme: theme,
            child: SwitchListTile.adaptive(
              value: ctrl.isVariableIncome,
              contentPadding: EdgeInsets.zero,
              title: const Text('دخل متغير'),
              subtitle: const Text(
                'الدخل المتغير يكون يدويًا ولا يحتاج مبلغ أو توقيت ثابت',
              ),
              onChanged: (value) {
                ctrl.isVariableIncome = value;
                if (value) {
                  ctrl.executionType = 'manual';
                  ctrl.amountController.clear();
                }
                onChanged();
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Scheduling (extracted — see SchedulingSection) ────────────────
        SchedulingSection(ctrl: ctrl, onChanged: onChanged),

        // ── Installment: first payment date ──────────────────────────────
        if (ctrl.isExpenseInstallment) ...[
          const SizedBox(height: 12),
          _surfaceSection(
            theme: theme,
            child: Builder(builder: (context) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: const Text('تاريخ أول دفعة'),
                subtitle: Text(
                  '${ctrl.firstPaymentDate.day}/'
                  '${ctrl.firstPaymentDate.month}/'
                  '${ctrl.firstPaymentDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: ctrl.firstPaymentDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040),
                  );
                  if (picked != null) {
                    ctrl.firstPaymentDate = picked;
                    onChanged();
                  }
                },
              );
            }),
          ),
        ],
      ],
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _sectionHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.repeat_rounded,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'الإعدادات المتكررة',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color:
                theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _surfaceSection(
      {required ThemeData theme, required Widget child}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: child,
    );
  }

}
