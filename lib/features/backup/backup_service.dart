import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class BackupService {
  static const _col = 'backups';
  static const _chunkSize = 200000;

  static DocumentReference _root(String email) =>
      FirebaseFirestore.instance.collection(_col).doc(email);

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

  static Future<Map<String, dynamic>?> fetchMetadata(String email) async {
    try {
      final doc = await _root(email).collection('meta').doc('info').get();
      if (!doc.exists || doc.data() == null) return null;
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> fetchData(String email) async {
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

  static Future<void> upload({
    required String email,
    required String displayName,
    required String jsonData,
    required int txCount,
    required int walletCount,
    required int recurringCount,
  }) async {
    final ref = _root(email);
    final dataRef = ref.collection('data').doc('backup');
    final chunksRef = dataRef.collection('chunks');
    final chunks = _splitBackup(jsonData);

    var batch = FirebaseFirestore.instance.batch();
    var operationCount = 0;

    Future<void> commitIfNeeded() async {
      if (operationCount < 450) return;
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

    set(ref.collection('meta').doc('info'), {
      'email': email,
      'name': displayName,
      'updatedAt': FieldValue.serverTimestamp(),
      'isEmpty': false,
      'storageFormat': 'chunked-v1',
      'chunkCount': chunks.length,
      'byteSize': utf8.encode(jsonData).length,
      'recordsCount': {
        'transactions': txCount,
        'wallets': walletCount,
        'recurringTransactions': recurringCount,
      },
      'appVersion': '1.0.0',
    });
    await commitIfNeeded();

    set(dataRef, {
      'storageFormat': 'chunked-v1',
      'chunkCount': chunks.length,
      'byteSize': utf8.encode(jsonData).length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await commitIfNeeded();

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

    for (var i = 0; i < chunks.length; i++) {
      set(chunksRef.doc(_chunkId(i)), {
        'index': i,
        'value': chunks[i],
      });
      await commitIfNeeded();
    }

    if (operationCount > 0) {
      await batch.commit();
    }
  }
}
