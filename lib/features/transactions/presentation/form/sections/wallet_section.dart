import 'package:flutter/material.dart';

import '../_shared/row_card.dart';

/// Wallet selection row.
class WalletSection extends StatelessWidget {
  const WalletSection({
    super.key,
    required this.walletName,
    required this.onOpenPicker,
  });

  final String walletName;
  final VoidCallback onOpenPicker;

  @override
  Widget build(BuildContext context) {
    return FormRowCard(
      label: 'المحفظة',
      value: walletName,
      icon: Icons.account_balance_wallet_outlined,
      onTap: onOpenPicker,
    );
  }
}
