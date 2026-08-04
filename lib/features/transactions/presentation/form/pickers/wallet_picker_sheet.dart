import 'package:flutter/material.dart';

import '../../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../../wallets/domain/entities/wallet_entity.dart';
import '../_shared/sheet_section_label.dart';

/// Shows the wallet picker bottom sheet.
/// Calls [onSelected] with the chosen wallet id (or 'no-wallet').
void showWalletPickerSheet(
  BuildContext context, {
  required List<WalletEntity> wallets,
  required String currentWalletId,
  required void Function(String walletId) onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFFFFFBF1),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetCtx) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.88,
      expand: false,
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const Text(
            'اختر المحفظة',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 14),

          // No-wallet option
          _WalletTile(
            id: 'no-wallet',
            name: 'بدون محفظة (افتراضي)',
            subtitle: 'تُسجَّل المعاملة دون التأثير على أي رصيد فعلي',
            icon: Icons.money_off_csred_rounded,
            accentHex: '#165b47',
            balance: null,
            isSelected: currentWalletId == 'no-wallet',
            onTap: () {
              onSelected('no-wallet');
              Navigator.pop(sheetCtx);
            },
          ),

          if (wallets.isNotEmpty) ...[
            const SheetSectionLabel(label: 'المحافظ'),
            const SizedBox(height: 10),
          ],

          ...wallets.map((wallet) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WalletTile(
                  id: wallet.id,
                  name: wallet.name,
                  subtitle:
                      '${wallet.balance.toStringAsFixed(2)} رصيد',
                  iconName: wallet.icon,
                  accentHex: wallet.iconColor ?? '#165b47',
                  balance: wallet.balance,
                  isSelected: currentWalletId == wallet.id,
                  onTap: () {
                    onSelected(wallet.id);
                    Navigator.pop(sheetCtx);
                  },
                ),
              )),
        ],
      ),
    ),
  );
}

// ── Internal tile ──────────────────────────────────────────────────────────
class _WalletTile extends StatelessWidget {
  const _WalletTile({
    required this.id,
    required this.name,
    required this.subtitle,
    this.icon,
    this.iconName,
    required this.accentHex,
    required this.balance,
    required this.isSelected,
    required this.onTap,
  });

  final String id;
  final String name;
  final String subtitle;
  final IconData? icon;
  final String? iconName;
  final String accentHex;
  final double? balance;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _parseColor(accentHex);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color:
              isSelected ? accent.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.55)
                : accent.withValues(alpha: 0.18),
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, color: accent, size: 26)
                    : AppIconPickerDialog.iconWidgetForName(
                        iconName ??
                            'account_balance_wallet',
                        color: accent,
                        size: 26,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? accent : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accent.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: accent, size: 24),
          ],
        ),
      ),
    );
  }

  static Color _parseColor(String hex) {
    final v = int.tryParse(
            hex.replaceFirst('#', ''), radix: 16) ??
        0x165b47;
    return Color(0xFF000000 | v);
  }
}
