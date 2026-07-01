import 'package:flutter/material.dart';

const Color kNotificationConfirmColor = Color(0xFF165B47);
const Color kNotificationTitleColor = Color(0xFF1C1C1C);
const Color kNotificationAmountColor = Color(0xFF1C1C1C);
const Color kNotificationCurrencyColor = Color(0xFF9A9A9A);
const Color kNotificationPostponeColor = Color(0xFF4A4A4A);

Color notificationAccentFromHex(String hex) {
  final normalized = hex.replaceAll('#', '').trim();
  if (normalized.length == 6) {
    return Color(int.parse('FF$normalized', radix: 16));
  }
  return const Color(0xFF165B47);
}

class NotificationsTabSelector extends StatelessWidget {
  const NotificationsTabSelector({
    super.key,
    required this.selectedTab,
    required this.pendingCount,
    required this.historyCount,
    required this.onTabChanged,
  });

  final String selectedTab;
  final int pendingCount;
  final int historyCount;
  final ValueChanged<String> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabTile(
              selected: selectedTab == 'new',
              title: 'التنبيهات',
              icon: Icons.notifications_active_rounded,
              onTap: () => onTabChanged('new'),
            ),
          ),
          Expanded(
            child: _TabTile(
              selected: selectedTab == 'history',
              title: 'السجل',
              icon: Icons.history_rounded,
              onTap: () => onTabChanged('history'),
            ),
          ),
        ],
      ),
    );
  }
}

class PendingNotificationCard extends StatelessWidget {
  const PendingNotificationCard({
    super.key,
    required this.accent,
    required this.title,
    required this.amount,
    required this.icon,
    required this.onConfirm,
    required this.onPostpone,
    this.confirmLabel = 'تأكيد',
    this.confirmEnabled = true,
    this.showPostpone = true,
  });

  final Color accent;
  final String title;
  final double amount;
  final Widget icon;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final VoidCallback onPostpone;
  final bool confirmEnabled;
  final bool showPostpone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountLabel = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5,
                    color: accent,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(width: 44, height: 44, child: icon),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: kNotificationTitleColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                height: 1.2,
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 42,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.55),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                amountLabel,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: kNotificationAmountColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'جنيه',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: kNotificationCurrencyColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: FilledButton.icon(
                      onPressed: confirmEnabled ? onConfirm : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        backgroundColor: kNotificationConfirmColor,
                        disabledBackgroundColor:
                            kNotificationConfirmColor.withValues(alpha: 0.45),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(confirmLabel),
                    ),
                  ),
                  if (showPostpone) ...[
                    const SizedBox(width: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onPostpone,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 17,
                              color: kNotificationPostponeColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'تأجيل',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: kNotificationPostponeColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class NotificationHistoryCard extends StatelessWidget {
  const NotificationHistoryCard({
    super.key,
    required this.title,
    required this.timeLabel,
    required this.amountValue,
    required this.accent,
    required this.icon,
    required this.onOpen,
  });

  final String title;
  final String timeLabel;
  final String amountValue;
  final Color accent;
  final Widget icon;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAmount = amountValue.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                      child: Row(
                        children: [
                          SizedBox(width: 42, height: 42, child: icon),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: kNotificationTitleColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: kNotificationCurrencyColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (hasAmount) ...[
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  amountValue,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: kNotificationConfirmColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'جنيه',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: kNotificationCurrencyColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationHistoryFilterBar extends StatelessWidget {
  const NotificationHistoryFilterBar({
    super.key,
    required this.categoryLabel,
    required this.durationLabel,
    required this.categoryOptions,
    required this.durationOptions,
    required this.onCategorySelected,
    required this.onDurationSelected,
  });

  final String categoryLabel;
  final String durationLabel;
  final List<String> categoryOptions;
  final List<String> durationOptions;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onDurationSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: Row(
        children: [
          _HistoryFilterChip(
            label: durationLabel,
            onSelected: onDurationSelected,
            options: durationOptions,
            showTrailingIcon: false,
          ),
          const Spacer(),
          _HistoryFilterChip(
            label: categoryLabel,
            onSelected: onCategorySelected,
            options: categoryOptions,
            showTrailingIcon: true,
          ),
        ],
      ),
    );
  }
}

class NotificationHistoryDateHeader extends StatelessWidget {
  const NotificationHistoryDateHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: lineColor, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(child: Divider(color: lineColor, thickness: 1)),
        ],
      ),
    );
  }
}

class _HistoryFilterChip extends StatelessWidget {
  const _HistoryFilterChip({
    required this.label,
    required this.options,
    required this.onSelected,
    this.showTrailingIcon = true,
  });

  final String label;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final bool showTrailingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<String>(
      onSelected: onSelected,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) => options
          .map(
            (option) => PopupMenuItem<String>(
              value: option,
              child: Text(
                option,
                style: TextStyle(
                  fontWeight: option == label ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (showTrailingIcon) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabTile extends StatelessWidget {
  const _TabTile({
    required this.selected,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = Color(0xFF165B47);

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? accent : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? accent : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: selected ? accent : theme.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
