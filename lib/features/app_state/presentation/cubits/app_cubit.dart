import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/transaction_types.dart';
import '../../../budget/domain/entities/money_location_review_entity.dart';
import '../../../budget/domain/services/money_location_engine.dart';
import '../../../transactions/domain/services/transaction_processor.dart';

import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../goals/domain/entities/goal_entity.dart';
import '../../../logs/domain/entities/log_entry_entity.dart';
import '../../../money_distribution/domain/entities/distribution_entry.dart';
import '../../../money_distribution/domain/services/distribution_engine.dart';
import '../../../notifications/domain/entities/notification_entity.dart';
import '../../../notifications/domain/notification_action_copy.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../domain/entities/app_state_entity.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/app_repository.dart';
import '../../../backup/backup_upload_pipeline.dart';
import '../../../backup/local_backup_service.dart';

part 'app_cubit_migration.dart';
part 'app_cubit_money_location.dart';
part 'app_cubit_transactions.dart';
part 'app_cubit_wallets.dart';
part 'app_cubit_budget.dart';
part 'app_cubit_jars.dart';
part 'app_cubit_allocations.dart';
part 'app_cubit_recurring.dart';
part 'app_cubit_lent.dart';
part 'app_cubit_goals.dart';
part 'app_cubit_categories.dart';
part 'app_cubit_settings.dart';
part 'app_cubit_backup.dart';
part 'app_cubit_notifications.dart';

abstract class AppCubitBase extends Cubit<AppStateEntity> {
  AppCubitBase(super.initialState);

  AppRepository get _repository;

  Future<void> initialize() async {
    var appState = await _repository.loadState();
    appState = _ensureDefaultSavingsJarSync(appState);
    appState = _migrateDefaultWalletIconsSync(appState);
    appState = _migrateOrphanedDebtRecurringSync(appState);
    appState = _normalizeMoneyLocationState(appState);
    final key = _monthKey();
    if (!appState.monthlyBudgetSnapshots.containsKey(key)) {
      appState = _withMonthlySnapshot(appState, appState.budgetSetup);
    }
    await _repository.saveState(appState);
    emit(appState);
  }

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  String _monthKey([DateTime? at]) {
    final date = at ?? DateTime.now();
    final mm = date.month.toString().padLeft(2, '0');
    return '${date.year}-$mm';
  }

  Map<String, dynamic> _coreMap(AppStateEntity appState) {
    final map = appState.toMap();
    map.remove('logs');
    return map;
  }

  AppStateEntity _restoreFromCore(String coreJson, List<LogEntryEntity> logs) {
    final map = jsonDecode(coreJson) as Map<String, dynamic>;
    return _normalizeMoneyLocationState(
      AppStateEntity.fromMap(map).copyWith(logs: logs),
    );
  }

  Future<void> _applyAndLog({
    required String action,
    required String entityType,
    required String entityId,
    required String details,
    String? titleOverride,
    bool recordInNotificationHistory = false,
    required Future<AppStateEntity> Function() apply,
  }) async {
    final before = jsonEncode(_coreMap(state));
    final nextRaw = await apply();
    final after = jsonEncode(_coreMap(nextRaw));
    final title = titleOverride ?? _notificationTitle(action, entityType);
    final log = LogEntryEntity(
      id: _id('log'),
      action: action,
      entityType: entityType,
      entityId: entityId,
      details: details,
      timestamp: DateTime.now(),
      beforeState: before,
      afterState: after,
      isReverted: false,
    );
    final notifications = recordInNotificationHistory
        ? [
            NotificationEntity(
              id: _id('notif'),
              title: title,
              message: details,
              createdAt: DateTime.now(),
              type: entityType,
              relatedLogId: log.id,
              isPendingAction: true,
            ),
            ...nextRaw.notifications,
          ].take(800).toList()
        : nextRaw.notifications;
    final next = nextRaw.copyWith(
      logs: [log, ...nextRaw.logs].take(600).toList(),
      notifications: notifications,
    );
    await _repository.saveState(next);
    emit(next);
    _autoSync(next);
  }

  /// رفع/حفظ تلقائي بعد كل عملية حفظ (غير blocking). يشغّل مسارين
  /// مستقلين تمامًا حسب التفعيل: النسخ التلقائي السحابي (BackupUploadPipeline
  /// بخانتين متبادلتين) والنسخ التلقائي المحلي (LocalBackupService بملفين
  /// متبادلين) — كل واحد منهما مستقل عن النسخ اليدوي تمامًا ولا يكتب فوقه.
  /// يضمن وجود جلسة Firebase موثَّقة قبل أي رفع تلقائي، بدون الاعتماد
  /// على زيارة المستخدم لأي شاشة إعدادات في نفس الجلسة (كان هذا السبب
  /// الجذري لعدم عمل النسخ التلقائي السحابي إطلاقًا في الجلسات التي لا
  /// تُفتح فيها شاشة الإعدادات — راجع تحقيق الباگ في نفس هذا الالتزام).
  /// يستخدم `signInSilently()` (استرجاع صامت لجلسة Google محفوظة، بلا
  /// أي واجهة) — إن لم توجد جلسة، يخرج بأمان بلا أثر.
  Future<void> _ensureFirebaseBridged() async {
    if (FirebaseAuth.instance.currentUser != null) return;
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      final account =
          googleSignIn.currentUser ?? await googleSignIn.signInSilently();
      if (account == null) return;
      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (_) {
      // فشل الجسر — الرفع التلقائي هيتخطى هذه الدورة بأمان، زي حالة
      // عدم وجود مستخدم مسجَّل من الأساس.
    }
  }

  void _autoSync(AppStateEntity appState) {
    _ensureFirebaseBridged().then((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) return;
      SharedPreferences.getInstance().then((prefs) {
        final enabled = prefs.getBool('auto_cloud_backup_enabled') ?? false;
        if (!enabled) return;
        BackupUploadPipeline.run(
          email: user.email!,
          displayName: user.displayName ?? user.email!,
          localState: appState,
          exportJson: () => jsonEncode(appState.toMap()),
          kind: BackupKind.auto,
        ).then((result) async {
          final p = await SharedPreferences.getInstance();
          final statusStr = switch (result.status) {
            BackupUploadStatus.uploaded => 'ok',
            BackupUploadStatus.deferredConflict => 'deferred',
            BackupUploadStatus.error => 'failed',
            BackupUploadStatus.rejectedEmpty ||
            BackupUploadStatus.rejectedShrink ||
            BackupUploadStatus.cancelled =>
              'failed',
          };
          await p.setString('last_auto_cloud_status', statusStr);
        }).catchError((_) async {
          final p = await SharedPreferences.getInstance();
          await p.setString('last_auto_cloud_status', 'failed');
        });
      }).catchError((_) {});
    }).catchError((_) {});

    LocalBackupService.autoEnabled().then((enabled) {
      if (!enabled || appState.isEmpty) return;
      LocalBackupService.writeAuto(jsonEncode(appState.toMap()));
    }).catchError((_) {});
    // لو السحابة مش متاحة أو تم تأجيل الرفع، مش بيوقف الـ app.
  }

  String _notificationTitle(String action, String entityType) {
    if (entityType == 'income' || entityType == 'transaction') {
      return 'إشعار معاملة';
    }
    if (entityType == 'budget') {
      return 'إشعار الميزانية';
    }
    if (entityType == 'recurring-transaction') {
      return 'إشعار معاملة متكررة';
    }
    if (entityType == 'goal') {
      return 'إشعار هدف';
    }
    if (action == 'delete') {
      return 'إشعار حذف';
    }
    return 'إشعار جديد';
  }
}

class AppCubit extends AppCubitBase
    with
        AppCubitMigrationMixin,
        AppCubitMoneyLocationMixin,
        AppCubitTransactionsMixin,
        AppCubitWalletsMixin,
        AppCubitBudgetMixin,
        AppCubitJarsMixin,
        AppCubitAllocationsMixin,
        AppCubitRecurringMixin,
        AppCubitLentMixin,
        AppCubitGoalsMixin,
        AppCubitCategoriesMixin,
        AppCubitSettingsMixin,
        AppCubitBackupMixin,
        AppCubitNotificationsMixin {
  AppCubit(this._repository) : super(AppStateEntity.initial());

  @override
  final AppRepository _repository;
}
