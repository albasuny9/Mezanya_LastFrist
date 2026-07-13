import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../domain/entities/category_entity.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _tab = 'expense';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;
        final sections = _sectionsFor(state);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _typeSwitcher(),
            const SizedBox(height: 16),
            if (sections.isEmpty)
              _emptySetupCard()
            else
              ...sections.map(_sectionCard),
          ],
        );
      },
    );
  }

  List<_SectionData> _sectionsFor(AppStateEntity state) {
    final budget = state.budgetSetup;
    final generalExpense = state.categories
        .where((c) => c.scope == 'expense' && c.incomeSourceId == null)
        .toList();
    final generalIncome =
        state.categories.where((c) => c.scope == 'income').toList();

    if (_tab == 'income') {
      return [
        _SectionData(
          key: 'income',
          title: 'فئات الدخل',
          subtitle: 'كل فئات الدخل هنا عامة وغير مرتبطة بأي مصدر دخل محدد.',
          target: const _CategoryTarget('income', 'income'),
          categories: generalIncome,
          accent: const Color(0xFF4B7F52),
          iconName: 'cash',
        ),
        ...budget.linkedWallets.map(
          (wallet) => _SectionData(
            key: 'linked-${wallet.id}',
            title: wallet.name,
            subtitle: 'فئات إيداع الدخل في الحصالة "${wallet.name}".',
            target: _CategoryTarget('linked-wallet', wallet.id),
            categories:
                wallet.categories.where((c) => c.scope == 'income').toList(),
            accent: _parseColor(wallet.iconColor),
            iconName: wallet.icon,
          ),
        ),
      ];
    }

    return [
      _SectionData(
        key: 'general-expense',
        title: 'الفئات العامة',
        subtitle: 'للمعاملات خارج الميزانية أو غير المرتبطة بمخصص.',
        target: const _CategoryTarget('general-expense', 'general-expense'),
        categories: generalExpense,
        accent: const Color(0xFF8A6B3D),
        iconName: 'category',
      ),
      ...budget.allocations.map(
        (allocation) => _SectionData(
          key: 'allocation-${allocation.id}',
          title: allocation.name,
          subtitle: 'فئات مخصص "${allocation.name}" داخل الميزانية.',
          target: _CategoryTarget('allocation', allocation.id),
          categories: allocation.categories,
          accent: _parseColor(allocation.iconColor),
          iconName: allocation.icon,
        ),
      ),
      ...budget.linkedWallets.map(
        (wallet) => _SectionData(
          key: 'linked-${wallet.id}',
          title: wallet.name,
          subtitle: 'فئات الحصالة أو الحساب المرتبط "${wallet.name}".',
          target: _CategoryTarget('linked-wallet', wallet.id),
          categories:
              wallet.categories.where((c) => c.scope == 'expense').toList(),
          accent: _parseColor(wallet.iconColor),
          iconName: wallet.icon,
        ),
      ),
    ];
  }

  Widget _typeSwitcher() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          _switchTile('expense', 'فئات المصروف', Icons.north_east_rounded),
          const SizedBox(width: 8),
          _switchTile('income', 'فئات الدخل', Icons.south_west_rounded),
        ],
      ),
    );
  }

  Widget _switchTile(String value, String label, IconData icon) {
    final selected = _tab == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = value),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).colorScheme.surface : null,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? const Color(0xFF2F6F5E) : null,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  color: selected ? const Color(0xFF2F6F5E) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(_SectionData section) {
    final theme = Theme.of(context);
    final accent = section.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 5,
            color: accent,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Center(
                        child: AppIconPickerDialog.iconWidgetForName(
                          section.iconName,
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
                            section.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            section.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  height: 1,
                ),
                const SizedBox(height: 14),
                if (section.categories.isEmpty)
                  _emptySection('لا توجد فئات في هذا القسم حتى الآن.')
                else
                  _categoriesGrid(section.target, section.categories),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openCategoryEditor(section.target),
                    icon: Icon(
                      Icons.add_rounded,
                      color: accent,
                      size: 20,
                    ),
                    label: Text(
                      '+ إضافة فئة جديدة',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: accent.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
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

  Widget _categoriesGrid(
    _CategoryTarget target,
    List<CategoryEntity> categories,
  ) {
    final rows = <Widget>[];
    for (var i = 0; i < categories.length; i += 2) {
      final left = categories[i];
      final right = i + 1 < categories.length ? categories[i + 1] : null;
      rows.add(
        Row(
          children: [
            Expanded(child: _categoryCard(target, left)),
            const SizedBox(width: 10),
            Expanded(
              child: right != null
                  ? _categoryCard(target, right)
                  : const SizedBox(),
            ),
          ],
        ),
      );
      if (i + 2 < categories.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }

  Widget _categoryCard(_CategoryTarget target, CategoryEntity category) {
    final color = _parseColor(category.color);
    final stripeColor = Color.lerp(color, Colors.black, 0.22)!;
    final iconColor = Color.lerp(color, Colors.black, 0.18)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openCategoryEditor(target, editing: category),
        onLongPress: () => _confirmDeleteCategory(target, category),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 16,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIconPickerDialog.iconWidgetForName(
                            category.icon,
                            color: iconColor,
                            size: 26,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            category.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Color(0xFF1A1A1A),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 5,
                    color: stripeColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCategory(
    _CategoryTarget target,
    CategoryEntity category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الفئة'),
        content: Text('هل تريد حذف "${category.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _deleteCategory(target, category);
    }
  }

  Widget _emptySection(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _emptySetupCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: const Column(
        children: [
          Icon(Icons.category_outlined, size: 46, color: Color(0xFF2F6F5E)),
          SizedBox(height: 12),
          Text(
            'لا توجد أقسام فئات بعد',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          SizedBox(height: 6),
          Text(
            'ابدأ بإعداد الميزانية الشهرية أو إضافة مصادر دخل ومخصصات حتى تظهر أقسام الفئات هنا.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _openCategoryEditor(
    _CategoryTarget target, {
    CategoryEntity? editing,
  }) async {
    final result = await Navigator.of(context).push<CategoryEntity>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CategoryEditorScreen(
          current: editing,
          scope: _tab,
          target: target,
        ),
      ),
    );
    if (result == null) return;
    await _saveCategory(target, result, editing: editing);
  }

  Future<void> _saveCategory(
    _CategoryTarget target,
    CategoryEntity category, {
    CategoryEntity? editing,
  }) async {
    final state = widget.cubit.state;
    final budget = state.budgetSetup;

    if (target.kind == 'allocation') {
      final allocation =
          budget.allocations.firstWhere((a) => a.id == target.id);
      final next = editing == null
          ? [...allocation.categories, category]
          : allocation.categories
              .map((c) => c.id == editing.id ? category : c)
              .toList();
      await widget.cubit.updateAllocationCategories(
        allocationId: target.id,
        categories: next,
      );
      return;
    }

    if (target.kind == 'linked-wallet') {
      final wallet = budget.linkedWallets.firstWhere((w) => w.id == target.id);
      final next = editing == null
          ? [...wallet.categories, category]
          : wallet.categories
              .map((c) => c.id == editing.id ? category : c)
              .toList();
      await widget.cubit.updateLinkedWalletCategories(
        linkedWalletId: target.id,
        categories: next,
      );
      return;
    }

    final current = state.categories;
    late final List<CategoryEntity> next;
    if (target.kind == 'income') {
      final source = current.where((c) => c.scope == 'income').toList();
      final updated = editing == null
          ? [...source, category]
          : source.map((c) => c.id == editing.id ? category : c).toList();
      final untouched = current.where((c) => c.scope != 'income').toList();
      next = [...untouched, ...updated];
    } else {
      final source = current
          .where((c) => c.scope == 'expense' && c.incomeSourceId == null)
          .toList();
      final updated = editing == null
          ? [...source, category]
          : source.map((c) => c.id == editing.id ? category : c).toList();
      final untouched = current
          .where((c) => !(c.scope == 'expense' && c.incomeSourceId == null))
          .toList();
      next = [...untouched, ...updated];
    }
    await widget.cubit.setCategories(next);
  }

  Future<void> _deleteCategory(
    _CategoryTarget target,
    CategoryEntity category,
  ) async {
    final state = widget.cubit.state;
    final budget = state.budgetSetup;

    if (target.kind == 'allocation') {
      final allocation =
          budget.allocations.firstWhere((a) => a.id == target.id);
      await widget.cubit.updateAllocationCategories(
        allocationId: target.id,
        categories:
            allocation.categories.where((c) => c.id != category.id).toList(),
      );
      return;
    }

    if (target.kind == 'linked-wallet') {
      final wallet = budget.linkedWallets.firstWhere((w) => w.id == target.id);
      await widget.cubit.updateLinkedWalletCategories(
        linkedWalletId: target.id,
        categories:
            wallet.categories.where((c) => c.id != category.id).toList(),
      );
      return;
    }

    await widget.cubit.setCategories(
      state.categories.where((c) => c.id != category.id).toList(),
    );
  }

  Color _parseColor(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | (value ?? 0x165B47));
  }
}

class _CategoryEditorScreen extends StatefulWidget {
  const _CategoryEditorScreen({
    required this.current,
    required this.scope,
    required this.target,
  });

  final CategoryEntity? current;
  final String scope;
  final _CategoryTarget target;

  @override
  State<_CategoryEditorScreen> createState() => _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends State<_CategoryEditorScreen> {
  static const _saveButtonColor = Color(0xFF165B47);

  late final TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.current?.name ?? '');
    if (widget.current == null) {
      final randomAppearance = AppIconPickerDialog.randomAppearance();
      _selectedIcon = randomAppearance.iconName;
      _selectedColor = randomAppearance.colorHex;
    } else {
      _selectedIcon = widget.current!.icon;
      _selectedColor = widget.current!.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final picked = await AppIconPickerDialog.show(
      context,
      initialIconName: _selectedIcon,
      initialColorHex: _selectedColor,
      title: 'اختيار أيقونة الفئة',
      name: _nameController.text,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedIcon = picked.iconName;
      _selectedColor = picked.colorHex;
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب اسم الفئة أولًا.')),
      );
      return;
    }
    Navigator.of(context).pop(
      CategoryEntity(
        id: widget.current?.id ??
            'cat-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        icon: _selectedIcon,
        color: _selectedColor,
        scope: widget.scope,
        allocationId:
            widget.target.kind == 'allocation' ? widget.target.id : null,
        walletId:
            widget.target.kind == 'linked-wallet' ? widget.target.id : null,
        incomeSourceId: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _parseColor(_selectedColor);
    final isNew = widget.current == null;
    final previewName = _nameController.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF1),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEDE6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFF555550),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isNew ? 'فئة جديدة' : 'تعديل الفئة',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: _saveButtonColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isNew ? Icons.add_rounded : Icons.check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isNew ? 'إضافة الفئة' : 'حفظ التعديلات',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE8E6DE)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: AppIconPickerDialog.iconWidgetForName(
                  _selectedIcon,
                  color: accent,
                  size: 44,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              previewName.isEmpty ? 'اسم الفئة' : previewName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE0DED6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اسم الفئة',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF888880),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'مثل: مطاعم، مواصلات...',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFBBBBB5),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: _pickIcon,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE0DED6)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: AppIconPickerDialog.iconWidgetForName(
                          _selectedIcon,
                          color: accent,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'الأيقونة واللون',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEDE6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        size: 20,
                        color: Color(0xFF666660),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | (value ?? 0x2F6F5E));
  }
}

class _CategoryTarget {
  const _CategoryTarget(this.kind, this.id);

  final String kind;
  final String id;
}

class _SectionData {
  const _SectionData({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.target,
    required this.categories,
    required this.accent,
    required this.iconName,
  });

  final String key;
  final String title;
  final String subtitle;
  final _CategoryTarget target;
  final List<CategoryEntity> categories;
  final Color accent;
  final String iconName;
}
