import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../logs/domain/entities/log_entry_entity.dart';
import '../../../money_distribution/domain/entities/distribution_entry.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../goals/domain/entities/goal_entity.dart';
import '../../../notifications/domain/entities/notification_entity.dart';

class AppStateEntity {
  const AppStateEntity({
    required this.wallets,
    required this.transactions,
    required this.budgetSetup,
    required this.categories,
    required this.userName,
    required this.currencyCode,
    required this.notificationsEnabled,
    required this.googleEmail,
    required this.logs,
    required this.recurringTransactions,
    required this.goals,
    required this.notifications,
    required this.backupDirectoryPath,
    required this.autoBackupMode,
    required this.lastAutoBackupAt,
    required this.monthlyBudgetSnapshots,
    this.moneyDistributions = const <DistributionEntry>[],
    this.profileImageUrl = '',
    this.moneyLocationMigrationDone = false,
    this.moneyDistributionMigrationDone = false,
  });

  final List<WalletEntity> wallets;
  final List<TransactionEntity> transactions;
  final BudgetSetupEntity budgetSetup;
  final List<CategoryEntity> categories;
  final String userName;
  final String currencyCode;
  final bool notificationsEnabled;
  final String googleEmail;
  final List<LogEntryEntity> logs;
  final List<RecurringTransactionEntity> recurringTransactions;
  final List<GoalEntity> goals;
  final List<NotificationEntity> notifications;
  final String backupDirectoryPath;
  final String autoBackupMode;
  final String lastAutoBackupAt;
  final Map<String, Map<String, dynamic>> monthlyBudgetSnapshots;
  final List<DistributionEntry> moneyDistributions;
  final String profileImageUrl;

  /// علامة تدل على أن ترحيل مراجعات مكان الفلوس قد تم مرة واحدة.
  /// يضمن ألا تُعاد إنشاء المراجعات بعد أن يتجاهلها المستخدم.
  final bool moneyLocationMigrationDone;
  final bool moneyDistributionMigrationDone;

  factory AppStateEntity.initial() {
    return AppStateEntity(
      wallets: <WalletEntity>[
        const WalletEntity(
          id: 'wallet-cash-default',
          name: 'الكاش',
          balance: 0,
          icon: 'cash',
          iconColor: '#165B47',
        ),
        const WalletEntity(
          id: 'wallet-bank-default',
          name: 'البنك',
          balance: 0,
          icon: 'bank',
          iconColor: '#1D4ED8',
        ),
      ],
      transactions: <TransactionEntity>[],
      budgetSetup: BudgetSetupEntity.initial('wallet-cash-default'),
      categories: const <CategoryEntity>[],
      userName: '',
      currencyCode: 'EGP',
      notificationsEnabled: true,
      googleEmail: '',
      logs: const <LogEntryEntity>[],
      recurringTransactions: const <RecurringTransactionEntity>[],
      goals: const <GoalEntity>[],
      notifications: const <NotificationEntity>[],
      moneyDistributions: const <DistributionEntry>[],
      backupDirectoryPath: '',
      autoBackupMode: 'off',
      lastAutoBackupAt: '',
      monthlyBudgetSnapshots: const <String, Map<String, dynamic>>{},
      profileImageUrl: '',
    );
  }

  AppStateEntity copyWith({
    List<WalletEntity>? wallets,
    List<TransactionEntity>? transactions,
    BudgetSetupEntity? budgetSetup,
    List<CategoryEntity>? categories,
    String? userName,
    String? currencyCode,
    bool? notificationsEnabled,
    String? googleEmail,
    List<LogEntryEntity>? logs,
    List<RecurringTransactionEntity>? recurringTransactions,
    List<GoalEntity>? goals,
    List<NotificationEntity>? notifications,
    String? backupDirectoryPath,
    String? autoBackupMode,
    String? lastAutoBackupAt,
    Map<String, Map<String, dynamic>>? monthlyBudgetSnapshots,
    List<DistributionEntry>? moneyDistributions,
    String? profileImageUrl,
    bool? moneyLocationMigrationDone,
    bool? moneyDistributionMigrationDone,
  }) {
    return AppStateEntity(
      wallets: wallets ?? this.wallets,
      transactions: transactions ?? this.transactions,
      budgetSetup: budgetSetup ?? this.budgetSetup,
      categories: categories ?? this.categories,
      userName: userName ?? this.userName,
      currencyCode: currencyCode ?? this.currencyCode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      googleEmail: googleEmail ?? this.googleEmail,
      logs: logs ?? this.logs,
      recurringTransactions:
          recurringTransactions ?? this.recurringTransactions,
      goals: goals ?? this.goals,
      notifications: notifications ?? this.notifications,
      backupDirectoryPath: backupDirectoryPath ?? this.backupDirectoryPath,
      autoBackupMode: autoBackupMode ?? this.autoBackupMode,
      lastAutoBackupAt: lastAutoBackupAt ?? this.lastAutoBackupAt,
      monthlyBudgetSnapshots:
          monthlyBudgetSnapshots ?? this.monthlyBudgetSnapshots,
      moneyDistributions: moneyDistributions ?? this.moneyDistributions,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      moneyLocationMigrationDone:
          moneyLocationMigrationDone ?? this.moneyLocationMigrationDone,
      moneyDistributionMigrationDone:
          moneyDistributionMigrationDone ?? this.moneyDistributionMigrationDone,
    );
  }

  bool get isEmpty =>
      transactions.isEmpty &&
      recurringTransactions.isEmpty &&
      budgetSetup.incomeSources.isEmpty &&
      budgetSetup.allocations.isEmpty &&
      wallets.every((w) => w.balance == 0);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'wallets': wallets.map((wallet) => wallet.toMap()).toList(),
      'transactions':
          transactions.map((transaction) => transaction.toMap()).toList(),
      'budgetSetup': budgetSetup.toMap(),
      'categories': categories.map((category) => category.toMap()).toList(),
      'userName': userName,
      'currencyCode': currencyCode,
      'notificationsEnabled': notificationsEnabled,
      'googleEmail': googleEmail,
      'logs': logs.map((item) => item.toMap()).toList(),
      'recurringTransactions':
          recurringTransactions.map((item) => item.toMap()).toList(),
      'goals': goals.map((item) => item.toMap()).toList(),
      'notifications': notifications.map((item) => item.toMap()).toList(),
      'backupDirectoryPath': backupDirectoryPath,
      'autoBackupMode': autoBackupMode,
      'lastAutoBackupAt': lastAutoBackupAt,
      'monthlyBudgetSnapshots': monthlyBudgetSnapshots,
      'moneyDistributions':
          moneyDistributions.map((entry) => entry.toMap()).toList(),
      'profileImageUrl': profileImageUrl,
      'moneyLocationMigrationDone': moneyLocationMigrationDone,
      'moneyDistributionMigrationDone': moneyDistributionMigrationDone,
    };
  }

  factory AppStateEntity.fromMap(Map<String, dynamic> map) {
    final walletsRaw = map['wallets'] as List<dynamic>? ?? <dynamic>[];
    final transactionsRaw =
        map['transactions'] as List<dynamic>? ?? <dynamic>[];
    final categoriesRaw = map['categories'] as List<dynamic>? ?? <dynamic>[];
    final logsRaw = map['logs'] as List<dynamic>? ?? <dynamic>[];
    final recurringRaw =
        map['recurringTransactions'] as List<dynamic>? ?? <dynamic>[];
    final goalsRaw = map['goals'] as List<dynamic>? ?? <dynamic>[];
    final notificationsRaw =
        map['notifications'] as List<dynamic>? ?? <dynamic>[];
    final snapshotsRaw =
        map['monthlyBudgetSnapshots'] as Map<String, dynamic>? ??
            <String, dynamic>{};
    final distributionsRaw =
        map['moneyDistributions'] as List<dynamic>? ?? <dynamic>[];

    return AppStateEntity(
      wallets: walletsRaw
          .whereType<Map<String, dynamic>>()
          .map(WalletEntity.fromMap)
          .toList(),
      transactions: transactionsRaw
          .whereType<Map<String, dynamic>>()
          .map(TransactionEntity.fromMap)
          .toList(),
      budgetSetup: map['budgetSetup'] is Map<String, dynamic>
          ? BudgetSetupEntity.fromMap(
              map['budgetSetup'] as Map<String, dynamic>)
          : BudgetSetupEntity.initial(
              walletsRaw.isNotEmpty
                  ? ((walletsRaw.first as Map<String, dynamic>)['id']
                          as String? ??
                      'wallet-cash-default')
                  : 'wallet-cash-default',
            ),
      categories: categoriesRaw
          .whereType<Map<String, dynamic>>()
          .map(CategoryEntity.fromMap)
          .toList(),
      userName: map['userName'] as String? ?? '',
      currencyCode: map['currencyCode'] as String? ?? 'EGP',
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      googleEmail: map['googleEmail'] as String? ?? '',
      logs: logsRaw
          .whereType<Map<String, dynamic>>()
          .map(LogEntryEntity.fromMap)
          .toList(),
      recurringTransactions: recurringRaw
          .whereType<Map<String, dynamic>>()
          .map(RecurringTransactionEntity.fromMap)
          .toList(),
      goals: goalsRaw
          .whereType<Map<String, dynamic>>()
          .map(GoalEntity.fromMap)
          .toList(),
      notifications: notificationsRaw
          .whereType<Map<String, dynamic>>()
          .map(NotificationEntity.fromMap)
          .toList(),
      backupDirectoryPath: map['backupDirectoryPath'] as String? ?? '',
      autoBackupMode: map['autoBackupMode'] as String? ?? 'off',
      lastAutoBackupAt: map['lastAutoBackupAt'] as String? ?? '',
      monthlyBudgetSnapshots: snapshotsRaw.map(
        (key, value) => MapEntry(
          key,
          value is Map<String, dynamic> ? value : <String, dynamic>{},
        ),
      ),
      moneyDistributions: distributionsRaw
          .whereType<Map<String, dynamic>>()
          .map(DistributionEntry.fromMap)
          .toList(),
      profileImageUrl: map['profileImageUrl'] as String? ?? '',
      moneyLocationMigrationDone:
          map['moneyLocationMigrationDone'] as bool? ?? false,
      moneyDistributionMigrationDone:
          map['moneyDistributionMigrationDone'] as bool? ?? false,
    );
  }
}
