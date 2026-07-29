import '../../../logs/domain/entities/log_entry_entity.dart';
import '../../domain/entities/app_state_entity.dart';
import '../serializers/app_state_serializer.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Final cleanup phase من خطة إعادة تصميم طبقة الـ Persistence.
///
/// [AppStateValidator] مسؤولة حصريًا عن **محاولة** فك تشفير payload
/// معيّن، وترجع `null` بدل ما ترمي استثناء لو فشلت — كل ده بدون أي معرفة
/// بـ `SharedPreferences` أو أي قرار "نكتب على القرص ولا لأ".
///
/// **قرار مهم متعمَّد:** الـ Validator ده **مبيقررش** إيه اللي يحصل لو
/// الفك فشل (يرجع initial state؟ يسيب البيانات القديمة زي ما هي؟) — القرار
/// ده بيفضل عند الـ Repository (orchestration)، لأنه مرتبط بقرارات لها
/// أثر جانبي على القرص (زي "متكتبش فوق البيانات المعطوبة") مش بمنطق
/// "هل الـ JSON ده صالح ولا لأ" البحت. الفصل ده بيخلي الـ Validator نقي
/// (pure) تمامًا: بياخد سترنج، يرجّع entity أو null، بس.
/// ═══════════════════════════════════════════════════════════════════════
class AppStateValidator {
  const AppStateValidator._();

  /// يحاول فك تشفير [payload] كـ core state. بيرجع `null` لو الـ JSON
  /// معطوب أو الصيغة غلط — بدون أي استثناء يوصل للـ caller.
  static AppStateEntity? tryDeserializeCore(String payload) {
    try {
      return AppStateSerializer.deserializeCore(payload);
    } catch (_) {
      return null;
    }
  }

  /// يحاول فك تشفير [payload] كقائمة logs. بيرجع `null` لو الـ JSON معطوب.
  static List<LogEntryEntity>? tryDeserializeLogs(String payload) {
    try {
      return AppStateSerializer.deserializeLogs(payload);
    } catch (_) {
      return null;
    }
  }
}
