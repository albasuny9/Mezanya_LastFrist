import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/transaction_types.dart';
import '../../../../core/utils/transaction_display_format.dart';
import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../budget/domain/entities/money_location_review_entity.dart';
import '../../../money_distribution/domain/entities/distribution_entry.dart';
import '../../../money_distribution/domain/services/distribution_engine.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/widgets/shared_transaction_card.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';
import 'wallet_shared_widgets.dart';

/// مكان الفلوس داخل الحصالة — مبني مؤقتًا على walletSources
Map<String, double> jarWalletDistribution(AppStateEntity state, String jarId) {
  final liveEntries = jarDistributionEntries(state, jarId);
  if (liveEntries.isNotEmpty) {
    return DistributionEngine.summaryForJar(liveEntries, jarId);
  }
  if (state.moneyDistributionMigrationDone) return {};
  final jar =
      state.budgetSetup.linkedWallets.where((j) => j.id == jarId).firstOrNull;
  if (jar == null) return {};
  return {for (final s in jar.walletSources) s.walletId: s.amount};
}

List<DistributionEntry> jarDistributionEntries(
  AppStateEntity state,
  String jarId,
) {
  final entries = state.moneyDistributions
      .where((entry) => entry.jarId == jarId && entry.amount > 0)
      .toList();
  if (entries.isNotEmpty) return entries;
  if (state.moneyDistributionMigrationDone) return const [];

  final jar =
      state.budgetSetup.linkedWallets.where((j) => j.id == jarId).firstOrNull;
  if (jar == null) return const [];
  return [
    for (final source in jar.walletSources.where((item) => item.amount > 0))
      DistributionEntry.fromWalletSource(
        jarId: jarId,
        walletId: source.walletId,
        amount: source.amount,
      ),
  ];
}

double jarUnknownDistribution(AppStateEntity state, LinkedWalletEntity jar) {
  if (jar.balance <= 0) return 0;
  final known = DistributionEngine.totalForJar(
    jarDistributionEntries(state, jar.id),
    jar.id,
  );
  final unknown = jar.balance - known;
  return unknown > 0 ? unknown : 0;
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
          final unknownDistribution = jarUnknownDistribution(state, currentJar);
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
                                        '${jar.balance.toStringAsFixed(2)} ${currencyLabelAr(state.currencyCode)}',
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
                                    label: 'غير معروف المصدر',
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
                                                'أمـاكن الفلوس',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () =>
                                                  _openDistributionManagerSheet(
                                                context: context,
                                                cubit: cubit,
                                                jar: jar,
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
                                                    Text('إدارة',
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
                                        if (distribution.isEmpty &&
                                            unknownDistribution <= 0.01)
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
                                              'لا توجد أماكن فلوس لهذه الحصالة حتى الآن.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Color(0xFF8A7F72),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          )
                                        else ...[
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
                                                        '${e.value.toStringAsFixed(2)} ${currencyLabelAr(state.currencyCode)}',
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
                                          if (unknownDistribution > 0.01)
                                            _DistributionSummaryTile(
                                              name: 'غير معروف',
                                              amount: unknownDistribution,
                                              currencyCode: state.currencyCode,
                                            ),
                                        ],
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    // ── قائمة مراجعات مكان الفلوس ────────────────────────
                    if (jar.moneyLocationReviews.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _jarSheetSectionHeader('يحتاج مراجعة'),
                      const SizedBox(height: 8),
                      ...jar.moneyLocationReviews.map(
                        (review) => _MoneyLocationReviewCard(
                          review: review,
                          jar: jar,
                          cubit: cubit,
                          state: state,
                        ),
                      ),
                    ],
                    // ─────────────────────────────────────────────────────
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
                                  text: 'لا توجد معاملات لعرضها.')
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
              '${jar.balance.toStringAsFixed(2)} ${currencyLabelAr(state.currencyCode)}',
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
        final entries = jarDistributionEntries(liveState, jarId)
            .where((entry) => entry.walletId == walletId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final currentTotal = entries.fold<double>(
          0,
          (sum, entry) => sum + entry.amount,
        );

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
                        Text(
                          'مكان الفلوس',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                      '${currentTotal.toStringAsFixed(2)} ${currencyLabelAr(cubit.state.currencyCode)}',
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
                child: entries.isEmpty
                    ? Center(
                        child: Text('لا توجد أماكن فلوس داخل هذه المحفظة.',
                            style: TextStyle(
                                color: accent.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w600)))
                    : ListView(
                        controller: ctrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        children: entries
                            .map(
                              (entry) => _DistributionEntryTile(
                                entry: entry,
                                jarName: currentJar.name,
                                currencyCode: liveState.currencyCode,
                                accent: accent,
                                onTap: () => _openDistributionEntryActions(
                                  context: bCtx,
                                  cubit: cubit,
                                  entry: entry,
                                  accent: accent,
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _DistributionSummaryTile extends StatelessWidget {
  const _DistributionSummaryTile({
    required this.name,
    required this.amount,
    required this.currencyCode,
  });

  final String name;
  final double amount;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              '${amount.toStringAsFixed(2)} ${currencyLabelAr(currencyCode)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionEntryTile extends StatelessWidget {
  const _DistributionEntryTile({
    required this.entry,
    required this.jarName,
    required this.currencyCode,
    required this.accent,
    required this.onTap,
  });

  final DistributionEntry entry;
  final String jarName;
  final String currencyCode;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title =
        entry.origin == DistributionOrigin.manual ? 'Manual' : jarName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Text(
                '${entry.amount.toStringAsFixed(2)} ${currencyLabelAr(currencyCode)}',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openDistributionEntryActions({
  required BuildContext context,
  required AppCubit cubit,
  required DistributionEntry entry,
  required Color accent,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFFFFFBF1),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _distributionActionTile(
              icon: Icons.drive_file_move_rounded,
              label: 'نقل',
              onTap: () {
                Navigator.pop(sheetCtx);
                _openMoveDistributionEntrySheet(
                  context: context,
                  cubit: cubit,
                  entry: entry,
                  accent: accent,
                );
              },
            ),
            _distributionActionTile(
              icon: Icons.edit_outlined,
              label: 'تعديل',
              onTap: () {
                Navigator.pop(sheetCtx);
                _openEditDistributionEntryAmountSheet(
                  context: context,
                  cubit: cubit,
                  entry: entry,
                  accent: accent,
                );
              },
            ),
            _distributionActionTile(
              icon: Icons.delete_outline_rounded,
              label: 'حذف',
              isDestructive: true,
              onTap: () async {
                await cubit.deleteMoneyDistributionEntry(entry.id);
                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _distributionActionTile({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  bool isDestructive = false,
}) {
  final color =
      isDestructive ? const Color(0xFFDC2626) : const Color(0xFF165B47);
  return ListTile(
    leading: Icon(icon, color: color),
    title: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w800),
    ),
    onTap: onTap,
  );
}

Future<void> _openMoveDistributionEntrySheet({
  required BuildContext context,
  required AppCubit cubit,
  required DistributionEntry entry,
  required Color accent,
}) async {
  var walletId = entry.walletId;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFFBF1),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _walletDropdown(
              cubit: cubit,
              value: walletId,
              label: 'المحفظة',
              accent: accent,
              onChanged: (value) => setSheet(() => walletId = value),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                try {
                  await cubit.moveMoneyDistributionEntry(
                    entryId: entry.id,
                    toWalletId: walletId,
                  );
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                } on DistributionValidationException catch (error) {
                  _showDistributionError(sheetCtx, error.message);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: accent),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _openEditDistributionEntryAmountSheet({
  required BuildContext context,
  required AppCubit cubit,
  required DistributionEntry entry,
  required Color accent,
}) async {
  final amountCtrl =
      TextEditingController(text: entry.amount.toStringAsFixed(2));
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFFBF1),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'المبلغ',
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              try {
                await cubit.editMoneyDistributionEntryAmount(
                  entryId: entry.id,
                  amount: double.tryParse(amountCtrl.text.trim()) ?? 0,
                );
                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              } on DistributionValidationException catch (error) {
                _showDistributionError(sheetCtx, error.message);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: accent),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _openDistributionManagerSheet({
  required BuildContext context,
  required AppCubit cubit,
  required LinkedWalletEntity jar,
}) async {
  final amountCtrl = TextEditingController();
  final wallets = cubit.state.wallets;
  if (wallets.isEmpty) return;
  var mode = 'add';
  var walletId = wallets.first.id;
  var fromWalletId = wallets.first.id;
  var toWalletId = wallets.length > 1 ? wallets[1].id : wallets.first.id;
  final accent = parseJarSheetColor(jar.iconColor);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFFBF1),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheet) {
        final jarAllocations = DistributionEngine.summaryForJar(
          jarDistributionEntries(cubit.state, jar.id),
          jar.id,
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'إدارة مكان الفلوس',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'add', label: Text('إضافة')),
                  ButtonSegment(value: 'remove', label: Text('حذف')),
                  ButtonSegment(value: 'transfer', label: Text('نقل')),
                ],
                selected: {mode},
                onSelectionChanged: (value) =>
                    setSheet(() => mode = value.first),
              ),
              const SizedBox(height: 16),
              if (mode == 'transfer') ...[
                _walletDropdown(
                  cubit: cubit,
                  value: fromWalletId,
                  label: 'من محفظة',
                  accent: accent,
                  jarAllocations: jarAllocations,
                  onChanged: (value) => setSheet(() => fromWalletId = value),
                ),
                const SizedBox(height: 12),
                _walletDropdown(
                  cubit: cubit,
                  value: toWalletId,
                  label: 'إلى محفظة',
                  accent: accent,
                  jarAllocations: jarAllocations,
                  onChanged: (value) => setSheet(() => toWalletId = value),
                ),
              ] else
                _walletDropdown(
                  cubit: cubit,
                  value: walletId,
                  label: 'المحفظة',
                  accent: accent,
                  jarAllocations: jarAllocations,
                  onChanged: (value) => setSheet(() => walletId = value),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'المبلغ',
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: accent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  try {
                    if (mode == 'add') {
                      await cubit.addMoneyDistribution(
                        jarId: jar.id,
                        walletId: walletId,
                        amount: amount,
                      );
                    } else if (mode == 'remove') {
                      await cubit.removeMoneyDistribution(
                        jarId: jar.id,
                        walletId: walletId,
                        amount: amount,
                      );
                    } else {
                      await cubit.transferMoneyDistribution(
                        jarId: jar.id,
                        fromWalletId: fromWalletId,
                        toWalletId: toWalletId,
                        amount: amount,
                      );
                    }
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                    await cubit.autoResolveReviewsIfConsistent(jar.id);
                  } on DistributionValidationException catch (error) {
                    if (sheetCtx.mounted) {
                      _showDistributionError(sheetCtx, error.message);
                    }
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: accent),
                child: const Text('تأكيد'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Widget _walletDropdown({
  required AppCubit cubit,
  required String value,
  required String label,
  required Color accent,
  required ValueChanged<String> onChanged,
  Map<String, double>? jarAllocations,
}) {
  return DropdownButtonFormField<String>(
    value: value,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: accent, width: 2),
      ),
    ),
    items: cubit.state.wallets
        .map(
          (wallet) => DropdownMenuItem(
            value: wallet.id,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(wallet.name),
                if (jarAllocations != null)
                  Text(
                    'في الحصالة: ${(jarAllocations[wallet.id] ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8A7F72),
                    ),
                  ),
              ],
            ),
          ),
        )
        .toList(),
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
  );
}

void _showDistributionError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Widget _jarSheetIconAction(
  IconData icon, {
  required VoidCallback onTap,
  required String tooltip,
}) {
  return Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    ),
  );
}

Widget _jarSheetGlassMetric({
  required String label,
  required String value,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
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

// ─────────────────────────────────────────────────────────────
// بطاقة مكان الفلوس
// ─────────────────────────────────────────────────────────────

/// تعرض ملخص أماكن الفلوس داخل الحصالة.
///
/// توضح المحافظ التي تحتوي على جزء من رصيد الحصالة
/// مع المبلغ الموجود في كل محفظة.
///
/// إذا كان جزء من الرصيد غير محدد مكانه، فسيظهر ضمن
/// "غير معروف".
///
/// هذه البطاقة تعرض بيانات مكان الفلوس فقط، ولا تعرض
/// المعاملات أو تعدل الأرصدة المالية.
class _MoneyLocationReviewCard extends StatelessWidget {
  const _MoneyLocationReviewCard({
    required this.review,
    required this.jar,
    required this.cubit,
    required this.state,
  });

  final MoneyLocationReview review;
  final LinkedWalletEntity jar;
  final AppCubit cubit;
  final AppStateEntity state;

  String get _typeLabel {
    switch (review.type) {
      case 'spending-wallet-mismatch':
        return 'تم الإنفاق من محفظة غير مسجلة كمكان للفلوس';

      case 'source-went-negative':
        return 'قيمة مكان الفلوس غير صالحة';

      case 'labeled-exceeds-balance':
        return 'إجمالي أماكن الفلوس أكبر من رصيد الحصالة';

      default:
        return 'يحتاج مراجعة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: const Color(0xFFD4A017).withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFC58B00),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _typeLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF7A5500),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${review.amount.toStringAsFixed(2)} '
                        '${currencyLabelAr(state.currencyCode)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF7A5500),
                        ),
                      ),
                      if (review.notes != null && review.notes!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            review.notes!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFA07020),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    await cubit.resolveMoneyLocationReview(
                      jarId: jar.id,
                      reviewId: review.id,
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFC58B00),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text(
                    'تجاهل',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: () async {
                    await _openDistributionManagerSheet(
                      context: context,
                      cubit: cubit,
                      jar: jar,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC58B00),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'صلّح الآن',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
