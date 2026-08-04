import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../domain/entities/budget_setup_entity.dart';

Future<AllocationEditorResult?> openAllocationEditorScreen(
  BuildContext context, {
  AllocationEntity? current,
  required List<IncomeSourceEntity> incomeSources,
  required String Function(String prefix) idFactory,
}) {
  return Navigator.of(context).push<AllocationEditorResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _AllocationEditorScreen(
        current: current,
        incomeSources: incomeSources,
        idFactory: idFactory,
      ),
    ),
  );
}

class AllocationEditorResult {
  const AllocationEditorResult({
    this.entity,
    this.deleteRequested = false,
  });

  final AllocationEntity? entity;
  final bool deleteRequested;
}

class _AllocationEditorScreen extends StatefulWidget {
  const _AllocationEditorScreen({
    required this.current,
    required this.incomeSources,
    required this.idFactory,
  });

  final AllocationEntity? current;
  final List<IncomeSourceEntity> incomeSources;
  final String Function(String prefix) idFactory;

  @override
  State<_AllocationEditorScreen> createState() =>
      _AllocationEditorScreenState();
}

class _AllocationEditorScreenState extends State<_AllocationEditorScreen> {
  late final TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColor;
  late String _rolloverBehavior;
  late List<AllocationFundingEntity> _funding;

  bool get _canDelete => widget.current != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.current?.name ?? '');
    _selectedIcon = widget.current?.icon ?? _randomAllocationIcon();
    _selectedColor = widget.current?.iconColor ?? _randomHexColor();
    _rolloverBehavior =
        widget.current?.rolloverBehavior ?? RolloverBehavior.toSavings.value;
    _funding = List<AllocationFundingEntity>.from(
      widget.current?.funding ??
          [
            AllocationFundingEntity(
              id: widget.idFactory('fund'),
              incomeSourceId: _defaultIncomeSourceId(),
              plannedAmount: 0,
            ),
          ],
    );
  }

  /// أعلى مصدر دخل ثابت (غير متغيّر) بالقيمة — أو فاضي لو مفيش مصادر ثابتة
  String _defaultIncomeSourceId() {
    final fixedSources =
        widget.incomeSources.where((s) => !s.isVariable).toList();
    if (fixedSources.isEmpty) return '';
    fixedSources.sort((a, b) => b.amount.compareTo(a.amount));
    return fixedSources.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// أيقونة عشوائية مناسبة لفئات الميزانية (أكل، مواصلات، بيت، تسوق...)
  static String _randomAllocationIcon() {
    const icons = [
      'restaurant',
      'local_cafe',
      'fastfood',
      'car',
      'bus',
      'taxi',
      'bike',
      'home',
      'bed',
      'kitchen',
      'cleaning',
      'shopping_cart',
      'shopping_bag',
      'checkroom',
      'favorite',
      'fitness',
      'medication',
      'movie',
      'music',
      'sports',
      'work',
      'school',
      'pets',
      'card_giftcard',
    ];
    return icons[Random().nextInt(icons.length)];
  }

  /// لون عشوائي حقيقي (HSV) بنفس أسلوب المحافظ والحصالات
  static String _randomHexColor() {
    final rnd = Random();
    final h = rnd.nextDouble();
    final s = 0.55 + rnd.nextDouble() * 0.30;
    final v = 0.35 + rnd.nextDouble() * 0.30;
    final i = (h * 6).floor();
    final f = h * 6 - i;
    final p = v * (1 - s);
    final q = v * (1 - f * s);
    final t = v * (1 - (1 - f) * s);
    double r, g, b;
    switch (i % 6) {
      case 0:
        r = v;
        g = t;
        b = p;
        break;
      case 1:
        r = q;
        g = v;
        b = p;
        break;
      case 2:
        r = p;
        g = v;
        b = t;
        break;
      case 3:
        r = p;
        g = q;
        b = v;
        break;
      case 4:
        r = t;
        g = p;
        b = v;
        break;
      default:
        r = v;
        g = p;
        b = q;
        break;
    }
    final ri = (r * 255).round();
    final gi = (g * 255).round();
    final bi = (b * 255).round();
    return '#${ri.toRadixString(16).padLeft(2, '0')}'
        '${gi.toRadixString(16).padLeft(2, '0')}'
        '${bi.toRadixString(16).padLeft(2, '0')}';
  }

  String? incomeSourceId;
  double get _totalPlanned => _funding.fold<double>(
        0,
        (sum, item) => sum + item.plannedAmount,
      );

  Future<void> _pickIcon() async {
    final picked = await AppIconPickerDialog.show(
      context,
      initialIconName: _selectedIcon,
      initialColorHex: _selectedColor,
      title: 'اختيار أيقونة المخصص',
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
        AllocationFundingEntity(
          id: widget.idFactory('fund'),
          incomeSourceId: incomeSourceId ?? _defaultIncomeSourceId(),
          plannedAmount: 0,
        ),
      ];
    });
  }

  void _updateFundingSource(String id,
      {String? incomeSourceId, double? amount}) {
    setState(() {
      _funding = _funding
          .map(
            (item) => item.id == id
                ? AllocationFundingEntity(
                    id: item.id,
                    incomeSourceId: incomeSourceId ?? item.incomeSourceId,
                    plannedAmount: amount ?? item.plannedAmount,
                  )
                : item,
          )
          .toList();
    });
  }

  Future<void> _removeFundingSource(String id) async {
    if (_funding.length == 1) {
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مصدر التمويل'),
        content: const Text(
            'سيتم حذف مصدر التمويل من هذا المخصص. هل تريد المتابعة؟'),
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

  void _save() {
    final name = _nameController.text.trim();
    final cleaned = _funding
        .where(
            (item) => item.incomeSourceId.isNotEmpty && item.plannedAmount > 0)
        .toList();
    if (name.isEmpty) {
      _showMessage('اكتب اسمًا واضحًا للمخصص أولًا.');
      return;
    }
    if (cleaned.isEmpty) {
      _showMessage('أضف مصدر تمويل واحدًا على الأقل بقيمة أكبر من صفر.');
      return;
    }
    Navigator.of(context).pop(
      AllocationEditorResult(
        entity: AllocationEntity(
          id: widget.current?.id ?? widget.idFactory('alloc'),
          name: name,
          icon: _selectedIcon,
          iconColor: _selectedColor,
          rolloverBehavior: _rolloverBehavior,
          funding: cleaned,
          categories: widget.current?.categories ?? const [],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    if (!_canDelete) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المخصص'),
        content: const Text(
            'سيتم حذف هذا المخصص من خطة الميزانية. هل تريد المتابعة؟'),
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
    Navigator.of(context)
        .pop(const AllocationEditorResult(deleteRequested: true));
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.current == null ? 'إضافة مخصص' : 'تعديل المخصص'),
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
              widget.current == null ? 'إضافة المخصص' : 'حفظ التعديلات',
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
                            ? 'مخصص جديد'
                            : _nameController.text.trim(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _rolloverBehavior == RolloverBehavior.keep.value
                            ? 'المتبقي يرحل إلى الشهر التالي'
                            : 'المتبقي يتحول إلى التوفير',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'إجمالي التمويل ${_totalPlanned.toStringAsFixed(2)}',
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
          _EditorSection(
            title: 'البيانات الأساسية',
            subtitle: 'سمِّ المخصص واختر له أيقونة واضحة يسهل تمييزها.',
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المخصص',
                    hintText: 'مثل: البيت أو المواصلات أو المصروف اليومي',
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
                                'غيّر شكل المخصص ليظهر بوضوح في شاشة المتابعة.',
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
            title: 'المتبقي آخر الدورة',
            subtitle: 'اختر كيف تريد التعامل مع الرصيد المتبقي من هذا المخصص.',
            child: Column(
              children: [
                _ChoiceTile(
                  title: 'يرحل إلى الشهر التالي',
                  subtitle:
                      'يبقى المبلغ المتبقي داخل نفس المخصص في الدورة الجديدة.',
                  selected: _rolloverBehavior == RolloverBehavior.keep.value,
                  onTap: () => setState(
                      () => _rolloverBehavior = RolloverBehavior.keep.value),
                ),
                const SizedBox(height: 10),
                _ChoiceTile(
                  title: 'يتحول إلى التوفير',
                  subtitle: 'ينتقل المتبقي تلقائيًا إلى التوفير بدل ترحيله.',
                  selected:
                      _rolloverBehavior == RolloverBehavior.toSavings.value,
                  onTap: () => setState(() =>
                      _rolloverBehavior = RolloverBehavior.toSavings.value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _EditorSection(
            title: 'مصادر التمويل',
            subtitle: 'وزّع قيمة هذا المخصص على دخل واحد أو أكثر.',
            trailing: TextButton.icon(
              onPressed: _addFundingSource,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة مصدر'),
            ),
            child: Column(
              children: _funding
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FundingCard(
                        item: item,
                        incomeSources: widget.incomeSources,
                        canDelete: _funding.length > 1,
                        onChanged: ({String? incomeSourceId, double? amount}) {
                          _updateFundingSource(
                            item.id,
                            incomeSourceId: incomeSourceId,
                            amount: amount,
                          );
                        },
                        onDelete: () => _removeFundingSource(item.id),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_canDelete) ...[
            const SizedBox(height: 14),
            _EditorSection(
              title: 'إدارة المخصص',
              subtitle:
                  'يمكنك حذف المخصص من هنا بدل جعل الحذف سهل الوصول بالخطأ.',
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف المخصص'),
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

class _EditorSection extends StatelessWidget {
  const _EditorSection({
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

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF0E5A47).withValues(alpha: 0.10)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.26),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF0E5A47)
                : colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
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
            const SizedBox(width: 12),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? const Color(0xFF0E5A47)
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _FundingCard extends StatelessWidget {
  const _FundingCard({
    required this.item,
    required this.incomeSources,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  final AllocationFundingEntity item;
  final List<IncomeSourceEntity> incomeSources;
  final bool canDelete;
  final void Function({String? incomeSourceId, double? amount}) onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isValid = incomeSources.any((e) => e.id == item.incomeSourceId);
    final selectedSource =
        isValid ? incomeSources.firstWhere((e) => e.id == item.incomeSourceId) : null;
    final sourceIcon = selectedSource == null
        ? Icons.help_outline_rounded
        : (selectedSource.isVariable
            ? Icons.trending_up_rounded
            : Icons.account_balance_wallet_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── الصف الأول: أيقونة + اسم المصدر (مساحة كاملة) + حذف ──
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E5A47).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(sourceIcon, size: 16, color: const Color(0xFF0E5A47)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<String>(
                    value: isValid ? item.incomeSourceId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    hint: const Text('اختر مصدر الدخل',
                        overflow: TextOverflow.ellipsis),
                    items: incomeSources
                        .map(
                          (income) => DropdownMenuItem(
                            value: income.id,
                            child: Text(income.name,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      onChanged(incomeSourceId: value);
                    },
                  ),
                ),
              ),
              IconButton(
                onPressed: canDelete ? onDelete : null,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'حذف هذا المصدر',
                visualDensity: VisualDensity.compact,
                color: canDelete
                    ? const Color(0xFFC62828)
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // ── الصف الثاني: المبلغ المخصص (سطر مستقل، مساحة كافية) ──
          Padding(
            padding: const EdgeInsets.only(right: 42),
            child: TextFormField(
              initialValue: item.plannedAmount == 0
                  ? ''
                  : item.plannedAmount.toStringAsFixed(0),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'المبلغ المخصص',
                suffixText: 'ج.م',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  onChanged(amount: double.tryParse(value) ?? 0),
            ),
          ),
        ],
      ),
    );
  }
}

Color _colorFromHex(String value) {
  final hex = value.replaceAll('#', '');
  final normalized = hex.length == 6 ? 'FF$hex' : hex;
  final intColor = int.tryParse(normalized, radix: 16) ?? 0xFF165B47;
  return Color(intColor);
}
