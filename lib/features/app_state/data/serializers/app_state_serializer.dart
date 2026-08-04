import 'dart:convert';

import '../../../logs/domain/entities/log_entry_entity.dart';
import '../../domain/entities/app_state_entity.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Phase 6.1 من خطة إعادة تصميم طبقة الـ Persistence.
///
/// [AppStateSerializer] مسؤولة حصريًا عن التحويل بين [AppStateEntity]/
/// [LogEntryEntity] وسترنج JSON — **مفيش أي حاجة تانية**. كل الدوال هنا
/// pure functions: بتاخد قيمة وترجع قيمة، بلا أي أثر جانبي، بلا أي معرفة
/// بـ `SharedPreferences`، بلا timing، بلا diagnostics، بلا migration،
/// بلا validation.
///
/// دوال الـ deserialize ممكن تعمل throw (لو الـ JSON معطوب أو الصيغة غلط)
/// — ده سلوك متعمَّد ومطابق تمامًا لما كان يحصل قبل الاستخراج (كان الكود
/// القديم بيعمل `jsonDecode`/`fromMap` مباشرة جوه try/catch في
/// الـ Repository؛ دلوقتي نفس الاستدعاءات بتحصل هنا، والـ try/catch
/// **لسه في الـ Repository زي ما هو بالحرف** — الاستخراج ده منقلش مكان
/// معالجة الأخطاء، نقل بس مكان التحويل نفسه).
/// ═══════════════════════════════════════════════════════════════════════
class AppStateSerializer {
  const AppStateSerializer._();

  /// يحوّل [AppStateEntity] (بدون logs) لسترنج JSON — نفس
  /// `jsonEncode(state.toMap(includeLogs: false))` اللي كانت جوه
  /// `_writeCore` بالحرف.
  static String serializeCore(AppStateEntity state) {
    return jsonEncode(state.toMap(includeLogs: false));
  }

  /// يحوّل سترنج JSON (لصيغة الـ core بدون logs) لـ [AppStateEntity].
  /// ممكن يعمل throw لو الـ JSON معطوب — الـ caller (الـ Repository) هو
  /// المسؤول عن التعامل مع ده، مش الدالة دي.
  static AppStateEntity deserializeCore(String json) {
    return AppStateEntity.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  /// يحوّل قائمة [LogEntryEntity] لسترنج JSON — نفس
  /// `jsonEncode(logs.map((l) => l.toMap()).toList())` اللي كانت جوه
  /// `_writeLogs` بالحرف.
  static String serializeLogs(List<LogEntryEntity> logs) {
    return jsonEncode(logs.map((l) => l.toMap()).toList());
  }

  /// يحوّل سترنج JSON لقائمة [LogEntryEntity]. ممكن يعمل throw لو الـ
  /// JSON معطوب — نفس مبدأ [deserializeCore].
  static List<LogEntryEntity> deserializeLogs(String json) {
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(LogEntryEntity.fromMap)
        .toList();
  }
}
