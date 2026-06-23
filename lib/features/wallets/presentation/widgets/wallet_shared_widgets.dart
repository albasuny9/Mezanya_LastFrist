import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';

// Widget classes extracted from wallets_screen.dart (Phase 1 refactor)
// These are pure presentational widgets with no dependency on screen state.

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
            if (!_reorderMode) ...[
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded),
                tooltip: 'تحويل بين المحافظ',
                onPressed: () {
                  final wallets = widget.cubit.state.wallets;
                  if (wallets.length < 2) return;
                  Navigator.pop(context);
                  // نرجع للشاشة الرئيسية ونفتح التحويل من هناك
                },
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'إضافة محفظة',
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
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
            // شريط التقدم أُزيل - الحصالة مش مثل المخصص
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
