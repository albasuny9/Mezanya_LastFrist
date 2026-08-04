import 'package:flutter/material.dart';

enum BudgetDetailsBlockSize { narrow, wide }

class BudgetDetailsBlock {
  const BudgetDetailsBlock(this.size, this.label, this.value);

  final BudgetDetailsBlockSize size;
  final String label;
  final String value;

  static BudgetDetailsBlock narrow(String label, String value) =>
      BudgetDetailsBlock(BudgetDetailsBlockSize.narrow, label, value);

  static BudgetDetailsBlock wide(String label, String value) =>
      BudgetDetailsBlock(BudgetDetailsBlockSize.wide, label, value);
}

class BudgetDetailsBlocks extends StatelessWidget {
  const BudgetDetailsBlocks({
    super.key,
    required this.blocks,
  });

  final List<BudgetDetailsBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const spacing = 10.0;

        double itemWidth() {
          return ((w - spacing) / 2).clamp(140.0, w);
        }

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final block in blocks)
              SizedBox(
                width: itemWidth(),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        block.value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.15,
                          fontSize: 12.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
