import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/transaction_types.dart';
import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/widgets/shared_transaction_card.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';
import 'wallet_shared_widgets.dart';

enum _JarAdjustmentMode { allocate }

/// توزيع الحصالة على المحافظ — مبني على walletSources
Map<String, double> jarWalletDistribution(AppStateEntity state, String jarId) {
  final jar =
      state.budgetSetup.linkedWallets.where((j) => j.id == jarId).firstOrNull;
  if (jar == null) return {};
  return {for (final s in jar.walletSources) s.walletId: s.amount};
}

bool isJarWalletLocationTransaction(TransactionEntity transaction) {
  return transaction.transferType == TransferType.jarAllocation.value ||
      transaction.transferType == TransferType.jarAllocationCancel.value ||
      transaction.transferType == TransferType.jarAllocationSpend.value ||
      transaction.transferType == TransferType.allocationToJar.value ||
      transaction.transferType == TransferType.jarToAllocation.value;
}

Color parseJarSheetColor(String hex) {
  final normalized = hex.replaceAll('#', '');
  final value = int.tryParse(normalized, radix: 16) ?? 0xFF165B47;
  return Color(0xFF000000 | value);
}

double _jarUnallocatedAmount(LinkedWalletEntity jar) => jar.unlabeledAmount;

Future<void> showJarDetailsSheet({
  required BuildContext context,
  required AppCubit cubit,
  required String jarId,
  required void Function(LinkedWalletEntity jar) onEditJar,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFFFFFBF1),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (ctx) {
      var showWallets = false;
      var sortDescending = true;
      var filterType = 'all'; // 'all' | 'income' | 'expense' | 'transfer'
      return BlocBuilder<AppCubit, AppStateEntity>(
        bloc: cubit,
        builder: (ctx, liveState) {
          final jarMatches = liveState.budgetSetup.linkedWallets
              .where((j) => j.id == jarId)
              .toList();
          if (jarMatches.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
            });
            return const SizedBox.shrink();
          }
          final currentJar = jarMatches.first;
          final state = liveState;
          final distribution = jarWalletDistribution(state, jarId);
          final relevantTransactions = state.transactions
              .where((t) =>
                  t.toWalletId == jarId ||
                  t.walletId == jarId ||
                  t.fromWalletId == jarId)
              .where((t) => !isJarWalletLocationTransaction(t))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final accent = parseJarSheetColor(currentJar.iconColor);
          final jar = currentJar;

          return StatefulBuilder(
            builder: (ctx, setSheet) {
              return DraggableScrollableSheet(
                initialChildSize: 0.88,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (ctx, scrollCtrl) => ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.95),
                            accent.withValues(alpha: 0.72),
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.30),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                            child: Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child:
                                        AppIconPickerDialog.iconWidgetForName(
                                      jar.icon,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        jar.name,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${jar.balance.toStringAsFixed(2)} ${state.currencyCode}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white
                                              .withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _jarSheetIconAction(
                                  Icons.settings_outlined,
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    onEditJar(jar);
                                  },
                                  tooltip: 'تعديل',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _jarSheetGlassMetric(
                                    label: 'الرصيد الكلي',
                                    value: jar.balance.toStringAsFixed(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _jarSheetGlassMetric(
                                    label: 'غير محجوز',
                                    value:
                                        jar.unlabeledAmount.toStringAsFixed(2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () =>
                                setSheet(() => showWallets = !showWallets),
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.28),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedRotation(
                                    turns: showWallets ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 260),
                                    child: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    showWallets
                                        ? 'إخفاء مكان الفلوس'
                                        : 'مكان الفلوس',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            child: showWallets
                                ? Container(
                                    padding: const EdgeInsets.fromLTRB(
                                        18, 0, 18, 20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.18),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons
                                                    .account_balance_wallet_rounded,
                                                color: Colors.white,
                                                size: 17,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const Expanded(
                                              child: Text(
                                                'توزيع الفلوس',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () =>
                                                  _openJarAdjustmentDialog(
                                                context: context,
                                                cubit: cubit,
                                                jar: jar,
                                                mode:
                                                    _JarAdjustmentMode.allocate,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.add_rounded,
                                                        size: 13,
                                                        color: Colors.white),
                                                    SizedBox(width: 4),
                                                    Text('تخصيص',
                                                        style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        if (distribution.isEmpty)
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFFBF1),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: accent.withValues(
                                                    alpha: 0.10),
                                              ),
                                            ),
                                            child: const Text(
                                              'لا يوجد تخصيص من أي محفظة لهذه الحصالة حتى الآن.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Color(0xFF8A7F72),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          )
                                        else
                                          ...distribution.entries.map((e) {
                                            final matchedWallets = state.wallets
                                                .where((w) => w.id == e.key)
                                                .toList();
                                            final walletName =
                                                matchedWallets.isEmpty
                                                    ? 'محفظة'
                                                    : matchedWallets.first.name;
                                            final walletIcon = matchedWallets
                                                    .isEmpty
                                                ? 'account_balance_wallet'
                                                : (matchedWallets.first.icon ??
                                                    'account_balance_wallet');
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8),
                                              child: GestureDetector(
                                                onTap: () =>
                                                    _openWalletAllocationSheet(
                                                  ctx: ctx,
                                                  cubit: cubit,
                                                  jar: jar,
                                                  walletId: e.key,
                                                  walletName: walletName,
                                                  walletIcon: walletIcon,
                                                  walletColor:
                                                      matchedWallets.isEmpty
                                                          ? null
                                                          : matchedWallets
                                                              .first.iconColor,
                                                  relevantTransactions:
                                                      relevantTransactions,
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 14,
                                                      vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.25),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 34,
                                                        height: 34,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white
                                                              .withValues(
                                                                  alpha: 0.18),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                        child: Center(
                                                          child: AppIconPickerDialog
                                                              .iconWidgetForName(
                                                            walletIcon,
                                                            color: Colors.white,
                                                            size: 17,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(walletName,
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                fontSize: 14)),
                                                      ),
                                                      Text(
                                                        '${e.value.toStringAsFixed(2)}${state.currencyCode}',
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            fontSize: 15),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      const Icon(
                                                          Icons
                                                              .chevron_left_rounded,
                                                          color: Colors.white70,
                                                          size: 18),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _jarSheetSectionHeader('المعاملات'),
                    const SizedBox(height: 8),
                    StatefulBuilder(
                      builder: (ctx2, setFilter) {
                        final filtered = relevantTransactions.where((t) {
                          if (filterType == 'income') {
                            return t.type == TransactionType.income.value;
                          }
                          if (filterType == 'expense') {
                            return t.type == TransactionType.expense.value;
                          }
                          if (filterType == 'transfer') {
                            return t.type == TransactionType.transfer.value;
                          }
                          return true;
                        }).toList();
                        if (!sortDescending) {
                          filtered.sort(
                              (a, b) => a.createdAt.compareTo(b.createdAt));
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        for (final f in [
                                          ('all', 'الكل'),
                                          ('income', 'دخل'),
                                          ('expense', 'خصم'),
                                          ('transfer', 'تحويل'),
                                        ])
                                          GestureDetector(
                                            onTap: () => setSheet(() {
                                              filterType = f.$1;
                                            }),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 180),
                                              margin:
                                                  const EdgeInsetsDirectional
                                                      .only(end: 6),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: filterType == f.$1
                                                    ? accent
                                                    : accent.withValues(
                                                        alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                f.$2,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: filterType == f.$1
                                                      ? Colors.white
                                                      : accent,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => setSheet(() {
                                    sortDescending = !sortDescending;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      sortDescending
                                          ? Icons.arrow_downward_rounded
                                          : Icons.arrow_upward_rounded,
                                      color: accent,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (filtered.isEmpty)
                              const WalletInlineNote(
                                  text: 'لا توجد معاملات لهذه الفئة.')
                            else
                              SharedTransactionDayGroups(
                                transactions: filtered.toList(),
                                appState: state,
                                viewingContextId: jar.id,
                                onTap: (transaction) =>
                                    openTransactionDetailsSheet(
                                  ctx,
                                  cubit: cubit,
                                  transaction: transaction,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}

class JarCompactSummaryTile extends StatelessWidget {
  const JarCompactSummaryTile({
    super.key,
    required this.state,
    required this.jar,
    required this.onTap,
  });

  final AppStateEntity state;
  final LinkedWalletEntity jar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distribution = jarWalletDistribution(state, jar.id);
    final accent = parseJarSheetColor(jar.iconColor);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: AppIconPickerDialog.iconWidgetForName(
                  jar.icon,
                  color: accent,
                  size: 19,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jar.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${jar.balance.toStringAsFixed(2)} ${state.currencyCode}',
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_left_rounded,
                color: accent.withValues(alpha: 0.4), size: 16),
          ],
        ),
      ),
    );
  }
}

Future<void> _openWalletAllocationSheet({
  required BuildContext ctx,
  required AppCubit cubit,
  required LinkedWalletEntity jar,
  required String walletId,
  required String walletName,
  required String walletIcon,
  String? walletColor,
  required List<TransactionEntity> relevantTransactions,
}) async {
  final jarId = jar.id;
  final accentBase = parseJarSheetColor(walletColor ?? jar.iconColor);

  await showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFFBF1),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (bCtx) => BlocBuilder<AppCubit, AppStateEntity>(
      bloc: cubit,
      builder: (bCtx, liveState) {
        final jarMatches = liveState.budgetSetup.linkedWallets
            .where((j) => j.id == jarId)
            .toList();
        final currentJar = jarMatches.isEmpty ? jar : jarMatches.first;
        final accent = accentBase;

        final liveRelevantTransactions = liveState.transactions
            .where((t) =>
                t.toWalletId == jarId ||
                t.walletId == jarId ||
                t.fromWalletId == jarId ||
                (t.type == TransactionType.income.value &&
                    t.toWalletId == jarId))
            .where((t) =>
                t.transferType == TransferType.jarAllocation.value ||
                t.transferType == TransferType.jarAllocationCancel.value ||
                t.transferType == TransferType.jarAllocationSpend.value ||
                t.transferType == TransferType.jarFunding.value ||
                t.transferType == TransferType.jarFundingPhysical.value ||
                t.transferType == TransferType.depositWithJarLabel.value ||
                t.transferType == TransferType.allocationToJar.value ||
                t.transferType == TransferType.jarToAllocation.value ||
                t.transferType == TransferType.jarToJar.value ||
                (t.type == TransactionType.income.value &&
                    t.budgetScope == BudgetScope.withinBudget.value))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final walletTxns = liveRelevantTransactions.where((t) {
          if (t.walletId != walletId && t.fromWalletId != walletId) {
            return false;
          }
          return t.transferType == TransferType.jarAllocation.value ||
              t.transferType == TransferType.jarAllocationCancel.value ||
              t.transferType == TransferType.jarFunding.value ||
              t.transferType == TransferType.jarFundingPhysical.value ||
              t.transferType == TransferType.depositWithJarLabel.value ||
              t.transferType == TransferType.jarToJar.value;
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final currentTotal = currentJar.walletSources
            .where((s) => s.walletId == walletId)
            .fold<double>(0, (sum, s) => sum + s.amount);

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (bCtx, ctrl) => Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.95),
                      accent.withValues(alpha: 0.72)
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: AppIconPickerDialog.iconWidgetForName(walletIcon,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(walletName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16)),
                        Text('معاملات الحجز',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ]),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${currentTotal.toStringAsFixed(2)} جنيه',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: walletTxns.isEmpty
                    ? Center(
                        child: Text('لا توجد معاملات حجز لهذه المحفظة',
                            style: TextStyle(
                                color: accent.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w600)))
                    : ListView(
                        controller: ctrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        children: [
                          SharedTransactionDayGroups(
                            transactions: walletTxns,
                            appState: liveState,
                            viewingContextId: currentJar.id,
                            onTap: (_) => _openReservationLabelEditor(
                              context: bCtx,
                              cubit: cubit,
                              jar: currentJar,
                              walletId: walletId,
                              currentAmount: currentJar.walletSources
                                  .where((s) => s.walletId == walletId)
                                  .fold<double>(0, (s, e) => s + e.amount),
                              accent: accent,
                            ),
                            onLongPress: (transaction) =>
                                openTransactionDetailsSheet(
                              bCtx,
                              cubit: cubit,
                              transaction: transaction,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> _openReservationLabelEditor({
  required BuildContext context,
  required AppCubit cubit,
  required LinkedWalletEntity jar,
  required String walletId,
  required double currentAmount,
  required Color accent,
}) async {
  final ctrl = TextEditingController(
      text: currentAmount > 0 ? currentAmount.toStringAsFixed(2) : '');
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFFBF1),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('تعديل الحجز',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            'هذا التعديل يغيّر فقط توزيع الفلوس داخل الحصالة\nبدون أي تأثير على المعاملات المرتبطة.',
            style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'المبلغ المحجوز من هذه المحفظة',
              suffixText: 'جنيه',
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await cubit.relabelJarWalletSource(
                      jarId: jar.id,
                      walletId: walletId,
                      newAmount: 0,
                    );
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('حذف الحجز'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final val = double.tryParse(ctrl.text.trim()) ?? 0;
                    await cubit.relabelJarWalletSource(
                      jarId: jar.id,
                      walletId: walletId,
                      newAmount: val,
                    );
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  },
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  child: const Text('حفظ'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<void> _openJarAdjustmentDialog({
  required BuildContext context,
  required AppCubit cubit,
  required LinkedWalletEntity jar,
  required _JarAdjustmentMode mode,
  String? initialWalletId,
}) async {
  final state = cubit.state;
  final availableWallets = state.wallets;
  if (availableWallets.isEmpty) return;

  final accent = parseJarSheetColor(jar.iconColor);
  var walletId = availableWallets.any((wallet) => wallet.id == initialWalletId)
      ? initialWalletId!
      : availableWallets.first.id;
  final amountController = TextEditingController();
  final notesController = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFFBF1),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final currentJar = cubit.state.budgetSetup.linkedWallets
            .where((j) => j.id == jar.id)
            .firstOrNull;
        final unallocatedAmount = _jarUnallocatedAmount(currentJar ?? jar);
        const title = 'تحديد مصدر أموال الحصالة';

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4C9B8),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.95),
                            accent.withValues(alpha: 0.70),
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: AppIconPickerDialog.iconWidgetForName(
                          jar.icon,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: accent,
                            ),
                          ),
                          Text(
                            jar.name,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8A7F72),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: accent.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اختر محفظة لربطها بالرصيد:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: accent.withValues(alpha: 0.70),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBF1),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: accent.withValues(alpha: 0.16)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: walletId,
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down_rounded,
                                color: accent),
                            items: availableWallets.map((w) {
                              return DropdownMenuItem(
                                value: w.id,
                                child: Text(
                                  w.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setDialogState(() => walletId = value);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 14, color: accent),
                            const SizedBox(width: 6),
                            Text(
                              'المتاح للربط (غير محدد): ${unallocatedAmount.toStringAsFixed(2)} جنيه',
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'المبلغ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: accent.withValues(alpha: 0.70),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          filled: true,
                          fillColor: const Color(0xFFFFFBF1),
                          suffixText: 'جنيه',
                          suffixStyle: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: accent.withValues(alpha: 0.16)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: accent.withValues(alpha: 0.16)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: accent, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ملاحظات (اختياري)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: accent.withValues(alpha: 0.70),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesController,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'أضف ملاحظة...',
                          filled: true,
                          fillColor: const Color(0xFFFFFBF1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: accent.withValues(alpha: 0.16)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: accent.withValues(alpha: 0.16)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: accent, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side:
                              BorderSide(color: accent.withValues(alpha: 0.30)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          foregroundColor: const Color(0xFF8A7F72),
                        ),
                        child: const Text(
                          'إلغاء',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final amount =
                              double.tryParse(amountController.text.trim()) ??
                                  0;
                          if (amount <= 0) return;

                          final liveJar = cubit.state.budgetSetup.linkedWallets
                              .firstWhere((j) => j.id == jar.id);

                          if (amount > liveJar.unlabeledAmount + 0.01) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'لا يمكن تخصيص مبلغ أكبر من الرصيد غير المحدد في الحصالة.')),
                            );
                            return;
                          }

                          await cubit.addTransaction(
                            walletId: walletId,
                            fromWalletId: walletId,
                            toWalletId: jar.id,
                            amount: amount,
                            type: TransactionType.transfer.value,
                            transferType: TransferType.jarAllocation.value,
                            notes: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                          );

                          if (!context.mounted) return;
                          Navigator.of(ctx).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          'تأكيد التخصيص',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Widget _jarSheetGlassMetric({
  required String label,
  required String value,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.82),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Widget _jarSheetIconAction(
  IconData icon, {
  required VoidCallback onTap,
  required String tooltip,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Tooltip(
      message: tooltip,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    ),
  );
}

Widget _jarSheetSectionHeader(String title) {
  return Align(
    alignment: AlignmentDirectional.centerEnd,
    child: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    ),
  );
}
