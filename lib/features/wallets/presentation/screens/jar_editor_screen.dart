import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';

class JarEditorResult {
  const JarEditorResult({
    this.entity,
    this.deleteRequested = false,
  });

  final LinkedWalletEntity? entity;
  final bool deleteRequested;
}

class JarEditorScreen extends StatefulWidget {
  const JarEditorScreen({
    super.key,
    this.current,
    required this.incomeSources,
    required this.idFactory,
  });

  final LinkedWalletEntity? current;
  final List<IncomeSourceEntity> incomeSources;
  final String Function(String prefix) idFactory;

  @override
  State<JarEditorScreen> createState() => _JarEditorScreenState();
}

class _JarEditorScreenState extends State<JarEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _dayController;
  late String _selectedIcon;
  late String _selectedColor;
  late String _automationType;
  late List<LinkedWalletEntityFunding> _funding;

  bool get _isDefaultJar => widget.current?.id == 'linked-savings-default';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.current?.name ?? '');
    _dayController = TextEditingController(
      text: (widget.current?.executionDay ?? 1).toString(),
    );
    // لو حصالة جديدة — اختار لون وأيقونة عشوائية من الباليت
    const jarPalette = [
      ('#D97706', 'monetization_on'),
      ('#0F766E', 'savings'),
      ('#7C3AED', 'diamond'),
      ('#BE185D', 'star'),
      ('#0369A1', 'wb_sunny'),
      ('#4D7C0F', 'eco'),
      ('#B45309', 'local_fire_department'),
      ('#1D4ED8', 'flight_takeoff'),
    ];
    final rnd = DateTime.now().microsecond % jarPalette.length;
    _selectedIcon = widget.current?.icon ?? jarPalette[rnd].$2;
    _selectedColor = widget.current?.iconColor ?? jarPalette[rnd].$1;
    _automationType =
        widget.current?.automationType ?? AutomationType.confirm.value;
    _funding = List<LinkedWalletEntityFunding>.from(
      widget.current?.funding ?? [],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  double get _monthlyAmount => _funding.fold<double>(
        0,
        (sum, item) => sum + item.plannedAmount,
      );

  Future<void> _pickIcon() async {
    final picked = await AppIconPickerDialog.show(
      context,
      initialIconName: _selectedIcon,
      initialColorHex: _selectedColor,
      title: 'اختيار أيقونة الحصالة',
      name: _nameController.text,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedIcon = picked.iconName;
      _selectedColor = picked.colorHex;
    });
  }

  void _addFundingSource() {
    setState(() {
      _funding = [
        ..._funding,
        LinkedWalletEntityFunding(
          id: widget.idFactory('fund'),
          incomeSourceId: widget.incomeSources.isNotEmpty
              ? widget.incomeSources.first.id
              : '',
          plannedAmount: 0,
        ),
      ];
    });
  }

  void _updateFunding(String id,
      {String? incomeSourceId, double? amount, bool? isPhysical}) {
    setState(() {
      _funding = _funding
          .map(
            (item) => item.id == id
                ? LinkedWalletEntityFunding(
                    id: item.id,
                    incomeSourceId: incomeSourceId ?? item.incomeSourceId,
                    plannedAmount: amount ?? item.plannedAmount,
                    isPhysical: isPhysical ?? item.isPhysical,
                  )
                : item,
          )
          .toList();
    });
  }

  Future<void> _removeFunding(String id) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مصدر التمويل'),
        content: const Text(
            'سيتم حذف مصدر التمويل من هذه الحصالة. هل تريد المتابعة؟'),
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
    if (approved != true || !mounted) {
      return;
    }
    setState(() {
      _funding = _funding.where((item) => item.id != id).toList();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _save() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showMessage('اكتب اسمًا واضحًا للحصالة أولًا.');
      return;
    }

    final cleanedFunding = _funding
        .where(
          (item) => item.incomeSourceId.isNotEmpty && item.plannedAmount > 0,
        )
        .toList();

    final day = (int.tryParse(_dayController.text.trim()) ?? 1).clamp(1, 28);

    final entity = LinkedWalletEntity(
      id: widget.current?.id ?? widget.idFactory('linked'),
      name: name,
      balance: widget.current?.balance ?? 0,
      monthlyAmount: cleanedFunding.fold(
        0,
        (sum, item) => sum + item.plannedAmount,
      ),
      executionDay: day,
      fundingSource:
          cleanedFunding.isNotEmpty ? cleanedFunding.first.incomeSourceId : '',
      funding: cleanedFunding,
      icon: _selectedIcon,
      iconColor: _selectedColor,
      automationType: _automationType,
      categories: widget.current?.categories ?? const [],
    );

    Navigator.of(context).pop(
      JarEditorResult(entity: entity),
    );
  }

  Future<void> _requestDeleteJar() async {
    if (_isDefaultJar) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الحصالة'),
        content:
            const Text('سيتم حذف الحصالة من خطة الميزانية. هل تريد المتابعة؟'),
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
    Navigator.of(context).pop(const JarEditorResult(deleteRequested: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = _colorFromHex(_selectedColor);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.current == null ? 'إضافة حصالة' : 'تعديل الحصالة'),
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
                widget.current == null ? 'إضافة الحصالة' : 'حفظ التعديلات'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.95),
                  accent.withValues(alpha: 0.72),
                ],
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
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: AppIconPickerDialog.iconWidgetForName(
                      _selectedIcon,
                      color: Colors.white,
                      size: 30,
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
                            ? 'حصالة جديدة'
                            : _nameController.text.trim(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الرصيد الحالي ${(widget.current?.balance ?? 0).toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'التمويل الشهري ${_monthlyAmount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _JarEditorSection(
            title: 'البيانات الأساسية',
            subtitle:
                'حدد اسم الحصالة وشكلها. الرصيد الفعلي يأتي من التخصيصات والتحويلات وليس من كتابة رقم يدوي.',
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الحصالة',
                    hintText: 'مثل: السفر أو الطوارئ أو التعليم',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.30,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الرصيد الحالي',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (widget.current?.balance ?? 0).toStringAsFixed(2),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'يتغير هذا الرقم من التخصيصات الفعلية والتحويل الداخلي، وليس من هذه الشاشة.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
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
                              size: 26,
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
                                'اجعل الحصالة أوضح في الشاشات والقوائم.',
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
          _JarEditorSection(
            title: 'إعداد التنفيذ',
            subtitle: 'حدد طريقة تحويل المبلغ الشهري إلى هذه الحصالة.',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _automationType,
                  decoration: const InputDecoration(
                    labelText: 'نوع التنفيذ',
                  ),
                  items: [
                    DropdownMenuItem(
                        value: AutomationType.auto.value,
                        child: Text('تلقائي')),
                    DropdownMenuItem(
                        value: AutomationType.confirm.value,
                        child: Text('يحتاج تأكيد')),
                    DropdownMenuItem(
                        value: AutomationType.manual.value,
                        child: Text('يدوي')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _automationType = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'يوم التحويل الشهري',
                    hintText: 'اختر يومًا من 1 إلى 28',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _JarEditorSection(
            title: 'مصادر التمويل',
            subtitle: widget.incomeSources.isEmpty
                ? 'أضف دخلًا داخل الميزانية أولًا حتى تربط به تمويل الحصالة.'
                : 'وزّع قيمة التحويل الشهري على دخل واحد أو أكثر.',
            trailing: widget.incomeSources.isEmpty
                ? null
                : TextButton.icon(
                    onPressed: _addFundingSource,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة مصدر'),
                  ),
            child: widget.incomeSources.isEmpty
                ? const _JarEmptyState(
                    message:
                        'لا توجد مصادر دخل متاحة الآن لربط تمويل الحصالة بها.',
                  )
                : Column(
                    children: [
                      if (_funding.isEmpty)
                        const _JarEmptyState(
                          message:
                              'لا يوجد مصدر تمويل مضاف. يمكنك إضافة واحد للربط بالميزانية الشهرية، أو حفظ الحصالة بدون تمويل.',
                        )
                      else
                        ..._funding.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _JarFundingCard(
                              item: item,
                              incomeSources: widget.incomeSources,
                              canDelete: true,
                              onChanged: ({
                                String? incomeSourceId,
                                double? amount,
                                bool? isPhysical,
                              }) {
                                _updateFunding(
                                  item.id,
                                  incomeSourceId: incomeSourceId,
                                  amount: amount,
                                  isPhysical: isPhysical,
                                );
                              },
                              onDelete: () => _removeFunding(item.id),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          if (widget.current != null) ...[
            const SizedBox(height: 14),
            _JarEditorSection(
              title: 'إدارة الحصالة',
              subtitle:
                  'يمكنك حذف الحصالة من هنا بدل جعل الحذف سهل الوصول بالخطأ.',
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _isDefaultJar ? null : _requestDeleteJar,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    _isDefaultJar
                        ? 'حصالة افتراضية غير قابلة للحذف'
                        : 'حذف الحصالة',
                  ),
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
}

class _JarEditorSection extends StatelessWidget {
  const _JarEditorSection({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

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
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _JarFundingCard extends StatelessWidget {
  const _JarFundingCard({
    required this.item,
    required this.incomeSources,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  final LinkedWalletEntityFunding item;
  final List<IncomeSourceEntity> incomeSources;
  final bool canDelete;
  final void Function(
      {String? incomeSourceId, double? amount, bool? isPhysical}) onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isValidValue = incomeSources.any(
      (income) => income.id == item.incomeSourceId,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: isValidValue ? item.incomeSourceId : null,
            decoration: const InputDecoration(
              labelText: 'مصدر الدخل',
            ),
            items: incomeSources
                .map(
                  (income) => DropdownMenuItem<String>(
                    value: income.id,
                    child: Text(income.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              onChanged(incomeSourceId: value);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: item.plannedAmount == 0
                ? ''
                : item.plannedAmount.toStringAsFixed(0),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'المبلغ الشهري',
              hintText: 'اكتب القيمة التي ستتحول شهريًا',
            ),
            onChanged: (value) =>
                onChanged(amount: double.tryParse(value) ?? 0),
          ),
          const SizedBox(height: 12),
          // ── سويتش: خصم فعلي من المحفظة ─────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: item.isPhysical
                  ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: item.isPhysical
                    ? colorScheme.primary.withValues(alpha: 0.4)
                    : colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item.isPhysical
                      ? Icons.account_balance_wallet_rounded
                      : Icons.bookmark_outline_rounded,
                  size: 20,
                  color: item.isPhysical
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.isPhysical
                            ? 'خصم فعلي من المحفظة'
                            : 'تخصيص افتراضي فقط',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: item.isPhysical
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        item.isPhysical
                            ? 'المبلغ يُخصم من المحفظة عند توزيع الراتب'
                            : 'المبلغ يُحجز افتراضياً بدون خصم من المحفظة',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: item.isPhysical,
                  onChanged: (v) => onChanged(isPhysical: v),
                  activeColor: colorScheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: canDelete ? onDelete : null,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('حذف هذا المصدر'),
            ),
          ),
        ],
      ),
    );
  }
}

class _JarEmptyState extends StatelessWidget {
  const _JarEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

Color _colorFromHex(String value) {
  final hex = value.replaceAll('#', '');
  final normalized = hex.length == 6 ? 'FF$hex' : hex;
  final intColor = int.tryParse(normalized, radix: 16) ?? 0xFF0F766E;
  return Color(intColor);
}
