import 'package:flutter/material.dart';
import 'package:mezanya_app/core/theme/app_theme.dart';

class MainShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MainShellAppBar({
    super.key,
    required this.todayLabelFuture,
    required this.pendingNotifications,
    required this.onOpenNotifications,
  });

  final Future<String> todayLabelFuture;
  final int pendingNotifications;
  final VoidCallback onOpenNotifications;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 12,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            child: Icon(
              Icons.insights_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          const Text('الميزانية'),
          const Spacer(),
          FutureBuilder<String>(
            future: todayLabelFuture,
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? '',
                style: AppTheme.dateTextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'الإشعارات',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded),
              if (pendingNotifications > 0)
                PositionedDirectional(
                  top: -6,
                  end: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    child: Text(
                      pendingNotifications > 99
                          ? '99+'
                          : pendingNotifications.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: onOpenNotifications,
        ),
      ],
    );
  }
}
