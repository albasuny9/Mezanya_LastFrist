import 'package:flutter/material.dart';

class RestorePromptDialog extends StatelessWidget {
  const RestorePromptDialog({
    super.key,
    required this.txCount,
    required this.walletCount,
    required this.updatedAt,
  });

  final int txCount;
  final int walletCount;
  final DateTime? updatedAt;

  static const _green = Color(0xFF2F6F5E);
  static const _bg = Color(0xFFFFFBF1);

  static Future<bool> show(
    BuildContext context, {
    required int txCount,
    required int walletCount,
    required DateTime? updatedAt,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RestorePromptDialog(
        txCount: txCount,
        walletCount: walletCount,
        updatedAt: updatedAt,
      ),
    );
    return result ?? false;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child:
                  const Icon(Icons.cloud_done_rounded, color: _green, size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              'عندك نسخة محفوظة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1C3A32),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _row(Icons.receipt_long_rounded, '$txCount معاملة'),
                  const SizedBox(height: 6),
                  _row(Icons.account_balance_wallet_rounded,
                      '$walletCount محفظة'),
                  const SizedBox(height: 6),
                  _row(Icons.schedule_rounded,
                      'آخر تحديث: ${_formatDate(updatedAt)}'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'هل تريد تحميل بياناتك المحفوظة؟',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5A7A70),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: _green.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'تجاهل',
                      style: TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text(
                      'استعادة الآن',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
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

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _green),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C3A32),
          ),
        ),
      ],
    );
  }
}
