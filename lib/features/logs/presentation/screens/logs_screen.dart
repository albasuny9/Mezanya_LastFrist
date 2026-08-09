import 'package:mezanya_app/core/constants/transaction_types.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../recovery/domain/entities/recovery_entry.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/screens/recurring_transaction_composer_screen.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';
import '../../application/audit_facade.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _tab = 'all';
  String _range = 'all';
  DateTime? _customStart;
  DateTime? _customEnd;
  final Set<String> _entityTypes = <String>{};

  static const _green = Color(0xFF2F6F5E);
  static const _red = Color(0xFFC65D2E);
  static const _blue = Color(0xFF2E5CC6);
  static const _amber = Color(0xFFA07830);
  static const _purple = Color(0xFF6B42B8);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;
        final recovery = AuditFacade.recoveryHistory(state);
        final logs = _filtered(recovery);
        final total = recovery.length;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('السجلات'),
            actions: [
              IconButton(
                icon: Badge(
                  isLabelVisible: _range != 'all' || _entityTypes.isNotEmpty,
                  child: const Icon(Icons.tune_rounded),
                ),
                tooltip: 'الفلاتر',
                onPressed: _openFilters,
              ),
            ],
          ),
          body: Column(
            children: [
              _statsBar(total, logs.length),
              _tabsRow(),
              Expanded(
                child: logs.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          final rows = _detailRowsForLog(state, log);
                          return _LogCard(
                            log: log,
                            title: _pretty(log),
                            actionName: _actionName(log.action),
                            entityName: _entityTypeName(log.entityType),
                            timestamp: log.timestamp,
                            amount: rows['القيمة'] ?? rows['المبلغ'],
                            accentColor: _accentForLog(log),
                            onTap: () => _openDetails(state, log),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _accentForLog(RecoveryEntry log) {
    return switch (log.action) {
      'delete' => _red,
      'edit' => _amber,
      'transfer' => _blue,
      'revert' => _purple,
      'import' => _blue,
      _ => _green,
    };
  }

  Widget _statsBar(int total, int filtered) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _green.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: _green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إجمالي السجلات',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  filtered == total ? '$total سجل' : '$filtered من $total سجل',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
          if (filtered != total)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'مفلتر',
                style: TextStyle(
                  color: _amber,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tabChip('all', 'الكل', Icons.list_rounded, _green),
            _tabChip('transaction', 'معاملة', Icons.receipt_rounded, _green),
            _tabChip('recurring', 'متكررة', Icons.repeat_rounded, _blue),
            _tabChip('add', 'إضافة', Icons.add_circle_outline_rounded, _green),
            _tabChip('edit', 'تعديل', Icons.edit_outlined, _amber),
            _tabChip('delete', 'حذف', Icons.delete_outline_rounded, _red),
            _tabChip('transfer', 'تحويل', Icons.swap_horiz_rounded, _blue),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(
    String id,
    String label,
    IconData icon,
    Color color,
  ) {
    final selected = _tab == id;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: GestureDetector(
        onTap: () => setState(() => _tab = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.14)
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.6)
                  : Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.5),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  fontSize: 13,
                  color: selected
                      ? color
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 60,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.35),
          ),
          const SizedBox(height: 14),
          Text(
            'لا توجد سجلات مطابقة',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'جرّب تغيير الفلاتر أو الفئة المحددة',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  List<RecoveryEntry> _filtered(List<RecoveryEntry> logs) {
    final now = DateTime.now();
    var filtered = logs.where((log) {
      if (_range == 'day') return now.difference(log.timestamp).inHours <= 24;
      if (_range == 'week') return now.difference(log.timestamp).inDays <= 7;
      if (_range == 'month') return now.difference(log.timestamp).inDays <= 30;
      if (_range == 'custom' && _customStart != null && _customEnd != null) {
        final end = DateTime(
            _customEnd!.year, _customEnd!.month, _customEnd!.day, 23, 59, 59);
        return !log.timestamp.isBefore(_customStart!) &&
            !log.timestamp.isAfter(end);
      }
      return true;
    });
    if (_tab == 'transaction') {
      filtered = filtered.where((log) => log.entityType == 'transaction');
    } else if (_tab == 'recurring') {
      filtered =
          filtered.where((log) => log.entityType == 'recurring-transaction');
    } else if (_tab == 'add') {
      filtered = filtered.where((log) => log.action == 'add');
    } else if (_tab == 'edit') {
      filtered = filtered.where((log) => log.action == 'edit');
    } else if (_tab == 'delete') {
      filtered = filtered.where((log) => log.action == 'delete');
    } else if (_tab == 'transfer') {
      filtered = filtered.where((log) => log.action == 'transfer');
    }
    if (_entityTypes.isNotEmpty) {
      filtered = filtered.where((log) => _entityTypes.contains(log.entityType));
    }
    return filtered.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  void _openFilters() {
    final selected = Set<String>.from(_entityTypes);
    String range = _range;
    DateTime? customStart = _customStart;
    DateTime? customEnd = _customEnd;

    final entityOptions = [
      ('transaction', 'معاملة'),
      ('recurring-transaction', 'معاملة متكررة'),
      ('wallet', 'محفظة'),
      ('budget', 'ميزانية'),
      ('linked-wallet', 'حصالة'),
      ('category', 'فئة'),
      ('settings', 'إعدادات'),
      ('goal', 'هدف'),
    ];

    final rangeOptions = [
      ('all', 'كل الوقت'),
      ('day', 'آخر 24 ساعة'),
      ('week', 'آخر أسبوع'),
      ('month', 'آخر شهر'),
      ('custom', 'نطاق مخصص'),
    ];

    String fmtDate(DateTime? d) {
      if (d == null) return 'اختر تاريخ';
      return DateFormat('yyyy/MM/dd', 'ar').format(d);
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child:
                        const Icon(Icons.tune_rounded, color: _green, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'فلترة السجلات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'المدى الزمني',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: rangeOptions.map((opt) {
                  final (value, label) = opt;
                  final sel = range == value;
                  return GestureDetector(
                    onTap: () => setSheet(() => range = value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel
                            ? _blue.withValues(alpha: 0.13)
                            : Theme.of(ctx)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: sel
                              ? _blue.withValues(alpha: 0.6)
                              : Theme.of(ctx)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.5),
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: sel ? FontWeight.w900 : FontWeight.w700,
                          fontSize: 13,
                          color: sel
                              ? _blue
                              : Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (range == 'custom') ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _blue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'حدد النطاق الزمني',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: _blue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: customStart ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: customEnd ?? DateTime.now(),
                                  locale: const Locale('ar'),
                                  helpText: 'من تاريخ',
                                );
                                if (picked != null) {
                                  setSheet(() => customStart = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 11),
                                decoration: BoxDecoration(
                                  color: Theme.of(ctx).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: customStart != null
                                        ? _blue.withValues(alpha: 0.5)
                                        : Theme.of(ctx)
                                            .colorScheme
                                            .outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today_rounded,
                                        size: 15,
                                        color: customStart != null
                                            ? _blue
                                            : Theme.of(ctx)
                                                .colorScheme
                                                .onSurfaceVariant),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        'من: ${fmtDate(customStart)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: customStart != null
                                              ? _blue
                                              : Theme.of(ctx)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: customEnd ?? DateTime.now(),
                                  firstDate: customStart ?? DateTime(2020),
                                  lastDate: DateTime.now(),
                                  locale: const Locale('ar'),
                                  helpText: 'إلى تاريخ',
                                );
                                if (picked != null) {
                                  setSheet(() => customEnd = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 11),
                                decoration: BoxDecoration(
                                  color: Theme.of(ctx).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: customEnd != null
                                        ? _blue.withValues(alpha: 0.5)
                                        : Theme.of(ctx)
                                            .colorScheme
                                            .outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.event_rounded,
                                        size: 15,
                                        color: customEnd != null
                                            ? _blue
                                            : Theme.of(ctx)
                                                .colorScheme
                                                .onSurfaceVariant),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        'إلى: ${fmtDate(customEnd)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: customEnd != null
                                              ? _blue
                                              : Theme.of(ctx)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'نوع العنصر',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entityOptions.map((opt) {
                  final (value, label) = opt;
                  final sel = selected.contains(value);
                  return GestureDetector(
                    onTap: () => setSheet(() {
                      if (sel) {
                        selected.remove(value);
                      } else {
                        selected.add(value);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel
                            ? _amber.withValues(alpha: 0.13)
                            : Theme.of(ctx)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: sel
                              ? _amber.withValues(alpha: 0.6)
                              : Theme.of(ctx)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.5),
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (sel) ...[
                            Icon(Icons.check_rounded, size: 15, color: _amber),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            label,
                            style: TextStyle(
                              fontWeight:
                                  sel ? FontWeight.w900 : FontWeight.w700,
                              fontSize: 13,
                              color: sel
                                  ? _amber
                                  : Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setSheet(() {
                          range = 'all';
                          customStart = null;
                          customEnd = null;
                          selected.clear();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('مسح الكل'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _range = range;
                          _customStart = customStart;
                          _customEnd = customEnd;
                          _entityTypes
                            ..clear()
                            ..addAll(selected);
                        });
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('تطبيق الفلتر'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetails(AppStateEntity state, RecoveryEntry log) async {
    final rows = _detailRowsForLog(state, log);
    final changeRows = _changeRowsForEdit(state, log);
    final transaction = _currentTransaction(state, log.entityId);
    final recurring = _currentRecurring(state, log.entityId);
    final canEditTransaction =
        log.entityType == 'transaction' && transaction != null;
    final canDeleteTransaction =
        log.entityType == 'transaction' && transaction != null;
    final canEditRecurring =
        log.entityType == 'recurring-transaction' && recurring != null;
    final canDeleteRecurring =
        log.entityType == 'recurring-transaction' && recurring != null;
    final canUndoDelete = log.action == 'delete' && !log.isReverted;
    final accent = _accentForLog(log);
    final actionSentence = _actionSentence(state, log);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.88,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            // ─── Header card ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(_iconForAction(log.action),
                        color: accent, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pretty(log),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _miniTag(_actionName(log.action), accent),
                            _miniTag(_entityTypeName(log.entityType),
                                accent.withValues(alpha: 0.75)),
                            if (log.isReverted) _miniTag('تم التراجع', _purple),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ─── Action description + timestamps ─────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          actionSentence,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _infoRow(
                    Icons.schedule_rounded,
                    'وقت الحدث',
                    DateFormat('yyyy/MM/dd — HH:mm:ss', 'ar')
                        .format(log.timestamp),
                    accent,
                  ),
                  if (log.revertedAt != null) ...[
                    const SizedBox(height: 6),
                    _infoRow(
                      Icons.undo_rounded,
                      'وقت التراجع',
                      DateFormat('yyyy/MM/dd — HH:mm:ss', 'ar')
                          .format(log.revertedAt!),
                      _purple,
                    ),
                  ],
                  const SizedBox(height: 6),
                  _infoRow(
                    Icons.fingerprint_rounded,
                    'معرف السجل',
                    log.sourceLogId,
                    Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 6),
                  _infoRow(
                    Icons.link_rounded,
                    'معرف العنصر',
                    log.entityId,
                    Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─── Entity data ──────────────────────────────────
            if (rows.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'بيانات العنصر',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              _DetailsTable(rows: rows),
              const SizedBox(height: 14),
            ],

            // ─── Before / After diff for edits ───────────────
            if (changeRows.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'التغييرات التي تمت',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              _BeforeAfterTable(rows: changeRows),
              const SizedBox(height: 14),
            ],

            // ─── Action buttons ───────────────────────────────
            if (canEditTransaction) ...[
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await openTransactionDetailsSheet(
                    context,
                    cubit: widget.cubit,
                    transaction: transaction,
                  );
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('تعديل المعاملة'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (canEditRecurring) ...[
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => RecurringTransactionComposerScreen(
                        cubit: widget.cubit,
                        initialRecurring: recurring,
                        initialType: recurring.type,
                        initialWithinBudget: recurring.budgetScope ==
                            BudgetScope.withinBudget.value,
                        allowDelete: true,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('تعديل المعاملة المتكررة'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (canDeleteTransaction || canDeleteRecurring) ...[
              OutlinedButton.icon(
                onPressed: () async {
                  if (canDeleteTransaction) {
                    await widget.cubit.deleteTransaction(log.entityId);
                  } else {
                    await widget.cubit.deleteRecurringTransaction(log.entityId);
                  }
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                icon: Icon(Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error),
                label: Text(
                  canDeleteTransaction
                      ? 'حذف المعاملة'
                      : 'حذف المعاملة المتكررة',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (canUndoDelete) ...[
              OutlinedButton.icon(
                onPressed: () async {
                  await widget.cubit.toggleLogRevert(log.sourceLogId);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                icon: const Icon(Icons.undo_rounded),
                label: const Text('تراجع عن الحذف'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color.withValues(alpha: 0.7),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  String _actionSentence(AppStateEntity state, RecoveryEntry log) {
    final actionAr = _actionName(log.action);
    final entityAr = _entityTypeName(log.entityType);
    if (log.details.trim().isNotEmpty) return log.details.trim();
    if (log.entityType == 'transaction') {
      final tx = _transactionForLog(state, log);
      if (tx != null) {
        final typeAr = _transactionTypeName(tx.type);
        final amount = tx.amount.toStringAsFixed(2);
        if (log.action == 'add') return 'تمت إضافة $typeAr بقيمة $amount';
        if (log.action == 'edit') return 'تم تعديل $typeAr بقيمة $amount';
        if (log.action == 'delete') return 'تم حذف $typeAr بقيمة $amount';
        if (log.action == 'transfer') {
          return 'تم تحويل مبلغ $amount';
        }
      }
    }
    if (log.entityType == 'recurring-transaction') {
      final r = _recurringForLog(state, log);
      if (r != null) {
        if (log.action == 'add') return 'تمت إضافة معاملة متكررة «${r.name}»';
        if (log.action == 'edit') return 'تم تعديل معاملة متكررة «${r.name}»';
        if (log.action == 'delete') return 'تم حذف معاملة متكررة «${r.name}»';
      }
    }
    return 'تمت عملية $actionAr على $entityAr';
  }

  /// Returns a list of (field, before, after) for edit actions.
  List<(String, String, String)> _changeRowsForEdit(
      AppStateEntity state, RecoveryEntry log) {
    if (log.action != 'edit') return [];
    final before = _snapshotForLog(log, preferBefore: true);
    final after = _snapshotForLog(log, preferBefore: false);
    if (before == null || after == null) return [];

    Map<String, String> beforeMap = {};
    Map<String, String> afterMap = {};

    if (log.entityType == 'transaction') {
      final txBefore = before.transactions
          .where((t) => t.id == log.entityId)
          .cast<TransactionEntity?>()
          .firstWhere((t) => t != null, orElse: () => null);
      final txAfter = after.transactions
          .where((t) => t.id == log.entityId)
          .cast<TransactionEntity?>()
          .firstWhere((t) => t != null, orElse: () => null);
      if (txBefore != null) beforeMap = _transactionRows(state, txBefore);
      if (txAfter != null) afterMap = _transactionRows(state, txAfter);
    } else if (log.entityType == 'recurring-transaction') {
      final rBefore = before.recurringTransactions
          .where((r) => r.id == log.entityId)
          .cast<RecurringTransactionEntity?>()
          .firstWhere((r) => r != null, orElse: () => null);
      final rAfter = after.recurringTransactions
          .where((r) => r.id == log.entityId)
          .cast<RecurringTransactionEntity?>()
          .firstWhere((r) => r != null, orElse: () => null);
      if (rBefore != null) beforeMap = _recurringRows(state, rBefore);
      if (rAfter != null) afterMap = _recurringRows(state, rAfter);
    }

    if (beforeMap.isEmpty && afterMap.isEmpty) return [];
    final allKeys = {...beforeMap.keys, ...afterMap.keys};
    final changes = <(String, String, String)>[];
    for (final key in allKeys) {
      final b = beforeMap[key] ?? '—';
      final a = afterMap[key] ?? '—';
      if (b != a) changes.add((key, b, a));
    }
    return changes;
  }

  Widget _miniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  Map<String, String> _detailRowsForLog(
    AppStateEntity currentState,
    RecoveryEntry log,
  ) {
    if (log.entityType == 'transaction') {
      final tx = _transactionForLog(currentState, log);
      if (tx == null) return {'الوصف': _pretty(log)};
      return _transactionRows(currentState, tx);
    }
    if (log.entityType == 'recurring-transaction') {
      final recurring = _recurringForLog(currentState, log);
      if (recurring == null) return {'الوصف': _pretty(log)};
      return _recurringRows(currentState, recurring);
    }
    return {};
  }

  TransactionEntity? _transactionForLog(
    AppStateEntity currentState,
    RecoveryEntry log,
  ) {
    return _currentTransaction(currentState, log.entityId) ??
        _snapshotForLog(log, preferBefore: log.action == 'delete')
            ?.transactions
            .where((item) => item.id == log.entityId)
            .cast<TransactionEntity?>()
            .firstWhere((item) => item != null, orElse: () => null);
  }

  RecurringTransactionEntity? _recurringForLog(
    AppStateEntity currentState,
    RecoveryEntry log,
  ) {
    return _currentRecurring(currentState, log.entityId) ??
        _snapshotForLog(log, preferBefore: log.action == 'delete')
            ?.recurringTransactions
            .where((item) => item.id == log.entityId)
            .cast<RecurringTransactionEntity?>()
            .firstWhere((item) => item != null, orElse: () => null);
  }

  AppStateEntity? _snapshotForLog(
    RecoveryEntry log, {
    required bool preferBefore,
  }) {
    return AuditFacade.reconstructSnapshot(log, preferBefore: preferBefore);
  }

  TransactionEntity? _currentTransaction(AppStateEntity state, String id) {
    final items = state.transactions.where((item) => item.id == id).toList();
    return items.isEmpty ? null : items.first;
  }

  RecurringTransactionEntity? _currentRecurring(
      AppStateEntity state, String id) {
    final items =
        state.recurringTransactions.where((item) => item.id == id).toList();
    return items.isEmpty ? null : items.first;
  }

  Map<String, String> _transactionRows(
      AppStateEntity state, TransactionEntity tx) {
    return {
      'نوع العملية': _transactionTypeName(tx.type),
      'القيمة': tx.amount.toStringAsFixed(2),
      'التاريخ': DateFormat('yyyy/MM/dd', 'ar').format(tx.createdAt),
      'الوقت': DateFormat('HH:mm', 'ar').format(tx.createdAt),
      if (tx.walletId != null) 'المحفظة': _walletName(state, tx.walletId),
      if (tx.fromWalletId != null)
        'من محفظة': _walletName(state, tx.fromWalletId),
      if (tx.toWalletId != null) 'إلى': _walletOrJarName(state, tx.toWalletId),
      if (tx.incomeSourceId != null)
        'مصدر الدخل': _incomeName(state, tx.incomeSourceId),
      if (tx.allocationId != null)
        'المخصص': _allocationName(state, tx.allocationId),
      if (tx.categoryId != null) 'الفئة': _categoryName(state, tx.categoryId),
      if (tx.budgetScope != null) 'النطاق': _budgetScopeName(tx.budgetScope!),
      if (tx.notes?.isNotEmpty == true) 'الملاحظات': tx.notes!,
    };
  }

  Map<String, String> _recurringRows(
    AppStateEntity state,
    RecurringTransactionEntity recurring,
  ) {
    return {
      'اسم العملية': recurring.name,
      'نوع العملية': _transactionTypeName(recurring.type),
      'القيمة': recurring.isVariableIncome
          ? 'دخل متغير'
          : recurring.amount.toStringAsFixed(2),
      'المحفظة': _walletName(state, recurring.walletId),
      'النطاق': _budgetScopeName(recurring.budgetScope),
      'التكرار': _recurrenceName(recurring.recurrencePattern),
      'التنفيذ': _executionName(recurring.executionType),
      'يوم الشهر': recurring.dayOfMonth.toString(),
      if (recurring.scheduledTime?.isNotEmpty == true)
        'الوقت': recurring.scheduledTime!,
      if (recurring.isDebtOrSubscription) 'التصنيف': 'دين أو اشتراك',
      if (recurring.incomeSourceId != null)
        'مصدر الدخل': _incomeName(state, recurring.incomeSourceId),
      if (recurring.allocationId != null)
        'المخصص': _allocationName(state, recurring.allocationId),
      if (recurring.targetJarId != null)
        'الحصالة': _walletOrJarName(state, recurring.targetJarId),
      if (recurring.notes?.isNotEmpty == true) 'الملاحظات': recurring.notes!,
    };
  }

  String _pretty(RecoveryEntry log) {
    if (log.details.trim().isNotEmpty) return log.details.trim();
    return '${_actionName(log.action)} على ${_entityTypeName(log.entityType)}';
  }

  String _actionName(String action) {
    return switch (action) {
      'add' => 'إضافة',
      'edit' => 'تعديل',
      'delete' => 'حذف',
      'transfer' => 'تحويل',
      'revert' => 'تراجع',
      'import' => 'استيراد',
      _ => action,
    };
  }

  String _entityTypeName(String entityType) {
    return switch (entityType) {
      'transaction' => 'معاملة',
      'recurring-transaction' => 'معاملة متكررة',
      'wallet' => 'محفظة',
      'budget' => 'ميزانية',
      'linked-wallet' => 'حصالة',
      'category' => 'فئة',
      'settings' => 'إعدادات',
      'goal' => 'هدف',
      _ => entityType,
    };
  }

  String _transactionTypeName(String type) {
    return switch (type) {
      'income' => 'دخل',
      'expense' => 'مصروف',
      'transfer' => 'تحويل',
      'balance-adjustment' => 'تسوية رصيد',
      _ => type,
    };
  }

  String _budgetScopeName(String scope) {
    return scope == BudgetScope.withinBudget.value
        ? 'داخل الميزانية'
        : 'خارج الميزانية';
  }

  String _executionName(String type) {
    return switch (type) {
      'auto' => 'تلقائي',
      'confirm' => 'يحتاج تأكيد',
      'manual' => 'يدوي',
      _ => type,
    };
  }

  String _recurrenceName(String pattern) {
    return switch (pattern) {
      'daily' => 'يومي',
      'weekly' => 'أسبوعي',
      'biweekly' => 'كل أسبوعين',
      'every_3_weeks' => 'كل 3 أسابيع',
      'monthly' => 'شهري',
      'every_2_months' => 'كل شهرين',
      'every_3_months' => 'كل 3 شهور',
      'every_6_months' => 'كل 6 شهور',
      'yearly' => 'سنوي',
      'manual-variable' => 'يدوي متغير',
      _ => pattern,
    };
  }

  String _walletName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final wallets = state.wallets.where((item) => item.id == id).toList();
    return wallets.isEmpty ? id : wallets.first.name;
  }

  String _walletOrJarName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final wallets = state.wallets.where((item) => item.id == id).toList();
    if (wallets.isNotEmpty) return wallets.first.name;
    final jars =
        state.budgetSetup.linkedWallets.where((item) => item.id == id).toList();
    return jars.isEmpty ? id : jars.first.name;
  }

  String _incomeName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final items =
        state.budgetSetup.incomeSources.where((item) => item.id == id).toList();
    return items.isEmpty ? id : items.first.name;
  }

  String _allocationName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final items =
        state.budgetSetup.allocations.where((item) => item.id == id).toList();
    return items.isEmpty ? id : items.first.name;
  }

  String _categoryName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final items = state.categories.where((item) => item.id == id).toList();
    return items.isEmpty ? id : items.first.name;
  }

  IconData _iconForAction(String action) {
    return switch (action) {
      'delete' => Icons.delete_outline_rounded,
      'edit' => Icons.edit_outlined,
      'transfer' => Icons.swap_horiz_rounded,
      'revert' => Icons.undo_rounded,
      'import' => Icons.upload_rounded,
      _ => Icons.add_circle_outline_rounded,
    };
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.log,
    required this.title,
    required this.actionName,
    required this.entityName,
    required this.timestamp,
    required this.accentColor,
    required this.onTap,
    this.amount,
  });

  final RecoveryEntry log;
  final String title;
  final String actionName;
  final String entityName;
  final DateTime timestamp;
  final Color accentColor;
  final String? amount;
  final VoidCallback onTap;

  String _relativeTime() {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    return DateFormat('yyyy/MM/dd', 'ar').format(timestamp);
  }

  IconData _iconForAction(String action) {
    return switch (action) {
      'delete' => Icons.delete_outline_rounded,
      'edit' => Icons.edit_outlined,
      'transfer' => Icons.swap_horiz_rounded,
      'revert' => Icons.undo_rounded,
      'import' => Icons.upload_rounded,
      _ => Icons.add_circle_outline_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 72,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _iconForAction(log.action),
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _MiniChip(
                            label: actionName,
                            color: accent,
                          ),
                          const SizedBox(width: 5),
                          _MiniChip(
                            label: entityName,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          if (log.isReverted) ...[
                            const SizedBox(width: 5),
                            _MiniChip(
                              label: 'تراجع',
                              color: const Color(0xFF6B42B8),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (amount != null)
                    Text(
                      amount!,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: accent,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_left_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.rows});

  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final entries = rows.entries.toList();
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        children: List.generate(entries.length, (i) {
          final entry = entries[i];
          final isLast = i == entries.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _BeforeAfterTable extends StatelessWidget {
  const _BeforeAfterTable({required this.rows});

  final List<(String, String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const amber = Color(0xFFA07830);
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: amber.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(
                bottom: BorderSide(color: amber.withValues(alpha: 0.25)),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 90),
                Expanded(
                  child: Text(
                    'قبل',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: amber.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const Icon(Icons.arrow_back_ios_rounded,
                    size: 11, color: Color(0xFFA07830)),
                Expanded(
                  child: Text(
                    'بعد',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2F6F5E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(rows.length, (i) {
            final (field, before, after) = rows[i];
            final isLast = i == rows.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color:
                              colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      field,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      before,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: amber,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: amber.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_back_ios_rounded,
                      size: 11, color: Color(0xFF2F6F5E)),
                  Expanded(
                    child: Text(
                      after,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2F6F5E),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
