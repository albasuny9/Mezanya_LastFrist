import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mezanya_app/core/constants/transaction_types.dart';

import '../../../../core/utils/transaction_display_format.dart';
import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../screens/add_transaction_screen.dart';

CategoryEntity? getCategoryForTransaction(
    AppStateEntity state, String? categoryId) {
  if (categoryId == null || categoryId.isEmpty) return null;
  for (final c in state.categories) {
    if (c.id == categoryId) return c;
  }
  for (final alloc in state.budgetSetup.allocations) {
    for (final c in alloc.categories) {
      if (c.id == categoryId) return c;
    }
  }
  for (final jar in state.budgetSetup.linkedWallets) {
    for (final c in jar.categories) {
      if (c.id == categoryId) return c;
    }
  }
  return null;
}

Future<void> openTransactionDetailsSheet(
  BuildContext context, {
  required AppCubit cubit,
  required TransactionEntity transaction,
}) async {
  await showAppDetailsBottomSheet(
    context,
    title: 'تفاصيل المعاملة',
    children: _transactionDetailsChildren(
      context,
      cubit: cubit,
      transaction: transaction,
      closeBeforeEdit: true,
    ),
  );
}

Future<void> showAppDetailsBottomSheet(
  BuildContext context, {
  required String title,
  required List<Widget> children,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFFFFFBF1),
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AppDetailsSheetHeader(title: title),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AppDetailsSheetHeader extends StatelessWidget {
  const _AppDetailsSheetHeader({required this.title});

  final String title;

  static const _accent = Color(0xFF165b47);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: _accent,
            style: IconButton.styleFrom(
              backgroundColor: _accent.withValues(alpha: 0.08),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _accent,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.more_horiz_rounded),
            color: _accent,
            style: IconButton.styleFrom(
              backgroundColor: _accent.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> openTransactionDetailsPage(
  BuildContext context, {
  required AppCubit cubit,
  required TransactionEntity transaction,
}) =>
    openTransactionDetailsSheet(
      context,
      cubit: cubit,
      transaction: transaction,
    );

List<Widget> _transactionDetailsChildren(
  BuildContext context, {
  required AppCubit cubit,
  required TransactionEntity transaction,
  required bool closeBeforeEdit,
}) {
  final state = cubit.state;
  final category = getCategoryForTransaction(state, transaction.categoryId);
  final isIncome = transaction.type == TransactionType.income.value;
  final isExpense = transaction.type == TransactionType.expense.value;

  final accent = category != null
      ? parseCategoryColor(category.color)
      : isIncome
          ? const Color(0xFF16A34A)
          : isExpense
              ? const Color(0xFFDC2626)
              : const Color(0xFF2563EB);

  final heroBg = isIncome
      ? const Color(0xFFE8F8EE)
      : isExpense
          ? const Color(0xFFFDE8E8)
          : const Color(0xFFE8F0FE);

  final amountColor = isExpense
      ? const Color(0xFFDC2626)
      : isIncome
          ? const Color(0xFF16A34A)
          : const Color(0xFF2563EB);

  final displayTitle = (transaction.notes?.trim().isNotEmpty == true
          ? transaction.notes!.trim()
          : null) ??
      category?.name ??
      _transactionDisplayTitle(state, transaction);

  final displayIcon = category != null
      ? AppIconPickerDialog.iconDataForName(category.icon)
      : _iconForTransaction(transaction);

  final walletLabel = transactionWalletLabel(state, transaction);
  final allocationLabel = transactionAllocationLabel(state, transaction);
  final categoryLabel = category?.name;
  final dateLabel =
      DateFormat('d MMMM yyyy', 'ar').format(transaction.createdAt);
  final timeLabel = formatTransactionTime(transaction.createdAt);
  final timestampLabel = '$dateLabel، $timeLabel';
  final currency = currencyLabelAr(state.currencyCode);
  final amountSign = _signFor(transaction);
  final amountValue = transaction.amount.toStringAsFixed(2);
  final amountGridText = '$amountSign$amountValue $currency';

  final hasUserNotes = transaction.notes?.trim().isNotEmpty == true &&
      !_isGeneratedJarNote(transaction);

  return [
    AppDetailsSummaryCard(
      title: displayTitle,
      subtitle:
          categoryLabel ?? (allocationLabel != '—' ? allocationLabel : ''),
      amountSign: amountSign,
      amountValue: amountValue,
      currency: currency,
      icon: displayIcon,
      iconColor: accent,
      backgroundColor: heroBg,
      amountColor: amountColor,
    ),
    const SizedBox(height: 14),
    AppDetailsGrid(
      date: dateLabel,
      time: timeLabel,
      wallet: walletLabel,
      allocation: allocationLabel,
      amountText: amountGridText,
      amountValueColor: amountColor,
      paymentMethod: 'نقدي',
      createdAtLabel: timestampLabel,
      updatedAtLabel: timestampLabel,
    ),
    const SizedBox(height: 12),
    AppDetailsNotesSection(
      notes: hasUserNotes ? transaction.notes!.trim() : null,
    ),
    const SizedBox(height: 14),
    FilledButton.icon(
      onPressed: () => _openTransactionEditor(
        context,
        cubit: cubit,
        transaction: transaction,
        closeBeforeEdit: closeBeforeEdit,
      ),
      icon: const Icon(Icons.edit_outlined),
      label: const Text('تعديل المعاملة'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: const Color(0xFF165b47),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  ];
}

String transactionWalletLabel(AppStateEntity state, TransactionEntity tx) {
  final id = tx.walletId ?? tx.fromWalletId;
  if (id == null) return '—';
  return state.wallets
          .where((w) => w.id == id)
          .map((w) => w.name)
          .firstOrNull ??
      '—';
}

String transactionAllocationLabel(AppStateEntity state, TransactionEntity tx) {
  if (tx.allocationId != null) {
    return state.budgetSetup.allocations
            .where((a) => a.id == tx.allocationId)
            .map((a) => a.name)
            .firstOrNull ??
        '—';
  }
  if (tx.toWalletId != null) {
    return state.budgetSetup.linkedWallets
            .where((j) => j.id == tx.toWalletId)
            .map((j) => j.name)
            .firstOrNull ??
        '—';
  }
  if (tx.budgetScope == BudgetScope.outsideBudget.value) {
    return 'خارج الميزانية';
  }
  return '—';
}

class AppDetailsSummaryCard extends StatelessWidget {
  const AppDetailsSummaryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amountSign,
    required this.amountValue,
    required this.currency,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.amountColor,
  });

  final String title;
  final String subtitle;
  final String amountSign;
  final String amountValue;
  final String currency;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A7F72),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  '$amountSign$amountValue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: amountColor,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                currency,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8A7F72),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AppDetailsGrid extends StatelessWidget {
  const AppDetailsGrid({
    super.key,
    required this.date,
    required this.time,
    required this.wallet,
    required this.allocation,
    required this.amountText,
    this.amountValueColor,
    this.paymentMethod = 'نقدي',
    required this.createdAtLabel,
    required this.updatedAtLabel,
    this.walletLabel = 'المحفظة',
    this.allocationLabel = 'المخصص',
    this.paymentMethodLabel = 'طريقة الدفع',
    this.updatedAtLabelText = 'آخر تحديث',
    this.createdAtLabelText = 'تم الإنشاء في',
  });

  final String date;
  final String time;
  final String wallet;
  final String allocation;
  final String amountText;
  final Color? amountValueColor;
  final String paymentMethod;
  final String createdAtLabel;
  final String updatedAtLabel;
  final String walletLabel;
  final String allocationLabel;
  final String paymentMethodLabel;
  final String updatedAtLabelText;
  final String createdAtLabelText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EBE3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AppDetailsGridCell(
                    label: 'التاريخ',
                    value: date,
                    icon: Icons.calendar_today_outlined,
                  ),
                ),
                const VerticalDivider(width: 1, color: Color(0xFFF0EBE3)),
                Expanded(
                  child: AppDetailsGridCell(
                    label: 'المبلغ',
                    value: amountText,
                    icon: Icons.payments_outlined,
                    valueColor: amountValueColor,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EBE3)),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AppDetailsGridCell(
                    label: walletLabel,
                    value: wallet,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                const VerticalDivider(width: 1, color: Color(0xFFF0EBE3)),
                Expanded(
                  child: AppDetailsGridCell(
                    label: 'الوقت',
                    value: time,
                    icon: Icons.schedule_outlined,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EBE3)),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AppDetailsGridCell(
                    label: paymentMethodLabel,
                    value: paymentMethod,
                    icon: Icons.credit_card_outlined,
                  ),
                ),
                const VerticalDivider(width: 1, color: Color(0xFFF0EBE3)),
                Expanded(
                  child: AppDetailsGridCell(
                    label: allocationLabel,
                    value: allocation,
                    icon: Icons.pie_chart_outline_rounded,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EBE3)),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AppDetailsGridCell(
                    label: updatedAtLabelText,
                    value: updatedAtLabel,
                    icon: Icons.sync_rounded,
                  ),
                ),
                const VerticalDivider(width: 1, color: Color(0xFFF0EBE3)),
                Expanded(
                  child: AppDetailsGridCell(
                    label: createdAtLabelText,
                    value: createdAtLabel,
                    icon: Icons.history_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppDetailsGridCell extends StatelessWidget {
  const AppDetailsGridCell({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  static const _detailGreen = Color(0xFF165b47);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _detailGreen.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: _detailGreen),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A7F72),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? const Color(0xFF1A1A1A),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppDetailsNotesSection extends StatelessWidget {
  const AppDetailsNotesSection({super.key, required this.notes});

  final String? notes;

  static const _detailGreen = Color(0xFF165b47);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0EBE3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'الملاحظات',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _detailGreen,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _detailGreen.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sticky_note_2_outlined,
                  size: 16,
                  color: _detailGreen,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                notes ?? 'لا توجد ملاحظات',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: notes == null
                      ? const Color(0xFFB5A99A)
                      : const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openTransactionEditor(
  BuildContext context, {
  required AppCubit cubit,
  required TransactionEntity transaction,
  required bool closeBeforeEdit,
}) async {
  if (closeBeforeEdit) Navigator.pop(context);
  if (transaction.transferType == TransferType.jarFunding.value ||
      transaction.transferType == TransferType.jarFundingPhysical.value ||
      transaction.transferType == TransferType.jarAllocation.value) {
    await _openJarReserveEditor(
      context,
      cubit: cubit,
      transaction: transaction,
    );
    return;
  }
  if (transaction.transferType == TransferType.jarToJar.value) {
    await _openJarToJarEditor(
      context,
      cubit: cubit,
      transaction: transaction,
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.96,
      child: AddTransactionScreen(
        cubit: cubit,
        initialTransaction: transaction,
      ),
    ),
  );
}

/// محرر مخصص لمعاملات التحويل بين حصالتين (jarToJar).
/// لا يستخدم الشاشة العامة لأنها لا تدعم نوع transfer ولا تمرر
/// fromWalletId عند الحفظ — مما كان سيمحو أثر التحويل بالكامل عند التعديل.
Future<void> _openJarToJarEditor(
  BuildContext context, {
  required AppCubit cubit,
  required TransactionEntity transaction,
}) async {
  final amountController =
      TextEditingController(text: transaction.amount.toStringAsFixed(2));
  final notesController = TextEditingController(text: transaction.notes ?? '');
  var selectedSourceJarId = transaction.fromWalletId ?? '';
  var selectedTargetJarId = transaction.toWalletId ?? '';
  var selectedDate = transaction.createdAt;
  var selectedTime = TimeOfDay(
    hour: transaction.createdAt.hour,
    minute: transaction.createdAt.minute,
  );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheet) {
        final jars = cubit.state.budgetSetup.linkedWallets;
        if (selectedSourceJarId.isEmpty && jars.isNotEmpty) {
          selectedSourceJarId = jars.first.id;
        }
        if (selectedTargetJarId.isEmpty && jars.isNotEmpty) {
          selectedTargetJarId = jars.first.id;
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                'تعديل التحويل بين حصالتين',
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'المبلغ'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedSourceJarId.isEmpty ? null : selectedSourceJarId,
                decoration: const InputDecoration(labelText: 'من حصالة'),
                items: jars
                    .map(
                      (jar) => DropdownMenuItem<String>(
                        value: jar.id,
                        child: Text(jar.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setSheet(() => selectedSourceJarId = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedTargetJarId.isEmpty ? null : selectedTargetJarId,
                decoration: const InputDecoration(labelText: 'إلى حصالة'),
                items: jars
                    .map(
                      (jar) => DropdownMenuItem<String>(
                        value: jar.id,
                        child: Text(jar.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setSheet(() => selectedTargetJarId = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setSheet(() => selectedDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                          DateFormat('d MMM yyyy', 'ar').format(selectedDate)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: sheetContext,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setSheet(() => selectedTime = picked);
                        }
                      },
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(selectedTime.format(sheetContext)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: sheetContext,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('حذف التحويل'),
                      content: const Text(
                          'سيتم حذف هذا التحويل بالكامل. هل تريد المتابعة؟'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('إلغاء'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: const Text('حذف'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await cubit.deleteTransaction(transaction.id);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('حذف التحويل'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: Theme.of(sheetContext).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(sheetContext)
                        .colorScheme
                        .error
                        .withValues(alpha: 0.45),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: selectedSourceJarId.isEmpty ||
                        selectedTargetJarId.isEmpty ||
                        selectedSourceJarId == selectedTargetJarId
                    ? null
                    : () async {
                        final amount =
                            double.tryParse(amountController.text.trim());
                        if (amount == null || amount <= 0) return;

                        // تحقق إن المتاح في الحصالة المصدر يكفي (مع مراعاة
                        // إن نفس المعاملة كانت بتسحب من نفس المصدر أصلاً)
                        LinkedWalletEntity? sourceJar;
                        for (final jar
                            in cubit.state.budgetSetup.linkedWallets) {
                          if (jar.id == selectedSourceJarId) {
                            sourceJar = jar;
                            break;
                          }
                        }
                        if (sourceJar == null) return;
                        final alreadyDeductedFromSameJar =
                            transaction.fromWalletId == selectedSourceJarId
                                ? transaction.amount
                                : 0.0;
                        final availableInSource =
                            sourceJar.balance + alreadyDeductedFromSameJar;
                        if (amount > availableInSource + 0.01) {
                          await showDialog<void>(
                            context: sheetContext,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('المبلغ أكبر من المتاح'),
                              content: Text(
                                'المتاح في ${sourceJar?.name} هو '
                                '${availableInSource.toStringAsFixed(2)} فقط.',
                              ),
                              actions: [
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  child: const Text('تمام'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }

                        final createdAt = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                        await cubit.deleteTransaction(transaction.id);
                        await cubit.addTransaction(
                          walletId: transaction.walletId,
                          fromWalletId: selectedSourceJarId,
                          toWalletId: selectedTargetJarId,
                          amount: amount,
                          type: TransactionType.transfer.value,
                          transferType: TransferType.jarToJar.value,
                          notes: notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim(),
                          createdAt: createdAt,
                          details:
                              'تم تعديل تحويل بين حصالتين بقيمة ${amount.toStringAsFixed(2)}',
                        );
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> _openJarReserveEditor(
  BuildContext context, {
  required AppCubit cubit,
  required TransactionEntity transaction,
}) async {
  final amountController =
      TextEditingController(text: transaction.amount.toStringAsFixed(2));
  final notesController =
      TextEditingController(text: _editableJarNote(transaction));
  var selectedWalletId = transaction.fromWalletId ?? transaction.walletId ?? '';
  var selectedJarId = transaction.toWalletId ?? '';
  var selectedDate = transaction.createdAt;
  var selectedTime = TimeOfDay(
    hour: transaction.createdAt.hour,
    minute: transaction.createdAt.minute,
  );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheet) {
        final wallets = cubit.state.wallets;
        final jars = cubit.state.budgetSetup.linkedWallets;
        if (selectedWalletId.isEmpty && wallets.isNotEmpty) {
          selectedWalletId = wallets.first.id;
        }
        if (selectedJarId.isEmpty && jars.isNotEmpty) {
          selectedJarId = jars.first.id;
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                transaction.transferType == TransferType.jarFunding.value
                    ? 'تعديل تحويل من الميزانية'
                    : (transaction.transferType ==
                            TransferType.jarFundingPhysical.value
                        ? 'تعديل خصم لحصالة'
                        : 'تعديل تخصيص حصالة'),
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'المبلغ المحجوز'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedWalletId.isEmpty ? null : selectedWalletId,
                decoration: const InputDecoration(labelText: 'محفظة الحجز'),
                items: wallets
                    .map(
                      (wallet) => DropdownMenuItem<String>(
                        value: wallet.id,
                        child: Text(wallet.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setSheet(() => selectedWalletId = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedJarId.isEmpty ? null : selectedJarId,
                decoration: const InputDecoration(labelText: 'الحصالة'),
                items: jars
                    .map(
                      (jar) => DropdownMenuItem<String>(
                        value: jar.id,
                        child: Text(jar.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setSheet(() => selectedJarId = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setSheet(() => selectedDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                          DateFormat('d MMM yyyy', 'ar').format(selectedDate)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: sheetContext,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setSheet(() => selectedTime = picked);
                        }
                      },
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(selectedTime.format(sheetContext)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: sheetContext,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('حذف الحجز'),
                      content: const Text(
                          'سيتم حذف حجز الحصالة بالكامل. هل تريد المتابعة؟'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('إلغاء'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: const Text('حذف'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await cubit.deleteTransaction(transaction.id);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('حذف الحجز'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: Theme.of(sheetContext).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(sheetContext)
                        .colorScheme
                        .error
                        .withValues(alpha: 0.45),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: selectedWalletId.isEmpty || selectedJarId.isEmpty
                    ? null
                    : () async {
                        final amount =
                            double.tryParse(amountController.text.trim());
                        if (amount == null || amount <= 0) return;
                        LinkedWalletEntity? targetJar;
                        for (final jar
                            in cubit.state.budgetSetup.linkedWallets) {
                          if (jar.id == selectedJarId) {
                            targetJar = jar;
                            break;
                          }
                        }
                        if (targetJar == null) return;
                        final targetJarName = targetJar.name;
                        final currentAmountForSameJar =
                            transaction.toWalletId == selectedJarId
                                ? transaction.amount
                                : 0.0;
                        final availableForReservation =
                            targetJar.unlabeledAmount + currentAmountForSameJar;
                        if (amount > availableForReservation + 0.01) {
                          await showDialog<void>(
                            context: sheetContext,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('المبلغ أكبر من المتاح'),
                              content: Text(
                                'المتاح للحجز في $targetJarName هو '
                                '${availableForReservation.toStringAsFixed(2)} فقط.',
                              ),
                              actions: [
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  child: const Text('تمام'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                        final createdAt = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                        await cubit.deleteTransaction(transaction.id);
                        await cubit.addTransaction(
                          walletId: selectedWalletId,
                          fromWalletId: selectedWalletId,
                          toWalletId: selectedJarId,
                          amount: amount,
                          type: TransactionType.transfer.value,
                          budgetScope: transaction.budgetScope,
                          incomeSourceId: transaction.incomeSourceId,
                          transferType: transaction.transferType ??
                              TransferType.jarAllocation.value,
                          notes: notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim(),
                          createdAt: createdAt,
                          details:
                              'تم تعديل معاملة حصالة بقيمة ${amount.toStringAsFixed(2)}',
                        );
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ الحجز'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

String _editableJarNote(TransactionEntity tx) {
  if (_isGeneratedJarNote(tx)) return '';
  return tx.notes ?? '';
}

bool _isGeneratedJarNote(TransactionEntity tx) {
  final note = tx.notes?.trim();
  if (note == null || note.isEmpty) return false;
  if (tx.transferType != TransferType.jarFunding.value &&
      tx.transferType != TransferType.jarFundingPhysical.value) {
    return false;
  }
  return note.startsWith('حجز للحصالة') ||
      note.startsWith('حجز لحصالة') ||
      note.startsWith('خصم فعلي إلى حصالة') ||
      note.startsWith('خصم فعلي لحصالة') ||
      note.startsWith('تم تعديل حجز حصالة') ||
      note.startsWith('تعديل حجز');
}

String _transactionDisplayTitle(AppStateEntity state, TransactionEntity tx) {
  String? resolvedJarName;
  for (final jar in state.budgetSetup.linkedWallets) {
    if (jar.id == tx.toWalletId) {
      resolvedJarName = jar.name;
      break;
    }
  }
  final jarName = resolvedJarName ?? 'التوفير';

  if (tx.transferType == TransferType.jarFunding.value) {
    return 'حجز لحصالة $jarName';
  }
  if (tx.transferType == TransferType.jarFundingPhysical.value) {
    return 'خصم لحصالة $jarName';
  }
  if (tx.notes?.trim().isNotEmpty == true) {
    return tx.notes!.trim();
  }
  return _typeLabel(tx.type);
}

String _typeLabel(String type) {
  if (type == TransactionType.income.value) return 'دخل';
  if (type == TransactionType.expense.value) return 'مصروف';
  return 'تحويل';
}

IconData _iconForTransaction(TransactionEntity tx) {
  if (tx.type == TransactionType.income.value) return Icons.south_west_rounded;
  if (tx.type == TransactionType.expense.value) return Icons.north_east_rounded;
  return Icons.swap_horiz_rounded;
}

Color parseCategoryColor(String hexStr) {
  try {
    final buffer = StringBuffer();
    if (hexStr.length == 6 || hexStr.length == 7) buffer.write('ff');
    buffer.write(hexStr.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (e) {
    return const Color(0xFF165B47);
  }
}

String _signFor(TransactionEntity transaction) {
  if (transaction.type == TransactionType.income.value) return '+';
  if (transaction.type == TransactionType.expense.value) return '-';
  return '';
}
