import 'package:flutter/material.dart';

import '../../../../../core/widgets/app_icon_picker_dialog.dart';

// ---------------------------------------------------------------------------
// Category-add dialog — ported from the original add_transaction_screen.dart
// (_openAddCategoryDialog). Returns a [CategoryDraft] when the user confirms,
// or null when cancelled. Persisting the category is the caller's job (it
// needs the cubit), this dialog only collects name + icon + color.
// ---------------------------------------------------------------------------

/// Draft data collected from the category-add dialog.
class CategoryDraft {
  const CategoryDraft({
    required this.name,
    required this.iconName,
    required this.colorHex,
  });

  final String name;
  final String iconName;
  final String colorHex;
}

Color _parseColor(String hex) {
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  return Color(int.parse(value, radix: 16));
}

/// Shows the "add category" dialog. Returns the collected [CategoryDraft] if
/// confirmed with a non-empty name, otherwise null.
Future<CategoryDraft?> showCategoryAddDialog(
  BuildContext context, {
  required TextEditingController nameController,
}) async {
  nameController.clear();
  var selectedIcon = 'restaurant';
  var selectedColor = '#165b47';

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialog) {
        return AlertDialog(
          title: const Text('إضافة فئة'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('اسم الفئة'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(hintText: 'اكتب اسم الفئة'),
                    onChanged: (_) => setDialog(() {}),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await AppIconPickerDialog.show(
                          context,
                          initialIconName: selectedIcon,
                          initialColorHex: selectedColor,
                          title: 'اختيار أيقونة الفئة',
                          name: nameController.text,
                        );
                        if (picked == null) return;
                        setDialog(() {
                          selectedIcon = picked.iconName;
                          selectedColor = picked.colorHex;
                        });
                      },
                      icon: const Icon(Icons.palette_outlined),
                      label: const Text('اختيار الأيقونة واللون'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _parseColor(selectedColor),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: AppIconPickerDialog.iconWidgetForName(
                              selectedIcon,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(nameController.text.isEmpty
                            ? 'اسم الفئة'
                            : nameController.text),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تم'),
            ),
          ],
        );
      },
    ),
  );

  if (ok != true) return null;
  final name = nameController.text.trim();
  if (name.isEmpty) return null;

  return CategoryDraft(
    name: name,
    iconName: selectedIcon,
    colorHex: selectedColor,
  );
}
