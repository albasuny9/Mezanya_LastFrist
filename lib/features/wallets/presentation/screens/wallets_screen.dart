import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/widgets/shared_transaction_card.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';
import '../../domain/entities/wallet_entity.dart';
import 'jar_editor_screen.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  static const _green = Color(0xFF165B47);
  static const _teal = Color(0xFF0F766E);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;
        final wallets = state.wallets;
        final jars = _orderedJars(state.budgetSetup.linkedWallets);
        wallets.fold<double>(0, (s, w) => s + w.balance);
        jars.fold<double>(0, (s, j) => s + j.balance);

        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 110),
          children: [
            const SizedBox(height: 16),
            // ── Wallets section ─────────────────────────────────────────
            _overviewSection(
              title: 'المحافظ',
              subtitle: 'الأماكن الحقيقية للفلوس: كاش، بنك، أو أي محفظة.',
              accent: _green,
              sectionIcon: Icons.account_balance_wallet_rounded,
              addTooltip: 'إضافة محفظة',
              transferTooltip: 'تحويل بين المحافظ',
              onAdd: () => _openWalletEditor(),
              onTransfer: wallets.length < 2 ? null : _openWalletTransferDialog,
              onMore: () => _openWalletsPage(state),
              child: wallets.isEmpty
                  ? const _EmptyStateCard(
                      title: 'لا توجد محافظ بعد',
                      subtitle: 'أضف محفظة فعلية لتسجيل الفلوس الحقيقية.',
                    )
                  : Column(
                      children: wallets.take(2).map((wallet) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _compactWalletTile(state, wallet),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 16),

            // ── Jars section ────────────────────────────────────────────
            _overviewSection(
              title: 'الحصالات',
              subtitle: 'أوعية تنظيم ذهني للفلوس داخل المحافظ.',
              accent: _teal,
              sectionIcon: Icons.savings_rounded,
              addTooltip: 'إضافة حصالة',
              transferTooltip: 'تحويل بين الحصالات',
              onAdd: () => _openJarEditor(),
              onTransfer:
                  jars.length < 2 && state.budgetSetup.allocations.isEmpty
                      ? null
                      : () => _openInternalTransferDialog(),
              onMore: () => _openJarsPage(state),
              child: jars.isEmpty
                  ? const _EmptyStateCard(
                      title: 'لا توجد حصالات بعد',
                      subtitle:
                          'ابدأ بحصالة التوفير أو أنشئ حصالة لتنظيم جزء من فلوسك.',
                    )
                  : Column(
                      children: jars.take(2).map((jar) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _compactJarTile(state, jar),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _overviewSection({
    required String title,
    required String subtitle,
    required Color accent,
    required IconData sectionIcon,
    required String addTooltip,
    required String transferTooltip,
    required VoidCallback onAdd,
    required VoidCallback? onTransfer,
    required VoidCallback onMore,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(sectionIcon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.65),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.swap_horiz_rounded,
                  accent: accent,
                  enabled: onTransfer != null,
                  onTap: onTransfer ?? () {},
                  tooltip: transferTooltip,
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.add_rounded,
                  accent: accent,
                  enabled: true,
                  onTap: onAdd,
                  tooltip: addTooltip,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Divider ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: accent.withValues(alpha: 0.10)),
          ),
          const SizedBox(height: 14),

          // ── Content ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
          const SizedBox(height: 12),

          // ── More button ─────────────────────────────────────────────
          GestureDetector(
            onTap: onMore,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'عرض الكل',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_back_ios_new_rounded,
                      color: accent, size: 11),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactWalletTile(AppStateEntity state, WalletEntity wallet) {
    final reserved = _walletReservedAmount(state, wallet.id);
    final accent = _parseColor(wallet.iconColor ?? '#165b47');
    return _compactEntityTile(
      title: wallet.name,
      subtitle: reserved > 0
          ? 'محجوز للحصالات: ${reserved.toStringAsFixed(2)}'
          : 'الرصيد متاح بالكامل',
      amount: wallet.balance,
      icon: wallet.icon ?? 'account_balance_wallet',
      accent: accent,
      onTap: () => _openWalletDetailsSheet(wallet),
    );
  }

  Widget _compactJarTile(AppStateEntity state, LinkedWalletEntity jar) {
    final distribution = _jarDistribution(state, jar.id);
    final accent = _parseColor(jar.iconColor);
    return _compactEntityTile(
      title: jar.name,
      subtitle: distribution.isEmpty
          ? 'لم يتم توزيعها على محافظ بعد'
          : 'موزعة على ${distribution.length} محفظة',
      amount: jar.balance,
      icon: jar.icon,
      accent: accent,
      onTap: () => _openJarDetailsSheet(jar),
    );
  }

  Widget _compactEntityTile({
    required String title,
    required String subtitle,
    required double amount,
    required String icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.18), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon bubble
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: AppIconPickerDialog.iconWidgetForName(
                  icon,
                  color: accent,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: accent.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Amount + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount.toStringAsFixed(2),
                  style: TextStyle(
                    color: accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Icon(
                  Icons.chevron_left_rounded,
                  color: accent.withValues(alpha: 0.45),
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openWalletsPage(AppStateEntity state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _WalletsListPage(
          cubit: widget.cubit,
          onWalletTap: (w, showReservations) => _openWalletDetailsSheet(
            w,
            initialShowJars: showReservations,
          ),
        ),
      ),
    );
  }

  void _openJarsPage(AppStateEntity state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _JarsListPage(
          cubit: widget.cubit,
          onJarTap: (j) => _openJarDetailsSheet(j),
        ),
      ),
    );
  }

  Future<void> _openWalletDetailsSheet(
    WalletEntity wallet, {
    bool initialShowJars = false,
  }) async {
    final state = widget.cubit.state;
    final accent = _parseColor(wallet.iconColor ?? '#165b47');
    final reserved = _walletReservedAmount(state, wallet.id);
    final available = wallet.balance - reserved;
    final reservations =
        _walletReservations(state, wallet.id); // jarId -> amount

    final walletTx = state.transactions
        .where((t) =>
            t.walletId == wallet.id ||
            t.toWalletId == wallet.id ||
            t.fromWalletId == wallet.id)
        .where((t) => !_isVirtualJarTransaction(t))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFBF1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        var showJars = initialShowJars;
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
                  // ── Hero Card ──────────────────────────────────────────
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
                        // ── Top: icon + name + actions ──────────────────
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
                                  child: AppIconPickerDialog.iconWidgetForName(
                                    wallet.icon ?? 'account_balance_wallet',
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      wallet.name,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${wallet.balance.toStringAsFixed(2)} جنيه',
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
                              _iconAction(
                                Icons.settings_outlined,
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  _openWalletEditor(current: wallet);
                                },
                                tooltip: 'تعديل',
                              ),
                              const SizedBox(width: 6),
                              _iconAction(
                                Icons.add_circle_outline_rounded,
                                onTap: () =>
                                    _openWalletAllocateToJarDialog(wallet),
                                tooltip: 'تخصيص للحصالة',
                              ),
                              const SizedBox(width: 6),
                              // Expand arrow
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        // ── Metrics row ─────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            children: [
                              Expanded(
                                child: _glassMetric(
                                  label: 'الرصيد الكلي',
                                  value: wallet.balance.toStringAsFixed(2),
                                  accent: accent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _glassMetric(
                                  label: 'الصافي المتاح',
                                  value: available.toStringAsFixed(2),
                                  accent: accent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _glassMetric(
                                  label: 'الحصالات',
                                  value: reservations.length.toString(),
                                  accent: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ── Wide toggle button ───────────────────────────
                        GestureDetector(
                          onTap: () => setSheet(() => showJars = !showJars),
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
                                  turns: showJars ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 260),
                                  child: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  showJars
                                      ? 'إخفاء التخصيصات'
                                      : 'عرض التخصيصات للحصالات',
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
                      ],
                    ),
                  ),

                  // ── Jar allocations panel (below card) ─────────────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: showJars
                        ? Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.savings_rounded,
                                        color: accent,
                                        size: 17,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'التخصيصات للحصالات',
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (reservations.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBF1),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.10),
                                      ),
                                    ),
                                    child: const Text(
                                      'لا يوجد تخصيص لأي حصالة من هذه المحفظة حتى الآن.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF8A7F72),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                else
                                  ...reservations.entries.map((e) {
                                    final matchedJars = state
                                        .budgetSetup.linkedWallets
                                        .where((j) => j.id == e.key)
                                        .toList();
                                    final jarName = matchedJars.isEmpty
                                        ? 'حصالة'
                                        : matchedJars.first.name;
                                    final jarIcon = matchedJars.isEmpty
                                        ? 'savings'
                                        : matchedJars.first.icon;
                                    final jarAccent = matchedJars.isEmpty
                                        ? accent
                                        : _parseColor(
                                            matchedJars.first.iconColor);
                                    final ratio = reserved <= 0
                                        ? 0.0
                                        : (e.value / reserved).clamp(0.0, 1.0);
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFFBF1),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color:
                                                accent.withValues(alpha: 0.14),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    color: jarAccent.withValues(
                                                        alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            11),
                                                  ),
                                                  child: Center(
                                                    child: AppIconPickerDialog
                                                        .iconWidgetForName(
                                                      jarIcon,
                                                      color: jarAccent,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    jarName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  e.value.toStringAsFixed(2),
                                                  style: TextStyle(
                                                    color: jarAccent,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              child: LinearProgressIndicator(
                                                value: ratio,
                                                minHeight: 5,
                                                backgroundColor: accent
                                                    .withValues(alpha: 0.12),
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                        jarAccent),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 20),
                  // ── Transactions ───────────────────────────────────────
                  _sectionHeader('المعاملات'),
                  const SizedBox(height: 10),
                  if (walletTx.isEmpty)
                    const _InlineNote(
                      text: 'لا توجد حركات مسجلة على هذه المحفظة حتى الآن.',
                    )
                  else
                    ...walletTx.take(30).map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SharedTransactionCard(
                              transaction: t,
                              appState: widget.cubit.state,
                              onTap: () => openTransactionDetailsSheet(
                                ctx,
                                cubit: widget.cubit,
                                transaction: t,
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openJarDetailsSheet(LinkedWalletEntity jar) async {
    final state = widget.cubit.state;
    final distribution = _jarDistribution(state, jar.id);
    final relevantTransactions = state.transactions
        .where((t) =>
            t.toWalletId == jar.id ||
            t.walletId == jar.id ||
            (t.type == 'income' && t.toWalletId == jar.id))
        .where((t) =>
            t.transferType == 'jar-allocation' ||
            t.transferType == 'jar-allocation-cancel' ||
            t.transferType == 'jar-allocation-spend' ||
            t.transferType == 'jar-funding' ||
            t.transferType == 'jar-funding-physical' ||
            t.transferType == 'deposit-with-jar-label' ||
            t.transferType == 'allocation-to-jar' ||
            t.transferType == 'jar-to-allocation' ||
            (t.type == 'income' && t.budgetScope == 'within-budget'))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final accent = _parseColor(jar.iconColor);

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
                  // ── Hero Card ──────────────────────────────────────────
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
                        // ── Top: icon + name + actions ──────────────────
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
                                  child: AppIconPickerDialog.iconWidgetForName(
                                    jar.icon,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      '${jar.balance.toStringAsFixed(2)} جنيه',
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
                              _iconAction(Icons.settings_outlined, onTap: () {
                                Navigator.of(ctx).pop();
                                _openJarEditor(current: jar);
                              }, tooltip: 'تعديل'),
                              const SizedBox(width: 6),
                              _iconAction(
                                Icons.add_circle_outline_rounded,
                                onTap: () => _openJarAdjustmentDialog(
                                  jar: jar,
                                  mode: _JarAdjustmentMode.allocate,
                                ),
                                tooltip: 'تخصيص للحصالة',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        // ── Metrics row ─────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            children: [
                              Expanded(
                                child: _glassMetric(
                                  label: 'الرصيد الكلي',
                                  value: jar.balance.toStringAsFixed(2),
                                  accent: accent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _glassMetric(
                                  label: 'شهري مخطط',
                                  value: jar.monthlyAmount.toStringAsFixed(2),
                                  accent: accent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _glassMetric(
                                  label: 'المحافظ',
                                  value: distribution.length.toString(),
                                  accent: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ── Wide toggle button ───────────────────────────
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
                                      ? 'إخفاء التخصيصات'
                                      : 'عرض التخصيصات من المحافظ',
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
                      ],
                    ),
                  ),

                  // ── Wallet distribution panel (below card) ─────────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: showWallets
                        ? Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.account_balance_wallet_rounded,
                                        color: accent,
                                        size: 17,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'التخصيصات من المحافظ',
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
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
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.10),
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
                                    final walletName = matchedWallets.isEmpty
                                        ? 'محفظة'
                                        : matchedWallets.first.name;
                                    final walletIcon = matchedWallets.isEmpty
                                        ? 'account_balance_wallet'
                                        : (matchedWallets.first.icon ??
                                            'account_balance_wallet');
                                    final ratio = jar.balance <= 0
                                        ? 0.0
                                        : (e.value / jar.balance)
                                            .clamp(0.0, 1.0);
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFFBF1),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color:
                                                accent.withValues(alpha: 0.14),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    color: accent.withValues(
                                                        alpha: 0.10),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            11),
                                                  ),
                                                  child: Center(
                                                    child: AppIconPickerDialog
                                                        .iconWidgetForName(
                                                      walletIcon,
                                                      color: accent,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    walletName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  e.value.toStringAsFixed(2),
                                                  style: TextStyle(
                                                    color: accent,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                GestureDetector(
                                                  onTap: () =>
                                                      _openJarAdjustmentDialog(
                                                    jar: jar,
                                                    mode: _JarAdjustmentMode
                                                        .cancel,
                                                  ),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: accent.withValues(
                                                          alpha: 0.10),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: Text(
                                                      'إلغاء',
                                                      style: TextStyle(
                                                        color: accent,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              child: LinearProgressIndicator(
                                                value: ratio,
                                                minHeight: 5,
                                                backgroundColor: accent
                                                    .withValues(alpha: 0.12),
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                        accent),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 20),
                  // ── Transactions ───────────────────────────────────────
                  _sectionHeader('المعاملات'),
                  const SizedBox(height: 10),
                  if (relevantTransactions.isEmpty)
                    const _InlineNote(
                      text: 'لا توجد حركات مسجلة على هذه الحصالة حتى الآن.',
                    )
                  else
                    ...relevantTransactions.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SharedTransactionCard(
                          transaction: t,
                          appState: widget.cubit.state,
                          onTap: () => openTransactionDetailsSheet(
                            ctx,
                            cubit: widget.cubit,
                            transaction: t,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openJarAdjustmentDialog({
    required LinkedWalletEntity jar,
    required _JarAdjustmentMode mode,
  }) async {
    final state = widget.cubit.state;
    final sourceDistribution = _jarDistribution(state, jar.id);
    final availableWallets = mode == _JarAdjustmentMode.allocate
        ? state.wallets
        : state.wallets
            .where((wallet) => (sourceDistribution[wallet.id] ?? 0) > 0)
            .toList();
    if (availableWallets.isEmpty) return;

    final accent = _parseColor(jar.iconColor);
    var walletId = availableWallets.first.id;
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
          final distribution = _jarDistribution(widget.cubit.state, jar.id);
          final unallocatedAmount =
              _jarUnallocatedAmount(widget.cubit.state, jar);
          final selectedReserved = distribution[walletId] ?? 0;
          final isAllocate = mode == _JarAdjustmentMode.allocate;
          final title =
              isAllocate ? 'تحديد مصدر أموال الحصالة' : 'إلغاء ربط من المحفظة';

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
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
                // Header
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
                // Form card
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
                          isAllocate
                              ? 'اختر محفظة لربطها بالرصيد:'
                              : 'اختر محفظة لإلغاء الربط منها:',
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
                            border: Border.all(
                                color: accent.withValues(alpha: 0.16)),
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
                                isAllocate
                                    ? 'المتاح للربط (غير محدد): ${unallocatedAmount.toStringAsFixed(2)} جنيه'
                                    : 'المتاح للإلغاء: ${selectedReserved.toStringAsFixed(2)} جنيه',
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
                        // Amount field
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
                        // Notes field
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
                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                                color: accent.withValues(alpha: 0.30)),
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

                            final currentJar = widget
                                .cubit.state.budgetSetup.linkedWallets
                                .firstWhere((j) => j.id == jar.id);

                            if (isAllocate) {
                              if (amount > currentJar.unlabeledAmount + 0.01) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'لا يمكن تخصيص مبلغ أكبر من الرصيد غير المحدد في الحصالة.')),
                                );
                                return;
                              }
                              // إضافة أو زيادة label المحفظة
                              final existing =
                                  currentJar.walletSources.firstWhere(
                                (s) => s.walletId == walletId,
                                orElse: () => JarWalletSource(
                                    walletId: walletId, amount: 0),
                              );
                              final newSources = [
                                ...currentJar.walletSources
                                    .where((s) => s.walletId != walletId),
                                JarWalletSource(
                                    walletId: walletId,
                                    amount: existing.amount + amount),
                              ];
                              await widget.cubit.updateJarWalletSources(
                                jarId: jar.id,
                                sources: newSources,
                              );
                            } else {
                              if (amount > selectedReserved + 0.01) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'لا يمكن إلغاء تخصيص مبلغ أكبر من المربوط حالياً بهذه المحفظة.')),
                                );
                                return;
                              }
                              // تخفيض أو حذف label المحفظة
                              final existing =
                                  currentJar.walletSources.firstWhere(
                                (s) => s.walletId == walletId,
                                orElse: () => JarWalletSource(
                                    walletId: walletId, amount: 0),
                              );
                              final newAmt = (existing.amount - amount)
                                  .clamp(0.0, double.infinity);
                              final newSources = [
                                ...currentJar.walletSources
                                    .where((s) => s.walletId != walletId),
                                if (newAmt > 0)
                                  JarWalletSource(
                                      walletId: walletId, amount: newAmt),
                              ];
                              await widget.cubit.updateJarWalletSources(
                                jarId: jar.id,
                                sources: newSources,
                              );
                            }

                            if (!mounted) return;
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
                          child: Text(
                            isAllocate ? 'تأكيد التخصيص' : 'تأكيد الإلغاء',
                            style: const TextStyle(
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

  Future<void> _openInternalTransferDialog({
    LinkedWalletEntity? sourceJar,
  }) async {
    final state = widget.cubit.state;
    final jars = _orderedJars(state.budgetSetup.linkedWallets);
    final allocations = state.budgetSetup.allocations;

    if (jars.isEmpty && allocations.isEmpty) return;

    // Initial state
    String sourceId = sourceJar?.id ??
        (jars.isNotEmpty ? jars.first.id : allocations.first.id);
    String sourceType = (sourceJar != null || jars.any((j) => j.id == sourceId))
        ? 'jar'
        : 'allocation';

    String targetId = jars.any((j) => j.id != sourceId)
        ? jars.firstWhere((j) => j.id != sourceId).id
        : (allocations.isNotEmpty ? allocations.first.id : jars.first.id);
    String targetType =
        jars.any((j) => j.id == targetId) ? 'jar' : 'allocation';

    String selectedWalletId = '';
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentState = widget.cubit.state;

          // Data Resolvers
          dynamic sourceItem;
          if (sourceType == 'jar') {
            sourceItem = currentState.budgetSetup.linkedWallets
                .firstWhere((j) => j.id == sourceId);
          } else {
            sourceItem = currentState.budgetSetup.allocations
                .firstWhere((a) => a.id == sourceId);
          }

          dynamic targetItem;
          if (targetType == 'jar') {
            targetItem = currentState.budgetSetup.linkedWallets
                .firstWhere((j) => j.id == targetId);
          } else {
            targetItem = currentState.budgetSetup.allocations
                .firstWhere((a) => a.id == targetId);
          }

          // Wallet selection logic for Source (Jar or Allocation)
          List<Map<String, dynamic>> walletOptions = [];
          final distribution = sourceType == 'jar'
              ? _jarDistribution(currentState, sourceId)
              : _allocationDistribution(currentState, sourceId);
          final unallocated = _jarUnallocatedAmount(currentState, sourceItem);

          for (final wallet in currentState.wallets) {
            final amount = distribution[wallet.id] ?? 0;
            if (amount > 0.01) {
              walletOptions.add({
                'id': wallet.id,
                'name': wallet.name,
                'amount': amount,
              });
            }
          }
          if (unallocated > 0.01) {
            walletOptions.add({
              'id': 'unallocated',
              'name': 'بدون محفظة',
              'amount': unallocated,
            });
          }

          if (selectedWalletId.isEmpty && walletOptions.isNotEmpty) {
            selectedWalletId = walletOptions.first['id'] as String;
          } else if (selectedWalletId.isNotEmpty &&
              !walletOptions.any((w) => w['id'] == selectedWalletId)) {
            selectedWalletId = walletOptions.isNotEmpty
                ? walletOptions.first['id'] as String
                : '';
          }

          final selectedWalletAmount = walletOptions.isNotEmpty
              ? (walletOptions.firstWhere((w) => w['id'] == selectedWalletId,
                  orElse: () => {'amount': 0.0})['amount'] as double)
              : double.infinity;

          return Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBF1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const Text('تحويل داخلي',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 24),
                  _TransferItemTile(
                    label: 'من',
                    title: sourceType == 'jar'
                        ? (sourceItem as LinkedWalletEntity).name
                        : (sourceItem as AllocationEntity).name,
                    icon: sourceType == 'jar'
                        ? (sourceItem as LinkedWalletEntity).icon
                        : (sourceItem as AllocationEntity).icon,
                    accent: _parseColor(sourceType == 'jar'
                        ? (sourceItem as LinkedWalletEntity).iconColor
                        : (sourceItem as AllocationEntity).iconColor),
                    amount: sourceType == 'jar'
                        ? (sourceItem as LinkedWalletEntity).balance
                        : (sourceItem as AllocationEntity).balance,
                    onTap: () => _showInternalItemPicker(
                      title: 'اختر المصدر',
                      onSelected: (id, type) {
                        setDialogState(() {
                          sourceId = id;
                          sourceType = type;
                          selectedWalletId = '';
                        });
                      },
                    ),
                  ),
                  if (walletOptions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('من محفظة فعليّة:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.black54)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: walletOptions.map((opt) {
                        final isSelected = selectedWalletId == opt['id'];
                        return GestureDetector(
                          onTap: () => setDialogState(
                              () => selectedWalletId = opt['id'] as String),
                          child: Container(
                            width: (MediaQuery.of(context).size.width - 56) / 3,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0F766E)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF0F766E)
                                      : Colors.black.withValues(alpha: 0.08)),
                            ),
                            child: Column(
                              children: [
                                Text(opt['name'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87)),
                                const SizedBox(height: 4),
                                Text(
                                    (opt['amount'] as double)
                                        .toStringAsFixed(0),
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF0F766E))),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Icon(Icons.keyboard_double_arrow_down_rounded,
                          color: Colors.black26)),
                  _TransferItemTile(
                    label: 'إلى',
                    title: targetType == 'jar'
                        ? (targetItem as LinkedWalletEntity).name
                        : (targetItem as AllocationEntity).name,
                    icon: targetType == 'jar'
                        ? (targetItem as LinkedWalletEntity).icon
                        : (targetItem as AllocationEntity).icon,
                    accent: _parseColor(targetType == 'jar'
                        ? (targetItem as LinkedWalletEntity).iconColor
                        : (targetItem as AllocationEntity).iconColor),
                    amount: targetType == 'jar'
                        ? (targetItem as LinkedWalletEntity).balance
                        : (targetItem as AllocationEntity).balance,
                    onTap: () => _showInternalItemPicker(
                      title: 'اختر الوجهة',
                      onSelected: (id, type) {
                        setDialogState(() {
                          targetId = id;
                          targetType = type;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900),
                    decoration: InputDecoration(
                      labelText: 'المبلغ',
                      prefixIcon: const Icon(Icons.monetization_on_outlined),
                      suffixText: 'جنيه',
                      helperText: walletOptions.isNotEmpty
                          ? 'المتاح من المحفظة: ${selectedWalletAmount.toStringAsFixed(2)}'
                          : null,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                        labelText: 'ملاحظات (اختياري)',
                        prefixIcon: Icon(Icons.notes_rounded)),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () async {
                      final amount =
                          double.tryParse(amountController.text.trim()) ?? 0;
                      if (amount <= 0) return;
                      if (walletOptions.isNotEmpty &&
                          amount > selectedWalletAmount + 0.01) {
                        return;
                      }
                      if (sourceId == targetId && sourceType == targetType) {
                        return;
                      }

                      Navigator.of(context).pop();

                      final actualWalletId =
                          (selectedWalletId == 'unallocated' ||
                                  selectedWalletId.isEmpty)
                              ? null
                              : selectedWalletId;

                      if (sourceType == 'jar' && targetType == 'jar') {
                        // تحويل بين حصالتين — label فقط بدون transaction
                        await widget.cubit.transferBetweenJars(
                          sourceJarId: sourceId,
                          targetJarId: targetId,
                          amount: amount,
                          physicalWalletId: actualWalletId,
                        );
                      } else {
                        // تحويل يشمل مخصص — نستخدم transaction افتراضية
                        await widget.cubit.addTransaction(
                          type: 'transfer',
                          fromWalletId: sourceId,
                          toWalletId: targetId,
                          walletId: actualWalletId,
                          amount: amount,
                          transferType: 'internal-transfer',
                          notes: notesController.text.trim().isEmpty
                              ? 'تحويل داخلي'
                              : notesController.text.trim(),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF0F766E)),
                    child: const Text('تأكيد التحويل',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showInternalItemPicker({
    required String title,
    required void Function(String id, String type) onSelected,
  }) {
    final state = widget.cubit.state;
    final jars = _orderedJars(state.budgetSetup.linkedWallets);
    final allocations = state.budgetSetup.allocations;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFBF1),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          if (jars.isNotEmpty) ...[
            const Row(children: [
              Icon(Icons.savings_rounded, size: 16),
              SizedBox(width: 8),
              Text('الحصالات',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: Colors.teal))
            ]),
            const Divider(),
            ...jars.map((j) => ListTile(
                  leading: AppIconPickerDialog.iconWidgetForName(j.icon,
                      color: _parseColor(j.iconColor)),
                  title: Text(j.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${j.balance.toStringAsFixed(2)} جنيه'),
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(j.id, 'jar');
                  },
                )),
          ],
          if (allocations.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Row(children: [
              Icon(Icons.category_rounded, size: 16),
              SizedBox(width: 8),
              Text('المخصصات',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: Colors.orange))
            ]),
            const Divider(),
            ...allocations.map((a) => ListTile(
                  leading: AppIconPickerDialog.iconWidgetForName(a.icon,
                      color: _parseColor(a.iconColor)),
                  title: Text(a.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(a.id, 'allocation');
                  },
                )),
          ],
        ],
      ),
    );
  }

  Future<void> _openWalletAllocateToJarDialog(WalletEntity wallet) async {
    final jars = _orderedJars(widget.cubit.state.budgetSetup.linkedWallets);
    if (jars.isEmpty) {
      return;
    }

    var jarId = jars.first.id;
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تخصيص من المحفظة إلى حصالة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: jarId,
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
                  if (value == null) return;
                  setDialogState(() => jarId = value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'المبلغ'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final amount =
                    double.tryParse(amountController.text.trim()) ?? 0;
                if (amount <= 0) {
                  return;
                }
                final targetJar = jars.firstWhere((jar) => jar.id == jarId);
                await widget.cubit.addTransaction(
                  type: 'transfer',
                  fromWalletId: wallet.id,
                  toWalletId: targetJar.id,
                  amount: amount,
                  transferType: 'jar-allocation',
                  notes: notesController.text.trim().isEmpty
                      ? 'تخصيص ${amount.toStringAsFixed(2)} من ${wallet.name} إلى ${targetJar.name}'
                      : notesController.text.trim(),
                );
                if (targetJar.id == 'linked-savings-default') {
                  await widget.cubit.applySavingsReserve(
                    walletId: wallet.id,
                    amount: amount,
                    action: 'allocate',
                  );
                }
                if (!mounted) {
                  return;
                }
                Navigator.of(context).pop();
              },
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWalletTransferDialog() async {
    final wallets = widget.cubit.state.wallets;
    if (wallets.length < 2) return;
    var fromId = wallets.first.id;
    var toId = wallets[1].id;
    final amountController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final fromWallet = wallets.firstWhere((w) => w.id == fromId);
          final toWallet = wallets.firstWhere((w) => w.id == toId);

          return Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBF1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const Text('تحويل بين المحافظ',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 24),

                  // من
                  _WalletPickerTile(
                    label: 'من',
                    wallet: fromWallet,
                    onTap: () => _showWalletPicker(
                      title: 'اختر المحفظة المصدر',
                      wallets: wallets,
                      excludeId: toId,
                      onSelected: (id) => setDialogState(() => fromId = id),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Icon(Icons.keyboard_double_arrow_down_rounded,
                        color: Colors.black26, size: 28),
                  ),

                  // إلى
                  _WalletPickerTile(
                    label: 'إلى',
                    wallet: toWallet,
                    onTap: () => _showWalletPicker(
                      title: 'اختر المحفظة الوجهة',
                      wallets: wallets,
                      excludeId: fromId,
                      onSelected: (id) => setDialogState(() => toId = id),
                    ),
                  ),

                  const SizedBox(height: 24),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900),
                    decoration: InputDecoration(
                      labelText: 'المبلغ',
                      prefixIcon: const Icon(Icons.monetization_on_outlined),
                      suffixText: 'جنيه',
                      helperText:
                          'الرصيد المتاح: ${fromWallet.balance.toStringAsFixed(2)} جنيه',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),

                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () async {
                      final amount =
                          double.tryParse(amountController.text.trim()) ?? 0;
                      if (amount <= 0 || fromId == toId) return;
                      Navigator.of(context).pop();
                      await widget.cubit.addTransaction(
                        type: 'transfer',
                        amount: amount,
                        fromWalletId: fromId,
                        toWalletId: toId,
                        transferType: 'wallet-to-wallet',
                        notes: 'تحويل بين المحافظ',
                      );
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF165B47),
                    ),
                    child: const Text('تأكيد التحويل',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showWalletPicker({
    required String title,
    required List<WalletEntity> wallets,
    required String excludeId,
    required void Function(String id) onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFBF1),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          ...wallets.where((w) => w.id != excludeId).map((w) => ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _parseColor(w.iconColor ?? '#165b47')
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: AppIconPickerDialog.iconWidgetForName(
                        w.icon ?? 'account_balance_wallet',
                        color: _parseColor(w.iconColor ?? '#165b47'),
                        size: 22),
                  ),
                ),
                title: Text(w.name,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${w.balance.toStringAsFixed(2)} جنيه'),
                onTap: () {
                  Navigator.pop(context);
                  onSelected(w.id);
                },
              )),
        ],
      ),
    );
  }

  void _openWalletEditor({WalletEntity? current}) {
    final nameController = TextEditingController(text: current?.name ?? '');
    final balanceController =
        TextEditingController(text: (current?.balance ?? 0).toStringAsFixed(0));
    var selectedColor = current?.iconColor ?? '#165b47';
    var selectedIcon = current?.icon ?? 'account_balance_wallet';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final accent = _parseColor(selectedColor);
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFFFBF1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),

                    // أيقونة + اسم
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final picked = await AppIconPickerDialog.show(
                              context,
                              initialIconName: selectedIcon,
                              initialColorHex: selectedColor,
                              title: 'اختيار أيقونة المحفظة',
                              name: nameController.text.isEmpty
                                  ? 'محفظة جديدة'
                                  : nameController.text,
                            );
                            if (picked == null) return;
                            setDialogState(() {
                              selectedIcon = picked.iconName;
                              selectedColor = picked.colorHex;
                            });
                          },
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.3),
                                  width: 2),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: AppIconPickerDialog.iconWidgetForName(
                                      selectedIcon,
                                      color: accent,
                                      size: 28),
                                ),
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.edit_rounded,
                                        size: 10, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                current == null
                                    ? 'محفظة جديدة'
                                    : 'تعديل المحفظة',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text('اضغط الأيقونة لتغيير الشكل واللون',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: accent.withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      autofocus: current == null,
                      decoration: const InputDecoration(
                          labelText: 'اسم المحفظة',
                          prefixIcon: Icon(Icons.label_outline_rounded)),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: balanceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'الرصيد الفعلي',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                        suffixText: 'جنيه',
                      ),
                    ),

                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final balance =
                            double.tryParse(balanceController.text.trim()) ?? 0;
                        if (name.isEmpty) return;
                        Navigator.of(context).pop();
                        if (current == null) {
                          await widget.cubit.addWallet(
                            name: name,
                            openingBalance: balance,
                            icon: selectedIcon,
                            iconColor: selectedColor,
                          );
                        } else {
                          await widget.cubit.updateWallet(
                            id: current.id,
                            name: name,
                            balance: balance,
                            icon: selectedIcon,
                            iconColor: selectedColor,
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: accent,
                      ),
                      child: Text(
                        current == null ? 'إضافة المحفظة' : 'حفظ التعديلات',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),

                    if (current != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await widget.cubit.deleteWallet(current.id);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFE53935)),
                          foregroundColor: const Color(0xFFE53935),
                        ),
                        child: const Text('حذف المحفظة',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openJarEditor({LinkedWalletEntity? current}) {
    final incomes = widget.cubit.state.budgetSetup.incomeSources;
    Navigator.of(context)
        .push<JarEditorResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: JarEditorScreen(
            current: current,
            incomeSources: incomes,
            idFactory: (prefix) =>
                '$prefix-${DateTime.now().millisecondsSinceEpoch}',
          ),
        ),
      ),
    )
        .then((result) async {
      if (result == null) {
        return;
      }
      if (result.deleteRequested && current != null) {
        if (current.id == 'linked-savings-default') {
          return;
        }
        await widget.cubit.deleteLinkedWallet(current.id);
        return;
      }
      final entity = result.entity;
      if (entity == null) {
        return;
      }
      if (current == null) {
        await widget.cubit.addLinkedWallet(entity);
      } else {
        await widget.cubit.updateLinkedWallet(entity);
      }
    });
  }

  /// المبالغ المحجوزة من محفظة معينة لكل حصالة — مبني على walletSources (label فقط)
  Map<String, double> _walletReservations(
      AppStateEntity state, String walletId) {
    final result = <String, double>{};
    for (final jar in state.budgetSetup.linkedWallets) {
      for (final src in jar.walletSources) {
        if (src.walletId == walletId && src.amount > 0) {
          result[jar.id] = src.amount;
        }
      }
    }
    return result;
  }

  /// توزيع الحصالة على المحافظ — مبني على walletSources
  Map<String, double> _jarDistribution(AppStateEntity state, String jarId) {
    final jar =
        state.budgetSetup.linkedWallets.where((j) => j.id == jarId).firstOrNull;
    if (jar == null) return {};
    return {for (final s in jar.walletSources) s.walletId: s.amount};
  }

  Map<String, double> _allocationDistribution(
      AppStateEntity state, String allocId) {
    final alloc =
        state.budgetSetup.allocations.where((a) => a.id == allocId).firstOrNull;
    if (alloc == null) return {};
    return alloc.walletBalances;
  }

  double _jarUnallocatedAmount(AppStateEntity state, dynamic entity) {
    if (entity is LinkedWalletEntity) {
      return entity.unlabeledAmount;
    } else if (entity is AllocationEntity) {
      final sum = entity.walletBalances.values.fold<double>(0, (s, v) => s + v);
      return (entity.balance - sum).clamp(0, double.infinity);
    }
    return 0;
  }

  double _walletReservedAmount(AppStateEntity state, String walletId) {
    return _walletReservations(state, walletId)
        .values
        .fold<double>(0, (sum, item) => sum + item);
  }

  bool _isVirtualJarTransaction(TransactionEntity transaction) {
    return transaction.transferType == 'jar-funding' ||
        transaction.transferType == 'jar-allocation' ||
        transaction.transferType == 'jar-allocation-cancel' ||
        transaction.transferType == 'jar-allocation-spend' ||
        transaction.transferType == 'allocation-to-jar' ||
        transaction.transferType == 'jar-to-allocation';
  }

  Widget _glassMetric({
    required String label,
    required String value,
    required Color accent,
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

  Widget _iconAction(
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

  Widget _sectionHeader(String title) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
    );
  }

  Color _parseColor(String hex) {
    final normalized = hex.replaceAll('#', '');
    final value = int.tryParse(normalized, radix: 16) ?? 0xFF165B47;
    return Color(0xFF000000 | value);
  }

  List<LinkedWalletEntity> _orderedJars(List<LinkedWalletEntity> jars) {
    final sorted = List<LinkedWalletEntity>.from(jars);
    sorted.sort((a, b) {
      if (a.id == 'linked-savings-default' &&
          b.id != 'linked-savings-default') {
        return -1;
      }
      if (b.id == 'linked-savings-default' &&
          a.id != 'linked-savings-default') {
        return 1;
      }
      return a.name.compareTo(b.name);
    });
    return sorted;
  }
}

enum _JarAdjustmentMode { allocate, cancel }

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.accent,
    required this.enabled,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? accent : const Color(0xFFBDB5A8);
    final bg = enabled
        ? accent.withValues(alpha: 0.10)
        : const Color(0xFFE8E0D6).withValues(alpha: 0.60);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: effectiveColor.withValues(alpha: 0.16)),
          ),
          child: Icon(icon, color: effectiveColor, size: 20),
        ),
      ),
    );
  }
}

// ── Wallets full-page list with reorder + style toggle ─────────────────────

class _WalletsListPage extends StatefulWidget {
  const _WalletsListPage({required this.cubit, this.onWalletTap});
  final AppCubit cubit;
  final void Function(WalletEntity wallet, bool showReservations)? onWalletTap;
  @override
  State<_WalletsListPage> createState() => _WalletsListPageState();
}

class _WalletsListPageState extends State<_WalletsListPage> {
  bool _reorderMode = false;

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.tryParse(normalized, radix: 16) ?? 0xFF165B47);
  }

  Map<String, double> _walletReservations(
      AppStateEntity state, String walletId) {
    final result = <String, double>{};
    for (final jar in state.budgetSetup.linkedWallets) {
      for (final src in jar.walletSources) {
        if (src.walletId == walletId && src.amount > 0) {
          result[jar.id] = src.amount;
        }
      }
    }
    return result;
  }

  double _walletReservedAmount(AppStateEntity state, String walletId) {
    return _walletReservations(state, walletId)
        .values
        .fold<double>(0, (sum, item) => sum + item);
  }

  Widget _buildCard(AppStateEntity state, WalletEntity wallet, int index) {
    final accent = _parseColor(wallet.iconColor ?? '#165b47');
    final isColored = wallet.isHighlighted;
    final reserved = _walletReservedAmount(state, wallet.id);
    final available = wallet.balance - reserved;

    final card = Container(
      key: ValueKey(wallet.id),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isColored ? accent : accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: accent.withValues(alpha: isColored ? 0.0 : 0.20),
            width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isColored ? 0.32 : 0.10),
            blurRadius: isColored ? 24 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isColored
                        ? Colors.white.withValues(alpha: 0.20)
                        : accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: AppIconPickerDialog.iconWidgetForName(
                      wallet.icon ?? 'account_balance_wallet',
                      color: isColored ? Colors.white : accent,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.name,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: isColored
                              ? Colors.white
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'متاح ${available.toStringAsFixed(2)} جنيه',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isColored
                              ? Colors.white.withValues(alpha: 0.80)
                              : accent.withValues(alpha: 0.60),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_reorderMode)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            widget.cubit.toggleWalletHighlight(wallet.id),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isColored
                                ? Colors.white.withValues(alpha: 0.22)
                                : accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isColored
                                ? Icons.invert_colors_off_rounded
                                : Icons.color_lens_rounded,
                            size: 18,
                            color: isColored ? Colors.white : accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ReorderableDragStartListener(
                        index: index,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isColored
                                ? Colors.white.withValues(alpha: 0.15)
                                : accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.drag_handle_rounded,
                            size: 20,
                            color: isColored ? Colors.white : accent,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isColored
                    ? Colors.white.withValues(alpha: 0.14)
                    : accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wallet.balance.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isColored ? Colors.white : accent,
                          ),
                        ),
                        Text(
                          'إجمالي الرصيد',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isColored
                                ? Colors.white.withValues(alpha: 0.70)
                                : accent.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (reserved > 0) ...[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onWalletTap?.call(wallet, true),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            reserved.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isColored
                                  ? Colors.white.withValues(alpha: 0.80)
                                  : accent.withValues(alpha: 0.70),
                            ),
                          ),
                          Text(
                            'فلوس محجوزة',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isColored
                                  ? Colors.white.withValues(alpha: 0.60)
                                  : accent.withValues(alpha: 0.50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return _reorderMode
        ? card
        : GestureDetector(
            onTap: () => widget.onWalletTap?.call(wallet, false),
            child: card,
          );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF1),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFFBF1),
          surfaceTintColor: Colors.transparent,
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _reorderMode
                ? const Text(
                    'اسحب لإعادة الترتيب · اضغط 🎨 للون',
                    key: ValueKey('reorder'),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF165B47)),
                  )
                : const Text('كل المحافظ',
                    key: ValueKey('title'),
                    style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _reorderMode ? Icons.check_circle_rounded : Icons.tune_rounded,
                color: _reorderMode ? const Color(0xFF165B47) : null,
              ),
              tooltip: _reorderMode ? 'تم' : 'ترتيب وتخصيص',
              onPressed: () => setState(() => _reorderMode = !_reorderMode),
            ),
          ],
        ),
        body: StreamBuilder<AppStateEntity>(
          stream: widget.cubit.stream,
          initialData: widget.cubit.state,
          builder: (ctx, snap) {
            final state = snap.data ?? widget.cubit.state;
            final wallets = state.wallets;

            if (_reorderMode) {
              return ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: wallets.length,
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  final reordered = List<WalletEntity>.from(wallets);
                  final item = reordered.removeAt(oldIndex);
                  reordered.insert(newIndex, item);
                  widget.cubit.reorderWallets(reordered);
                },
                itemBuilder: (ctx, i) => _buildCard(state, wallets[i], i),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: wallets.length,
              itemBuilder: (ctx, i) => _buildCard(state, wallets[i], i),
            );
          },
        ),
      ),
    );
  }
}

// ── Jars full-page list with reorder + style toggle ────────────────────────

class _JarsListPage extends StatefulWidget {
  const _JarsListPage({required this.cubit, this.onJarTap});
  final AppCubit cubit;
  final void Function(LinkedWalletEntity)? onJarTap;
  @override
  State<_JarsListPage> createState() => _JarsListPageState();
}

class _JarsListPageState extends State<_JarsListPage> {
  bool _reorderMode = false;

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.tryParse(normalized, radix: 16) ?? 0xFF0F766E);
  }

  Widget _buildCard(
      List<LinkedWalletEntity> allJars, LinkedWalletEntity jar, int index) {
    final accent = _parseColor(jar.iconColor);
    final isColored = jar.isHighlighted;
    final progressVal = jar.monthlyAmount > 0
        ? (jar.balance / jar.monthlyAmount).clamp(0.0, 1.0)
        : null;

    final card = Container(
      key: ValueKey(jar.id),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isColored ? accent : accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: accent.withValues(alpha: isColored ? 0.0 : 0.20),
            width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isColored ? 0.32 : 0.10),
            blurRadius: isColored ? 24 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isColored
                        ? Colors.white.withValues(alpha: 0.20)
                        : accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: AppIconPickerDialog.iconWidgetForName(
                      jar.icon,
                      color: isColored ? Colors.white : accent,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jar.name,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: isColored
                              ? Colors.white
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (jar.monthlyAmount > 0)
                        Text(
                          'الهدف الشهري: ${jar.monthlyAmount.toStringAsFixed(2)} جنيه',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isColored
                                ? Colors.white.withValues(alpha: 0.80)
                                : accent.withValues(alpha: 0.60),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_reorderMode)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => widget.cubit.toggleJarHighlight(jar.id),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isColored
                                ? Colors.white.withValues(alpha: 0.22)
                                : accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isColored
                                ? Icons.invert_colors_off_rounded
                                : Icons.color_lens_rounded,
                            size: 18,
                            color: isColored ? Colors.white : accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ReorderableDragStartListener(
                        index: index,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isColored
                                ? Colors.white.withValues(alpha: 0.15)
                                : accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.drag_handle_rounded,
                            size: 20,
                            color: isColored ? Colors.white : accent,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isColored
                    ? Colors.white.withValues(alpha: 0.14)
                    : accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jar.balance.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isColored ? Colors.white : accent,
                          ),
                        ),
                        Text(
                          'الرصيد الحالي',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isColored
                                ? Colors.white.withValues(alpha: 0.70)
                                : accent.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (progressVal != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progressVal,
                  minHeight: 6,
                  color:
                      isColored ? Colors.white.withValues(alpha: 0.80) : accent,
                  backgroundColor: isColored
                      ? Colors.white.withValues(alpha: 0.20)
                      : accent.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progressVal * 100).round()}٪ من الهدف الشهري',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isColored
                      ? Colors.white.withValues(alpha: 0.65)
                      : accent.withValues(alpha: 0.55),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return _reorderMode
        ? card
        : GestureDetector(
            onTap: () => widget.onJarTap?.call(jar),
            child: card,
          );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF1),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFFBF1),
          surfaceTintColor: Colors.transparent,
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _reorderMode
                ? const Text(
                    'اسحب لإعادة الترتيب · اضغط 🎨 للون',
                    key: ValueKey('reorder'),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F766E)),
                  )
                : const Text('كل الحصالات',
                    key: ValueKey('title'),
                    style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _reorderMode ? Icons.check_circle_rounded : Icons.tune_rounded,
                color: _reorderMode ? const Color(0xFF0F766E) : null,
              ),
              tooltip: _reorderMode ? 'تم' : 'ترتيب وتخصيص',
              onPressed: () => setState(() => _reorderMode = !_reorderMode),
            ),
          ],
        ),
        body: StreamBuilder<AppStateEntity>(
          stream: widget.cubit.stream,
          initialData: widget.cubit.state,
          builder: (ctx, snap) {
            final state = snap.data ?? widget.cubit.state;
            final jars = state.budgetSetup.linkedWallets;

            if (_reorderMode) {
              return ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: jars.length,
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  final reordered = List<LinkedWalletEntity>.from(jars);
                  final item = reordered.removeAt(oldIndex);
                  reordered.insert(newIndex, item);
                  widget.cubit.reorderJars(reordered);
                },
                itemBuilder: (ctx, i) => _buildCard(jars, jars[i], i),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: jars.length,
              itemBuilder: (ctx, i) => _buildCard(jars, jars[i], i),
            );
          },
        ),
      ),
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEDF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF72685A),
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4DCCF)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 34, color: Color(0xFF7A725F)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF72685A),
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletPickerTile extends StatelessWidget {
  const _WalletPickerTile({
    required this.label,
    required this.wallet,
    required this.onTap,
  });

  final String label;
  final WalletEntity wallet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Color(
      0xFF000000 |
          int.parse((wallet.iconColor ?? '#165b47').replaceFirst('#', ''),
              radix: 16),
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: AppIconPickerDialog.iconWidgetForName(
                  wallet.icon ?? 'account_balance_wallet',
                  color: accent,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: accent.withValues(alpha: 0.7),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    wallet.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'الرصيد',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.black38),
                ),
                Text(
                  wallet.balance.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_note_rounded,
                color: accent.withValues(alpha: 0.4), size: 20),
          ],
        ),
      ),
    );
  }
}

class _TransferItemTile extends StatelessWidget {
  const _TransferItemTile({
    required this.label,
    required this.title,
    required this.icon,
    required this.accent,
    this.amount,
    required this.onTap,
  });

  final String label;
  final String title;
  final String icon;
  final Color accent;
  final double? amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: AppIconPickerDialog.iconWidgetForName(
                  icon,
                  color: accent,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: accent.withValues(alpha: 0.7),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            if (amount != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'الرصيد الحالي',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.black38),
                  ),
                  Text(
                    amount!.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 8),
            Icon(Icons.edit_note_rounded,
                color: accent.withValues(alpha: 0.4), size: 20),
          ],
        ),
      ),
    );
  }
}
