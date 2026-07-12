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

/// نوع الرفعة: تلقائي (يدور بين خانتين، لا يطلب تأكيدًا) أو يدوي (خانة
/// واحدة ثابتة، لا تُستبدَل إلا بضغطة المستخدم الصريحة). Backup V2 —
/// الاثنان مستقلان تمامًا ولا يكتب أحدهما فوق الآخر أبدًا.
enum BackupKind { manual, auto }

/// دالة اختيارية لعرض حوار التعارض على المستخدم (تُستخدَم في المسار
/// التفاعلي فقط). لو null، يعني تشغيل غير تفاعلي (تلقائي) — أي تعارض
/// حقيقي يُؤجَّل الرفع بدلاً من عرض واجهة أو الكتابة فوق البيانات.
typedef ConflictResolver = Future<BackupConflictChoice> Function({
  required int remoteTxCount,
  required int localTxCount,
  required DateTime? remoteUpdatedAt,
});

/// خط أنابيب رفع النسخ الاحتياطية الموحَّد — المسار الوحيد المسموح به لأي
/// كود في المشروع يرفع نسخة احتياطية على Firestore، تلقائية كانت أو
/// يدوية. يغطي مراحل إلزامية لكل استدعاء بلا استثناء: تحقق (Validation)
/// → كشف تعارض (Conflict Detection) → رفع لخانة الرفع المناسبة.
///
/// ADR-0003: `docs/architecture/adr/0003-backup-versioning-overwrite-protection.md`
class BackupUploadPipeline {
  BackupUploadPipeline._();

  static const String _lastAutoSyncPrefsKey = 'last_auto_cloud_backup_at';
  static const String _lastManualSyncPrefsKey = 'last_manual_cloud_backup_at';

  /// نقطة الدخول الوحيدة لأي رفع نسخة احتياطية سحابية. `kind` يحدد الخانة
  /// المستهدفة والمسار (تلقائي يدور بين خانتين، يدوي خانة ثابتة). الرفع
  /// اليدوي تفاعلي (`resolveConflict` غير null)، التلقائي غير تفاعلي.
  static Future<BackupUploadResult> run({
    required String email,
    required String displayName,
    required AppStateEntity localState,
    required String Function() exportJson,
    required BackupKind kind,
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
    final syncKey =
        kind == BackupKind.manual ? _lastManualSyncPrefsKey : _lastAutoSyncPrefsKey;
    final lastKnownSyncStr = prefs.getString(syncKey);
    final lastKnownSync =
        lastKnownSyncStr != null ? DateTime.tryParse(lastKnownSyncStr) : null;

    // تحديد خانة القراءة (لفحص التعارض) وخانة الكتابة (قد تختلفان في
    // الوضع التلقائي: نقرأ الأحدث بين الخانتين، ونكتب في الأقدم منهما،
    // بحيث تبقى دائمًا آخر نسختين فقط).
    BackupSlot writeSlot;
    BackupSlot? readSlot;
    if (kind == BackupKind.manual) {
      writeSlot = BackupSlot.manualCloud;
      readSlot = BackupSlot.manualCloud;
    } else {
      readSlot = await BackupService.latestAutoSlot(email);
      writeSlot = await BackupService.oldestAutoSlot(email);
    }

    Map<String, dynamic>? meta;
    try {
      meta = readSlot != null
          ? await BackupService.fetchSlotMetadata(email, readSlot)
          : null;
    } catch (_) {
      meta = null; // تعذّر الوصول للسحابة — يُعامَل كأنه أول رفع (لا تعارض)
    }

    final localTxCount = localState.transactions.length;

    if (meta != null) {
      final remoteTxCount =
          (meta['recordsCount']?['transactions'] as int?) ?? 0;
      final remoteWalletCount = (meta['recordsCount']?['wallets'] as int?) ?? 0;
      final remoteRecurringCount =
          (meta['recordsCount']?['recurringTransactions'] as int?) ?? 0;
      final remoteUpdatedAt = meta['updatedAt'] is Timestamp
          ? (meta['updatedAt'] as Timestamp).toDate()
          : null;

      // المرحلة 2: رفض الرفعات الخطيرة — قواعد حتمية فقط، بدون أي نسبة
      // مئوية أو عتبة تقديرية. كل قاعدة تمنع محو فئة بيانات كانت موجودة
      // بالكامل على السحابة بينما هي فارغة تمامًا محليًا.
      if (remoteTxCount > 0 && localTxCount == 0) {
        return BackupUploadResult(
          BackupUploadStatus.rejectedShrink,
          'تم رفض الرفع: النسخة المحلية بدون أي معاملات بينما النسخة '
          'السحابية تحتوي $remoteTxCount معاملة. راجع النسخة يدويًا قبل '
          'المتابعة.',
        );
      }
      if (remoteWalletCount > 0 && localState.wallets.isEmpty) {
        return BackupUploadResult(
          BackupUploadStatus.rejectedShrink,
          'تم رفض الرفع: النسخة المحلية بدون أي محافظ بينما النسخة '
          'السحابية تحتوي $remoteWalletCount محفظة. راجع النسخة يدويًا '
          'قبل المتابعة.',
        );
      }
      if (remoteRecurringCount > 0 && localState.recurringTransactions.isEmpty) {
        return BackupUploadResult(
          BackupUploadStatus.rejectedShrink,
          'تم رفض الرفع: النسخة المحلية بدون أي معاملات متكررة بينما '
          'النسخة السحابية تحتوي $remoteRecurringCount. راجع النسخة '
          'يدويًا قبل المتابعة.',
        );
      }

      // المرحلة 3: كشف التعارض — تعارض حقيقي فقط لو النسخة البعيدة اتحدّثت
      // من مصدر آخر بعد آخر مزامنة معروفة لنا محليًا لنفس نوع الرفعة
      // (تلقائي/يدوي كل واحد له تتبّعه الخاص، مستقلان تمامًا).
      final remoteWrittenByOthers = remoteUpdatedAt != null &&
          (lastKnownSync == null || remoteUpdatedAt.isAfter(lastKnownSync));

      if (remoteWrittenByOthers) {
        if (resolveConflict == null) {
          // مسار غير تفاعلي (تلقائي): لا نعرض واجهة ولا نكتب فوق بيانات
          // قد تكون أحدث من جهاز آخر — نؤجّل الرفع فقط.
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
          final remoteJson = readSlot != null
              ? await BackupService.fetchSlotData(email, readSlot)
              : null;
          if (remoteJson != null && onMerge != null) {
            await onMerge(remoteJson);
          }
        }
        // overwrite أو merge مكتمل → يكمل للرفع تحت.
      }
    }

    // المرحلة 4: الرفع الفعلي إلى الخانة المستهدفة (منطقي واحد فقط،
    // BackupService.uploadToSlot، تلقائي أو يدوي حسب `writeSlot`).
    try {
      await BackupService.uploadToSlot(
        email: email,
        displayName: displayName,
        slot: writeSlot,
        jsonData: exportJson(),
        txCount: localTxCount,
        walletCount: localState.wallets.length,
        recurringCount: localState.recurringTransactions.length,
      );
    } catch (e) {
      return BackupUploadResult(BackupUploadStatus.error, e.toString());
    }

    // نخزّن توقيت السيرفر نفسه (لا ساعة الجهاز) كمرجع للمقارنات القادمة.
    // سبب جوهري: كل عمليات كشف التعارض تقارن هذا المرجع بـ `updatedAt`
    // القادم من Firestore (توقيت سيرفر). لو خُزِّن بدلاً منه `DateTime.now()`
    // من ساعة الجهاز، أي فرق توقيت (clock skew) بين الجهاز والسيرفر —
    // حتى لو ثوانٍ قليلة — يجعل كل رفعة تلقائية لاحقة تظن خطأً أن السحابة
    // تحدّثت من مصدر آخر، فتُؤجَّل للأبد دون تحديث `syncKey` مطلقًا (هذا
    // كان يفسّر بالضبط بقاء "آخر نسخة تلقائية" عالقة عند وقت أول رفعة
    // ناجحة فقط). قراءة السيرفر مرة إضافية هنا تضمن أن طرفي أي مقارنة
    // مستقبلية دائمًا من نفس مصدر الساعة.
    DateTime syncTimestamp;
    try {
      final freshMeta = await BackupService.fetchSlotMetadata(email, writeSlot);
      final serverUpdatedAt = freshMeta?['updatedAt'];
      syncTimestamp = serverUpdatedAt is Timestamp
          ? serverUpdatedAt.toDate()
          : DateTime.now();
    } catch (_) {
      syncTimestamp = DateTime.now();
    }

    await prefs.setString(syncKey, syncTimestamp.toIso8601String());

    return const BackupUploadResult(BackupUploadStatus.uploaded);
  }
}
