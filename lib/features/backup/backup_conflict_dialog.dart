import 'package:flutter/material.dart';

enum BackupConflictChoice { overwrite, merge, cancel }

class BackupConflictDialog extends StatelessWidget {
  const BackupConflictDialog({
    super.key,
    required this.remoteTxCount,
    required this.localTxCount,
    required this.remoteUpdatedAt,
  });

  final int remoteTxCount;
  final int localTxCount;
  final DateTime? remoteUpdatedAt;

  static const _green = Color(0xFF2F6F5E);
  static const _orange = Color(0xFFC65D2E);
  static const _bg = Color(0xFFFFFBF1);

  static Future<BackupConflictChoice> show(
    BuildContext context, {
    required int remoteTxCount,
    required int localTxCount,
    required DateTime? remoteUpdatedAt,
  }) async {
    final result = await showDialog<BackupConflictChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackupConflictDialog(
        remoteTxCount: remoteTxCount,
        localTxCount: localTxCount,
        remoteUpdatedAt: remoteUpdatedAt,
      ),
    );
    return result ?? BackupConflictChoice.cancel;
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
                color: _orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: _orange, size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              'عندك نسخة محفوظة بالفعل',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1C3A32),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _orange.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _compareRow(
                    label: 'المحفوظة على السحابة',
                    value:
                        '$remoteTxCount معاملة · ${_formatDate(remoteUpdatedAt)}',
                    color: _green,
                  ),
                  const SizedBox(height: 8),
                  _compareRow(
                    label: 'الحالية على الجهاز',
                    value: '$localTxCount معاملة',
                    color: _orange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    Navigator.pop(context, BackupConflictChoice.merge),
                icon: const Icon(Icons.merge_rounded, size: 18),
                label: const Text(
                  'دمج البيانات',
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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(context, BackupConflictChoice.overwrite),
                icon:
                    Icon(Icons.cloud_upload_rounded, size: 18, color: _orange),
                label: Text(
                  'استبدال النسخة المحفوظة',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _orange,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: _orange.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, BackupConflictChoice.cancel),
              child: const Text(
                'إلغاء',
                style: TextStyle(
                  color: Color(0xFF5A7A70),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compareRow({
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C3A32),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
