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
import '../../../../core/perf/txn_timing.dart'; // Sprint #2 — remove when done
import '../../domain/services/migration_service.dart';
import '../../domain/services/audit_log_service.dart';
import '../../domain/services/money_distribution_service.dart';

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

  // عقود مجرّدة لواجهات عامة يستخدمها أكثر من mixin واحد. التنفيذ الفعلي
  // يبقى في الـ mixin المالك (transactions / budget) لتفادي تكرار المنطق؛
  // الإعلان هنا فقط يجعلها مرئية لبقية الـ mixins عبر `on AppCubitBase`.
  Future<void> addTransaction({
    String? walletId,
    String? fromWalletId,
    String? toWalletId,
    required double amount,
    required String type,
    String? allocationId,
    String? toAllocationId,
    String? budgetScope,
    String? incomeSourceId,
    String? categoryId,
    String? transferType,
    String? notes,
    DateTime? createdAt,
    String? details,
    String? notificationTitleOverride,
    bool recordInNotificationHistory = false,
  });

  Future<void> updateBudgetSetup(
    BudgetSetupEntity setup, {
    String? detailsOverride,
    String? titleOverride,
    bool recordInNotificationHistory = false,
  });

  Future<void> initialize() async {
    var appState = await _repository.loadState();
    appState = MigrationService.ensureDefaultSavingsJarSync(appState);
    appState = MigrationService.migrateDefaultWalletIconsSync(appState);
    appState = MigrationService.migrateOrphanedDebtRecurringSync(appState);
    appState = MigrationService.normalizeMoneyLocationState(appState);
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
    return appState.toMap(includeLogs: false);
  }

  AppStateEntity _withMonthlySnapshot(
    AppStateEntity source,
    BudgetSetupEntity setup, [
    DateTime? month,
  ]) {
    final snapshots = Map<String, Map<String, dynamic>>.from(
      source.monthlyBudgetSnapshots,
    );
    snapshots[_monthKey(month)] = setup.toMap();
    return source.copyWith(monthlyBudgetSnapshots: snapshots);
  }

  AppStateEntity _restoreFromCore(String coreJson, List<LogEntryEntity> logs) {
    final map = jsonDecode(coreJson) as Map<String, dynamic>;
    return MigrationService.normalizeMoneyLocationState(
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
    // ── Sprint #2: pipeline timing ─────────────────────────────────────────
    final _swTotal = Stopwatch()..start();

    final _swJson1 = Stopwatch()..start();
    final before = jsonEncode(_coreMap(state));
    _swJson1.stop();
    TxnTimingCollector.current
        .record('06a | jsonEncode — before state', _swJson1.elapsedMilliseconds);

    final _swApply = Stopwatch()..start();
    final nextRaw = await apply();
    _swApply.stop();
    TxnTimingCollector.current
        .record('04  | TransactionProcessor.apply()', _swApply.elapsedMilliseconds);

    final _swJson2 = Stopwatch()..start();
    final after = jsonEncode(_coreMap(nextRaw));
    _swJson2.stop();
    TxnTimingCollector.current
        .record('06b | jsonEncode — after state', _swJson2.elapsedMilliseconds);
    // ──────────────────────────────────────────────────────────────────────

    final built = AuditLogService.build(
      action: action,
      entityType: entityType,
      entityId: entityId,
      details: details,
      beforeStateJson: before,
      afterStateJson: after,
      existingLogs: nextRaw.logs,
      existingNotifications: nextRaw.notifications,
      titleOverride: titleOverride,
      recordInNotificationHistory: recordInNotificationHistory,
    );
    final next = nextRaw.copyWith(
      logs: built.logs,
      notifications: built.notifications,
    );

    // ── Sprint #2: saveState, emit, autoSync timing ────────────────────────
    final _swSave = Stopwatch()..start();
    await _repository.saveState(next);
    _swSave.stop();
    TxnTimingCollector.current
        .record('07  | Repository.saveState()', _swSave.elapsedMilliseconds);

    final _swEmit = Stopwatch()..start();
    emit(next);
    _swEmit.stop();
    TxnTimingCollector.current
        .record('09  | emit(next)', _swEmit.elapsedMilliseconds);

    final _swSync = Stopwatch()..start();
    _autoSync(next);
    _swSync.stop();
    TxnTimingCollector.current
        .record('10  | _autoSync (fire-and-forget scheduled)', _swSync.elapsedMilliseconds);

    _swTotal.stop();
    TxnTimingCollector.current
        .record('05  | _applyAndLog() total', _swTotal.elapsedMilliseconds);
    // ──────────────────────────────────────────────────────────────────────
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
        final _swBup = Stopwatch()..start(); // Sprint #2
        BackupUploadPipeline.run(
          email: user.email!,
          displayName: user.displayName ?? user.email!,
          localState: appState,
          exportJson: () => jsonEncode(appState.toMap()),
          kind: BackupKind.auto,
        ).then((result) async {
          _swBup.stop(); // Sprint #2
          TxnTimingCollector.printBackground( // Sprint #2
              '11  | BackupUploadPipeline.run()', _swBup.elapsedMilliseconds);
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
          _swBup.stop(); // Sprint #2
          TxnTimingCollector.printBackground( // Sprint #2
              '11  | BackupUploadPipeline.run() [error]', _swBup.elapsedMilliseconds);
          final p = await SharedPreferences.getInstance();
          await p.setString('last_auto_cloud_status', 'failed');
        });
      }).catchError((_) {});
    }).catchError((_) {});

    LocalBackupService.autoEnabled().then((enabled) {
      if (!enabled || appState.isEmpty) return;
      // Sprint #2: include the jsonEncode in the measured window (it runs
      // synchronously before writeAuto, so it IS part of local-backup cost).
      final _swLocal = Stopwatch()..start();
      final _localJson = jsonEncode(appState.toMap());
      LocalBackupService.writeAuto(_localJson).then((_) {
        _swLocal.stop();
        TxnTimingCollector.printBackground(
            '12  | LocalBackupService (encode + write)', _swLocal.elapsedMilliseconds);
      });
    }).catchError((_) {});
    // لو السحابة مش متاحة أو تم تأجيل الرفع، مش بيوقف الـ app.
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
