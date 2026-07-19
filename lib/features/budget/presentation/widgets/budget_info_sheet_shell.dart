import 'package:flutter/material.dart';

import 'budget_details_blocks.dart';

Future<void> showBudgetInfoSheet({
  required BuildContext context,
  required String title,
  required List<BudgetDetailsBlock> blocks,
  required String editLabel,
  required VoidCallback onEdit,
  double heightFactor = 0.55,
  double minHeight = 380,
  double maxHeight = 520,
  List<Widget>? extraActions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) {
      final height = MediaQuery.of(sheetCtx).size.height * heightFactor;
      return SizedBox(
        height: height.clamp(minHeight, maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  title,
                  style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(sheetCtx).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(sheetCtx)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      BudgetDetailsBlocks(blocks: blocks),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    onEdit();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(editLabel),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
              if (extraActions != null) ...extraActions,
            ],
          ),
        ),
      );
    },
  );
}
