import 'package:cloud_firestore/cloud_firestore.dart';

class BackupService {
  static const _col = 'backups';

  static DocumentReference _root(String email) =>
      FirebaseFirestore.instance.collection(_col).doc(email);

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
      return doc.data()!['backup'] as String?;
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
    final batch = FirebaseFirestore.instance.batch();

    batch.set(ref.collection('meta').doc('info'), {
      'email': email,
      'name': displayName,
      'updatedAt': FieldValue.serverTimestamp(),
      'isEmpty': false,
      'recordsCount': {
        'transactions': txCount,
        'wallets': walletCount,
        'recurringTransactions': recurringCount,
      },
      'appVersion': '1.0.0',
    });

    batch.set(ref.collection('data').doc('backup'), {
      'backup': jsonData,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
