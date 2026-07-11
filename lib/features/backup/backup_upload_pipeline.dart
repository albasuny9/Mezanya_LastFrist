import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state/domain/entities/app_state_entity.dart';
import 'backup_conflict_dialog.dart';
import 'backup_service.dart';

/// نتيجة تشغيل [BackupUploadPipeline.run].
enum BackupUploadStatus {
  uploaded,
  rejectedEmpty,
  rejectedShrink,
  deferredConflict,
  cancelled,
  error,
}

class BackupUploadResult {
  final BackupUploadStatus status;
  final String? message;
  const BackupUploadResult(this.status, [this.message]);

  bool get isSuccess => status == BackupUploadStatus.uploaded;
}

/// دالة اختيارية لعرض حوار التعارض على المستخدم (تُستخدَم في المسار
/// التفاعلي فقط). لو null، يعني تشغيل غير تفاعلي (تلقائي/صامت) — أي
/// تعارض حقيقي يُؤجَّل الرفع بدلاً من عرض واجهة أو الكتابة فوق البيانات.
typedef ConflictResolver = Future<BackupConflictChoice> Function({
  required int remoteTxCount,
  required int localTxCount,
  required DateTime? remoteUpdatedAt,
});

/// خط أنابيب رفع النسخ الاحتياطية الموحَّد — المسار الوحيد المسموح به لأي
/// كود في المشروع يرفع نسخة احتياطية على Firestore. يغطي 3 مراحل إلزامية
/// لكل استدعاء بلا استثناء: تحقق (Validation) → كشف تعارض (Conflict
/// Detection) → رفع.
///
/// ADR-0003: `docs/architecture/adr/0003-backup-versioning-overwrite-protection.md`
class BackupUploadPipeline {
  BackupUploadPipeline._();

  /// أقصى نسبة انخفاض مسموح بها في عدد المعاملات المحلية مقارنة بالنسخة
  /// البعيدة قبل اعتبار الرفع خطيرًا ورفضه تلقائيًا.
  ///
  /// ⚠️ قيمة مبدئية محافظة (50%) — **تحتاج تأكيد محمد صراحة**، ليست قرارًا
  /// نهائيًا. لا يوجد معيار "صحيح" موضوعي لهذه النسبة؛ اختيرت كبداية آمنة.
  static const double maxAllowedShrinkRatio = 0.5;

  /// الحد الأدنى لعدد معاملات النسخة البعيدة قبل تفعيل حارس الانخفاض
  /// الخطير — لتجنّب رفض رفعات مستخدمين جدد لهم نسخة بعيدة صغيرة أصلاً
  /// (مثال: نسخة بعيدة بمعاملة واحدة ومحلية بدون معاملات لسبب مشروع).
  static const int minRemoteTxToGuard = 5;

  static const String _lastSyncPrefsKey = 'last_cloud_backup_at';

  /// نقطة الدخول الوحيدة لأي رفع نسخة احتياطية. تُستخدَم من الرفع اليدوي
  /// (تفاعلي، `resolveConflict` غير null) والرفع التلقائي/الصامت (غير
  /// تفاعلي، `resolveConflict` = null).
  static Future<BackupUploadResult> run({
    required String email,
    required String displayName,
    required AppStateEntity localState,
    required String Function() exportJson,
    Future<void> Function(String remoteJson)? onMerge,
    ConflictResolver? resolveConflict,
  }) async {
    // المرحلة 1: التحقق (Validation) — قبل أي اتصال بالشبكة.
    if (localState.isEmpty) {
      return const BackupUploadResult(
        BackupUploadStatus.rejectedEmpty,
        'تم رفض الرفع: لا توجد بيانات محلية.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final lastKnownSyncStr = prefs.getString(_lastSyncPrefsKey);
    final lastKnownSync =
        lastKnownSyncStr != null ? DateTime.tryParse(lastKnownSyncStr) : null;

    Map<String, dynamic>? meta;
    try {
      meta = await BackupService.fetchMetadata(email);
    } catch (_) {
      meta = null; // تعذّر الوصول للسحابة — يُعامَل كأنه أول رفع (لا تعارض)
    }

    final localTxCount = localState.transactions.length;

    if (meta != null) {
      final remoteTxCount =
          (meta['recordsCount']?['transactions'] as int?) ?? 0;
      final remoteUpdatedAt = meta['updatedAt'] is Timestamp
          ? (meta['updatedAt'] as Timestamp).toDate()
          : null;

      // المرحلة 2: رفض الرفعات الخطيرة (انخفاض حاد في حجم البيانات).
      if (remoteTxCount >= minRemoteTxToGuard &&
          localTxCount < remoteTxCount * maxAllowedShrinkRatio) {
        return BackupUploadResult(
          BackupUploadStatus.rejectedShrink,
          'تم رفض الرفع: البيانات المحلية ($localTxCount معاملة) أقل بكثير '
          'من النسخة السحابية ($remoteTxCount معاملة). قد يشير هذا لفقدان '
          'بيانات محلي — راجع النسخة يدويًا قبل المتابعة.',
        );
      }

      // المرحلة 3: كشف التعارض — تعارض حقيقي فقط لو النسخة البعيدة اتحدّثت
      // من مصدر آخر بعد آخر مزامنة معروفة لنا محليًا. مقارنة "فيه نسخة
      // بعيدة أصلاً" كانت ستوقف الرفع التلقائي نهائيًا من أول استخدام.
      final remoteWrittenByOthers = remoteUpdatedAt != null &&
          (lastKnownSync == null || remoteUpdatedAt.isAfter(lastKnownSync));

      if (remoteWrittenByOthers) {
        if (resolveConflict == null) {
          // مسار غير تفاعلي (تلقائي/صامت): لا نعرض واجهة ولا نكتب فوق
          // بيانات قد تكون أحدث من جهاز آخر — نؤجّل الرفع فقط.
          return const BackupUploadResult(
            BackupUploadStatus.deferredConflict,
            'تم تأجيل الرفع التلقائي: يوجد تحديث من جهاز/جلسة أخرى يحتاج '
            'مراجعة يدوية من صفحة النسخ الاحتياطي.',
          );
        }

        final choice = await resolveConflict(
          remoteTxCount: remoteTxCount,
          localTxCount: localTxCount,
          remoteUpdatedAt: remoteUpdatedAt,
        );

        if (choice == BackupConflictChoice.cancel) {
          return const BackupUploadResult(BackupUploadStatus.cancelled);
        }

        if (choice == BackupConflictChoice.merge) {
          final remoteJson = await BackupService.fetchData(email);
          if (remoteJson != null && onMerge != null) {
            await onMerge(remoteJson);
          }
        }
        // overwrite أو merge مكتمل → يكمل للرفع تحت.
      }
    }

    // المرحلة 4: الرفع الفعلي (مسار واحد فقط، BackupService.upload).
    try {
      await BackupService.upload(
        email: email,
        displayName: displayName,
        jsonData: exportJson(),
        txCount: localTxCount,
        walletCount: localState.wallets.length,
        recurringCount: localState.recurringTransactions.length,
      );
    } catch (e) {
      return BackupUploadResult(BackupUploadStatus.error, e.toString());
    }

    await prefs.setString(
      _lastSyncPrefsKey,
      DateTime.now().toIso8601String(),
    );

    return const BackupUploadResult(BackupUploadStatus.uploaded);
  }
}
