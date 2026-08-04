import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// نوع خانة النسخة الاحتياطية على السحابة. النسخة اليدوية خانة واحدة ثابتة
/// لا تُستبدَل إلا بضغطة المستخدم الصريحة. النسخ التلقائي يدور بين خانتين
/// (`autoCloud0`/`autoCloud1`) للاحتفاظ بآخر نسختين فقط.
enum BackupSlot {
  manualCloud('manual_cloud'),
  autoCloud0('auto_cloud_0'),
  autoCloud1('auto_cloud_1');

  const BackupSlot(this.id);
  final String id;
}

class BackupService {
  static const _col = 'backups';
  static const _chunkSize = 200000;

  static DocumentReference _root(String email) =>
      FirebaseFirestore.instance.collection(_col).doc(email);

  /// جذر خانة نسخة احتياطية محدَّدة تحت مستند المستخدم.
  static DocumentReference _slotRoot(String email, BackupSlot slot) =>
      _root(email).collection('slots').doc(slot.id);

  static String _chunkId(int index) =>
      'part_${index.toString().padLeft(4, '0')}';

  static List<String> _splitBackup(String value) {
    final chunks = <String>[];
    for (var start = 0; start < value.length; start += _chunkSize) {
      final end = start + _chunkSize;
      chunks
          .add(value.substring(start, end > value.length ? value.length : end));
    }
    return chunks.isEmpty ? <String>[''] : chunks;
  }

  /// بيانات خانة النسخة (`meta/info`). ترجع null لو الخانة غير موجودة بعد.
  static Future<Map<String, dynamic>?> fetchSlotMetadata(
    String email,
    BackupSlot slot,
  ) async {
    try {
      final doc =
          await _slotRoot(email, slot).collection('meta').doc('info').get();
      if (!doc.exists || doc.data() == null) return null;
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> fetchSlotData(String email, BackupSlot slot) async {
    try {
      final doc = await _slotRoot(email, slot)
          .collection('data')
          .doc('backup')
          .get();
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;

      final chunkCount = data['chunkCount'];
      if (chunkCount is! int || chunkCount <= 0) return null;

      final chunks = await _slotRoot(email, slot)
          .collection('data')
          .doc('backup')
          .collection('chunks')
          .get();
      if (chunks.docs.length < chunkCount) return null;

      final sortedDocs = [...chunks.docs]..sort((a, b) => a.id.compareTo(b.id));
      final buffer = StringBuffer();
      for (final chunkDoc in sortedDocs.take(chunkCount)) {
        final value = chunkDoc.data()['value'];
        if (value is! String) return null;
        buffer.write(value);
      }
      return buffer.toString();
    } catch (_) {
      return null;
    }
  }

  /// اختيار الخانة التلقائية الأحدث بين الاثنتين (للاسترجاع) بمقارنة
  /// `updatedAt`. ترجع null لو لا توجد أي خانة تلقائية بعد.
  static Future<BackupSlot?> latestAutoSlot(String email) async {
    final meta0 = await fetchSlotMetadata(email, BackupSlot.autoCloud0);
    final meta1 = await fetchSlotMetadata(email, BackupSlot.autoCloud1);
    final t0 = meta0?['updatedAt'] is Timestamp
        ? (meta0!['updatedAt'] as Timestamp).toDate()
        : null;
    final t1 = meta1?['updatedAt'] is Timestamp
        ? (meta1!['updatedAt'] as Timestamp).toDate()
        : null;
    if (t0 == null && t1 == null) return null;
    if (t0 == null) return BackupSlot.autoCloud1;
    if (t1 == null) return BackupSlot.autoCloud0;
    return t1.isAfter(t0) ? BackupSlot.autoCloud1 : BackupSlot.autoCloud0;
  }

  /// اختيار الخانة التلقائية الأقدم (أو الفارغة) — هي التي يُكتب فوقها في
  /// الرفعة القادمة، بحيث تبقى دائمًا آخر نسختين فقط.
  static Future<BackupSlot> oldestAutoSlot(String email) async {
    final newest = await latestAutoSlot(email);
    if (newest == null) return BackupSlot.autoCloud0;
    return newest == BackupSlot.autoCloud0
        ? BackupSlot.autoCloud1
        : BackupSlot.autoCloud0;
  }

  /// يرفع نسخة كاملة إلى خانة محدَّدة، بترتيب آمن: يكتب كل الأجزاء
  /// الجديدة أولاً (إضافي بحت، لا يمسّ القديم)، ثم يُحدِّث المؤشرات
  /// (meta/info و data/backup) لتشير للنسخة الجديدة الكاملة، **وبعد ذلك
  /// فقط** يحذف الأجزاء القديمة الزائدة. لو فشلت العملية أو انقطع
  /// الاتصال في أي لحظة قبل اكتمال التحديث، تظل المؤشرات تشير للنسخة
  /// القديمة الكاملة الصالحة — لا يمكن أبدًا أن تُقرأ خانة بنسخة ناقصة.
  static Future<void> uploadToSlot({
    required String email,
    required String displayName,
    required BackupSlot slot,
    required String jsonData,
    required int txCount,
    required int walletCount,
    required int recurringCount,
  }) async {
    final ref = _slotRoot(email, slot);
    final dataRef = ref.collection('data').doc('backup');
    final chunksRef = dataRef.collection('chunks');
    final chunks = _splitBackup(jsonData);

    var batch = FirebaseFirestore.instance.batch();
    var operationCount = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (!force && operationCount < 450) return;
      if (operationCount == 0) return;
      await batch.commit();
      batch = FirebaseFirestore.instance.batch();
      operationCount = 0;
    }

    void set(DocumentReference reference, Map<String, dynamic> data) {
      batch.set(reference, data);
      operationCount++;
    }

    void delete(DocumentReference reference) {
      batch.delete(reference);
      operationCount++;
    }

    // 1) اكتب كل الأجزاء الجديدة أولاً — إضافي بحت، لا يحذف أو يستبدل أي
    //    شيء قديم بعد. لو فشلت العملية هنا، الخانة القديمة لسه سليمة تمامًا.
    for (var i = 0; i < chunks.length; i++) {
      set(chunksRef.doc(_chunkId(i)), {
        'index': i,
        'value': chunks[i],
      });
      await commitIfNeeded();
    }
    await commitIfNeeded(force: true);

    // 2) الآن بعد التأكد من كتابة كل الأجزاء الجديدة كاملةً، حدِّث
    //    المؤشرات لتشير للنسخة الجديدة — هذه هي لحظة "نجاح الرفع" الفعلية.
    set(ref.collection('meta').doc('info'), {
      'email': email,
      'name': displayName,
      'slot': slot.id,
      'updatedAt': FieldValue.serverTimestamp(),
      'isEmpty': false,
      'storageFormat': 'chunked-v2',
      'chunkCount': chunks.length,
      'byteSize': utf8.encode(jsonData).length,
      'recordsCount': {
        'transactions': txCount,
        'wallets': walletCount,
        'recurringTransactions': recurringCount,
      },
      'appVersion': '1.0.0',
    });
    set(dataRef, {
      'storageFormat': 'chunked-v2',
      'chunkCount': chunks.length,
      'byteSize': utf8.encode(jsonData).length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await commitIfNeeded(force: true);

    // 3) الرفع نجح والمؤشرات تشير للنسخة الجديدة الكاملة — الآن فقط يُسمح
    //    بحذف الأجزاء القديمة الزائدة عن الحاجة (تخص نسخة أقدم/أكبر حجمًا).
    final newChunkIds = {
      for (var i = 0; i < chunks.length; i++) _chunkId(i),
    };
    final oldChunks = await chunksRef.get();
    for (final oldChunk in oldChunks.docs.where(
      (chunk) => !newChunkIds.contains(chunk.id),
    )) {
      delete(oldChunk.reference);
      await commitIfNeeded();
    }
    await commitIfNeeded(force: true);
  }

  // ===========================================================================
  // توافق عكسي: النسخة القديمة (قبل V2) كانت تُخزَّن في مستند جذري واحد
  // بلا مفهوم "خانات" على الإطلاق: backups/{email}/meta/info و
  // backups/{email}/data/backup. هذه الدوال تبقى فقط لقراءة (لا كتابة)
  // أي نسخة قديمة موجودة من قبل الترقية لـ V2، حتى يظل استرجاعها ممكنًا.
  // لا يُكتب لهذا المسار بعد الآن إطلاقًا.
  // ===========================================================================

  static Future<Map<String, dynamic>?> fetchLegacyMetadata(
    String email,
  ) async {
    try {
      final doc = await _root(email).collection('meta').doc('info').get();
      if (!doc.exists || doc.data() == null) return null;
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> fetchLegacyData(String email) async {
    try {
      final doc = await _root(email).collection('data').doc('backup').get();
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;

      final legacyBackup = data['backup'];
      if (legacyBackup is String && legacyBackup.isNotEmpty) {
        return legacyBackup;
      }

      final chunkCount = data['chunkCount'];
      if (chunkCount is! int || chunkCount <= 0) return null;

      final chunks = await _root(email)
          .collection('data')
          .doc('backup')
          .collection('chunks')
          .get();
      if (chunks.docs.length < chunkCount) return null;

      final sortedDocs = [...chunks.docs]..sort((a, b) => a.id.compareTo(b.id));
      final buffer = StringBuffer();
      for (final chunkDoc in sortedDocs.take(chunkCount)) {
        final value = chunkDoc.data()['value'];
        if (value is! String) return null;
        buffer.write(value);
      }
      return buffer.toString();
    } catch (_) {
      return null;
    }
  }
}
