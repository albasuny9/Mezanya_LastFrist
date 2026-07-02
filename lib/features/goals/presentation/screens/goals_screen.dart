import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../domain/entities/goal_entity.dart';
import '../../../wallets/presentation/widgets/jar_details_sheet.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.cubit.ensureDefaultSavingsJar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;
        final jar = _savingsJar(state);
        final savedAmount = jar?.balance ?? 0;
        final totalTargets = state.goals.fold<double>(
          0,
          (sum, goal) => sum + goal.targetAmount,
        );
        final completedGoals = state.goals
            .where((goal) => _progress(goal, savedAmount) >= 1)
            .length;
        final remainingAmount =
            (totalTargets - savedAmount).clamp(0.0, double.infinity);
        final completedAmount =
            savedAmount.clamp(0.0, totalTargets > 0 ? totalTargets : savedAmount);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _heroCard(
              goalsCount: state.goals.length,
              completedAmount: completedAmount,
              totalTargets: totalTargets,
              remainingAmount: remainingAmount,
            ),
            const SizedBox(height: 14),
            _savingsJarCard(
              jar: jar,
              savedAmount: savedAmount,
            ),
            const SizedBox(height: 18),
            if (state.goals.isNotEmpty) ...[
              _sectionHeader('الأهداف', '$completedGoals مكتمل'),
              const SizedBox(height: 10),
            ],
            if (state.goals.isEmpty)
              _emptyGoalsCard()
            else
              ...state.goals.map(
                (goal) => _goalCard(state, goal, savedAmount),
              ),
          ],
        );
      },
    );
  }

  LinkedWalletEntity? _savingsJar(AppStateEntity state) {
    final matches = state.budgetSetup.linkedWallets
        .where((wallet) => wallet.id == 'linked-savings-default')
        .toList();
    return matches.isEmpty ? null : matches.first;
  }

  Widget _heroCard({
    required int goalsCount,
    required double completedAmount,
    required double totalTargets,
    required double remainingAmount,
  }) {
    const accent = Color(0xFF165B47);
    final theme = Theme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A3D36), Color(0xFF165B47), Color(0xFF1F6F54)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: _GoalsNightSkyPainter(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'أهداف التوفير',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'حوّل كل هدف لخطة واضحة بمبلغ ومدة وأيقونة مميزة.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.flag_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _HeroStatCell(
                            icon: Icons.schedule_rounded,
                            label: 'المتبقي',
                            value: _formatGoalAmount(remainingAmount),
                            unit: 'جنيه',
                          ),
                        ),
                        _heroStatDivider(),
                        Expanded(
                          child: _HeroStatCell(
                            icon: Icons.star_outline_rounded,
                            label: 'الأهداف',
                            value: '$goalsCount',
                            unit: 'هدف',
                          ),
                        ),
                        _heroStatDivider(),
                        Expanded(
                          child: _HeroStatCell(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'المكتمل',
                            value: _formatGoalAmount(completedAmount),
                            unit: 'جنيه',
                          ),
                        ),
                        _heroStatDivider(),
                        Expanded(
                          child: _HeroStatCell(
                            icon: Icons.savings_outlined,
                            label: 'المستهدف',
                            value: _formatGoalAmount(totalTargets),
                            unit: 'جنيه',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _openGoalEditor(widget.cubit.state),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('إضافة هدف جديد'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: accent,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStatDivider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.white.withValues(alpha: 0.18),
    );
  }

  String _formatGoalAmount(double value) {
    return NumberFormat('#,##0', 'en').format(value.round());
  }

  Widget _savingsJarCard({
    required LinkedWalletEntity? jar,
    required double savedAmount,
  }) {
    const accent = Color(0xFF165B47);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accent.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.monetization_on_rounded,
                        color: accent,
                        size: 34,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      left: 6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF9A825),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.monetization_on_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: jar == null
                    ? null
                    : () => showJarDetailsSheet(
                          context: context,
                          cubit: widget.cubit,
                          jarId: jar.id,
                          onEditJar: (_) {},
                        ),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تفاصيل الرصيد',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      Icon(
                        Icons.chevron_left_rounded,
                        size: 16,
                        color: accent,
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jar?.name ?? 'التوفير',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: accent,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'الرصيد المتاح لتحقيق الأهداف',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 54,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: accent.withValues(alpha: 0.15),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                savedAmount.toStringAsFixed(2),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'جنيه',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String meta) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Divider(color: theme.colorScheme.outlineVariant),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          meta,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _goalCard(AppStateEntity state, GoalEntity goal, double savedAmount) {
    final theme = Theme.of(context);
    final accent = _colorFromHex(goal.iconColor);
    final progress = _progress(goal, savedAmount);
    final remaining = (goal.targetAmount - savedAmount)
        .clamp(0.0, goal.targetAmount)
        .toDouble();
    final daysLeft = goal.endDate.difference(DateTime.now()).inDays;
    final monthlyNeeded = _monthlyNeeded(remaining, daysLeft);
    final isCompleted = progress >= 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openGoalDetails(state, goal, savedAmount),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Center(
                      child: AppIconPickerDialog.iconWidgetForName(
                        goal.icon,
                        color: accent,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                goal.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_left_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isCompleted
                              ? 'تم الوصول للهدف'
                              : 'متبقي ${remaining.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isCompleted
                                ? const Color(0xFF1F6F54)
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  color: accent,
                  backgroundColor: accent.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _GoalMiniData(
                    label: 'المستهدف',
                    value: goal.targetAmount.toStringAsFixed(0),
                  ),
                  _GoalMiniData(
                    label: 'نسبة الإنجاز',
                    value: '${(progress * 100).toStringAsFixed(0)}%',
                  ),
                  _GoalMiniData(
                    label: 'شهريًا تقريبًا',
                    value: monthlyNeeded <= 0
                        ? '0'
                        : monthlyNeeded.toStringAsFixed(0),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyGoalsCard() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: const Color(0xFF1F6F54).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFF1F6F54),
              size: 38,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'لسه مفيش أهداف',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ابدأ بهدف واضح: مبلغ، موعد، أيقونة، وملاحظات تساعدك تتابعه بسهولة.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openGoalEditor(widget.cubit.state),
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة أول هدف'),
          ),
        ],
      ),
    );
  }

  Future<void> _openGoalEditor(
    AppStateEntity state, {
    GoalEntity? current,
  }) async {
    final result = await Navigator.of(context).push<_GoalEditorResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _GoalEditorScreen(current: current),
      ),
    );
    if (result == null) return;
    if (result.deleteRequested && current != null) {
      await widget.cubit.deleteGoal(current.id);
      return;
    }
    final goal = result.goal;
    if (goal == null) return;
    if (current == null) {
      await widget.cubit.addGoal(
        name: goal.name,
        targetAmount: goal.targetAmount,
        startDate: goal.startDate,
        endDate: goal.endDate,
        icon: goal.icon,
        iconColor: goal.iconColor,
        notes: goal.notes,
      );
    } else {
      await widget.cubit.updateGoal(goal);
    }
  }

  Future<void> _openGoalDetails(
    AppStateEntity state,
    GoalEntity goal,
    double savedAmount,
  ) async {
    final accent = _colorFromHex(goal.iconColor);
    final progress = _progress(goal, savedAmount);
    final remaining = (goal.targetAmount - savedAmount)
        .clamp(0.0, goal.targetAmount)
        .toDouble();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: AppIconPickerDialog.iconWidgetForName(
                    goal.icon,
                    color: accent,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                goal.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 14),
              _DetailsTable(
                rows: [
                  _DetailRow(
                      'المبلغ المستهدف', goal.targetAmount.toStringAsFixed(2)),
                  _DetailRow(
                      'المتوفر في الحصالة', savedAmount.toStringAsFixed(2)),
                  _DetailRow('المتبقي', remaining.toStringAsFixed(2)),
                  _DetailRow('نسبة الإنجاز',
                      '${(progress * 100).toStringAsFixed(0)}%'),
                  _DetailRow('بداية الهدف', _formatDate(goal.startDate)),
                  _DetailRow('نهاية الهدف', _formatDate(goal.endDate)),
                  if ((goal.notes ?? '').trim().isNotEmpty)
                    _DetailRow('ملاحظات', goal.notes!.trim()),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openGoalEditor(state, current: goal);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('تعديل'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openAchieveSheet(state, goal);
                      },
                      icon: const Icon(Icons.emoji_events_outlined),
                      label: const Text('تحقيق الهدف'),
                      style: FilledButton.styleFrom(backgroundColor: accent),
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

  Future<void> _openAchieveSheet(AppStateEntity state, GoalEntity goal) async {
    final jar = _savingsJar(state);
    if (jar == null) return;
    final amountController = TextEditingController(
      text: (goal.targetAmount <= jar.balance ? goal.targetAmount : jar.balance)
          .toStringAsFixed(2),
    );
    final notesController =
        TextEditingController(text: 'تحقيق هدف: ${goal.name}');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          6,
          16,
          MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EditorSection(
                title: 'تسجيل تحقيق الهدف',
                subtitle:
                    'سيتم تسجيل مصروف خارج الميزانية من حصالة التوفير حتى يظل الأثر المالي واضحًا.',
                child: Column(
                  children: [
                    _InfoStrip(
                      icon: Icons.monetization_on_rounded,
                      title: 'الرصيد الحالي',
                      value: jar.balance.toStringAsFixed(2),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المستخدم',
                        hintText: 'اكتب قيمة الصرف من الحصالة',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'الوصف',
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () async {
                        final amount =
                            double.tryParse(amountController.text.trim()) ?? 0;
                        if (amount <= 0 || amount > jar.balance) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('اكتب مبلغًا صحيحًا داخل رصيد الحصالة.'),
                            ),
                          );
                          return;
                        }
                        await widget.cubit.addTransaction(
                          type: TransactionType.expense.value,
                          walletId: jar.id,
                          amount: amount,
                          budgetScope: BudgetScope.outsideBudget.value,
                          notes: notesController.text.trim().isEmpty
                              ? 'تحقيق هدف ${goal.name}'
                              : notesController.text.trim(),
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('تسجيل العملية'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _progress(GoalEntity goal, double savedAmount) {
    if (goal.targetAmount <= 0) return 0;
    return (savedAmount / goal.targetAmount).clamp(0.0, 1.0).toDouble();
  }

  double _monthlyNeeded(double remaining, int daysLeft) {
    if (remaining <= 0 || daysLeft <= 0) return remaining;
    final months = (daysLeft / 30).clamp(1.0, 120.0).toDouble();
    return remaining / months;
  }

  String _formatDate(DateTime date) => DateFormat('d/M/yyyy').format(date);
}

class _GoalEditorResult {
  const _GoalEditorResult({this.goal, this.deleteRequested = false});

  final GoalEntity? goal;
  final bool deleteRequested;
}

class _GoalEditorScreen extends StatefulWidget {
  const _GoalEditorScreen({required this.current});

  final GoalEntity? current;

  @override
  State<_GoalEditorScreen> createState() => _GoalEditorScreenState();
}

class _GoalEditorScreenState extends State<_GoalEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _notesController;
  late DateTime _startDate;
  late DateTime _endDate;
  late String _selectedIcon;
  late String _selectedColor;

  bool get _canDelete => widget.current != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.current?.name ?? '');
    _targetController = TextEditingController(
      text: widget.current == null
          ? ''
          : widget.current!.targetAmount.toStringAsFixed(0),
    );
    _notesController = TextEditingController(text: widget.current?.notes ?? '');
    _startDate = widget.current?.startDate ?? DateTime.now();
    _endDate =
        widget.current?.endDate ?? DateTime.now().add(const Duration(days: 90));
    _selectedIcon = widget.current?.icon ?? 'savings';
    _selectedColor = widget.current?.iconColor ?? '#2f6f5e';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final picked = await AppIconPickerDialog.show(
      context,
      initialIconName: _selectedIcon,
      initialColorHex: _selectedColor,
      title: 'اختيار أيقونة الهدف',
      name: _nameController.text,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedIcon = picked.iconName;
      _selectedColor = picked.colorHex;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 30));
        }
      } else {
        _endDate = picked;
      }
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    final target = double.tryParse(_targetController.text.trim()) ?? 0;
    if (name.isEmpty) {
      _showMessage('اكتب اسم الهدف أولًا.');
      return;
    }
    if (target <= 0) {
      _showMessage('اكتب مبلغًا مستهدفًا أكبر من صفر.');
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      _showMessage('تاريخ نهاية الهدف يجب أن يكون بعد تاريخ البداية.');
      return;
    }
    Navigator.of(context).pop(
      _GoalEditorResult(
        goal: GoalEntity(
          id: widget.current?.id ??
              'goal-${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          targetAmount: target,
          startDate: _startDate,
          endDate: _endDate,
          icon: _selectedIcon,
          iconColor: _selectedColor,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ),
      ),
    );
  }

  Future<void> _delete() async {
    if (!_canDelete) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الهدف'),
        content: const Text(
            'سيتم حذف هذا الهدف من قائمة الأهداف. هل تريد المتابعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    Navigator.of(context).pop(const _GoalEditorResult(deleteRequested: true));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = _colorFromHex(_selectedColor);
    final target = double.tryParse(_targetController.text.trim()) ?? 0;
    final days = _endDate.difference(_startDate).inDays.clamp(1, 3650);
    final monthlyTarget = target <= 0 ? 0 : target / (days / 30);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.current == null ? 'إضافة هدف' : 'تعديل الهدف'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: accent,
            ),
            child: Text(
              widget.current == null ? 'إضافة الهدف' : 'حفظ التعديلات',
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.96),
                  accent.withValues(alpha: 0.72),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: AppIconPickerDialog.iconWidgetForName(
                      _selectedIcon,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameController.text.trim().isEmpty
                            ? 'هدف جديد'
                            : _nameController.text.trim(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        target <= 0
                            ? 'حدد المبلغ والمدة لتظهر الخطة'
                            : 'تحتاج تقريبًا ${monthlyTarget.toStringAsFixed(0)} شهريًا',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.93),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _EditorSection(
            title: 'بيانات الهدف',
            subtitle: 'اكتب اسمًا واضحًا واختر أيقونة ولونًا يميزان الهدف.',
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الهدف',
                    hintText: 'مثل: مصيف، لابتوب، مقدم شقة',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickIcon,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.35,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: AppIconPickerDialog.iconWidgetForName(
                              _selectedIcon,
                              color: accent,
                              size: 27,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'اختيار الأيقونة واللون',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ستظهر الأيقونة في كارت الهدف وقائمة المتابعة.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_left_rounded),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _EditorSection(
            title: 'الخطة المالية',
            subtitle:
                'حدد المبلغ المطلوب والمدة حتى يظهر لك الاحتياج الشهري التقريبي.',
            child: Column(
              children: [
                TextField(
                  controller: _targetController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المستهدف',
                    hintText: 'اكتب قيمة الهدف',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateTile(
                        label: 'البداية',
                        value: _formatDate(_startDate),
                        onTap: () => _pickDate(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateTile(
                        label: 'النهاية',
                        value: _formatDate(_endDate),
                        onTap: () => _pickDate(isStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoStrip(
                  icon: Icons.calendar_month_rounded,
                  title: 'الاحتياج الشهري التقريبي',
                  value: monthlyTarget <= 0
                      ? '0'
                      : monthlyTarget.toStringAsFixed(0),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _EditorSection(
            title: 'ملاحظات',
            subtitle: 'اكتب أي تفاصيل تساعدك تتذكر الهدف أو سبب أهميته.',
            child: TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'ملاحظات اختيارية',
                hintText: 'مثال: جزء من الخطة السنوية أو هدف قبل السفر',
              ),
            ),
          ),
          if (_canDelete) ...[
            const SizedBox(height: 14),
            _EditorSection(
              title: 'إدارة الهدف',
              subtitle:
                  'الحذف موجود هنا فقط لتجنب الضغط عليه بالخطأ من القائمة.',
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف الهدف'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => DateFormat('d/M/yyyy').format(date);
}

class _HeroStatCell extends StatelessWidget {
  const _HeroStatCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          unit,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _GoalsNightSkyPainter extends CustomPainter {
  const _GoalsNightSkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final mountainPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final farMountain = Path()
      ..moveTo(0, size.height * 0.72)
      ..lineTo(size.width * 0.18, size.height * 0.58)
      ..lineTo(size.width * 0.36, size.height * 0.68)
      ..lineTo(size.width * 0.52, size.height * 0.5)
      ..lineTo(size.width * 0.72, size.height * 0.64)
      ..lineTo(size.width, size.height * 0.54)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(farMountain, mountainPaint);

    final nearMountain = Paint()
      ..color = Colors.black.withValues(alpha: 0.24)
      ..style = PaintingStyle.fill;
    final nearPath = Path()
      ..moveTo(0, size.height * 0.82)
      ..lineTo(size.width * 0.24, size.height * 0.66)
      ..lineTo(size.width * 0.48, size.height * 0.78)
      ..lineTo(size.width * 0.7, size.height * 0.62)
      ..lineTo(size.width, size.height * 0.74)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(nearPath, nearMountain);

    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    const stars = <Offset>[
      Offset(0.12, 0.18),
      Offset(0.28, 0.1),
      Offset(0.44, 0.16),
      Offset(0.58, 0.08),
      Offset(0.72, 0.14),
      Offset(0.86, 0.2),
      Offset(0.34, 0.28),
      Offset(0.64, 0.24),
    ];
    for (final point in stars) {
      canvas.drawCircle(
        Offset(point.dx * size.width, point.dy * size.height),
        1.6,
        starPaint,
      );
    }

    final moonPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.2),
      10,
      moonPaint,
    );
    final moonCutPaint = Paint()
      ..color = const Color(0xFF0F4F45)
      ..blendMode = BlendMode.srcOver;
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.18),
      9,
      moonCutPaint,
    );

    final shootingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.7, size.height * 0.12),
      Offset(size.width * 0.82, size.height * 0.18),
      shootingPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoalMiniData extends StatelessWidget {
  const _GoalMiniData({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_rounded, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF1F6F54);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.rows});

  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      rows[i].label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1)
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;
}

Color _colorFromHex(String value) {
  final hex = value.replaceAll('#', '');
  final normalized = hex.length == 6 ? 'FF$hex' : hex;
  final intColor = int.tryParse(normalized, radix: 16) ?? 0xFF2F6F5E;
  return Color(intColor);
}
