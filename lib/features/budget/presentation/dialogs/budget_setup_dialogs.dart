import 'package:flutter/material.dart';

Future<bool> showFutureMonthBudgetNoticeDialog(
  BuildContext context, {
  required String displayMonthName,
}) async {
  final switchToCurrentMonth = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('خطة شهر قادم: $displayMonthName'),
      content: const Text(
        'هذه الصفحة خاصة بإعداد شهر قادم وليست للشهر الحالي. يمكنك المتابعة أو التحويل مباشرة إلى إعداد الشهر الحالي.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('خطة الشهر الحالي'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('أوكي'),
        ),
      ],
    ),
  );
  return switchToCurrentMonth == true;
}

Future<String?> showBudgetStartDayTimingDialog(
  BuildContext context, {
  required DateTime now,
  required DateTime currentEnd,
  required DateTime nextCycleStart,
  required int newDay,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('يوم بداية الدورة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أنت حاليًا في منتصف الدورة المحددة.\n\n'
            '• الدورة الحالية: ${now.day}/${now.month} — ${currentEnd.day}/${currentEnd.month}\n'
            '• الدورة الكاملة القادمة تبدأ يوم $newDay/${nextCycleStart.month}',
          ),
          const SizedBox(height: 12),
          const Text(
            'هتبدأ الإعداد ده من النهارده ولا هتطبقه من الدورة الجاية؟',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop('next'),
          child: const Text('من الدورة الجاية'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop('now'),
          child: const Text('من النهارده'),
        ),
      ],
    ),
  );
}
