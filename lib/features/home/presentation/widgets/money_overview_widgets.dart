import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:flutter/material.dart';

import '../../../transactions/domain/entities/transaction_entity.dart';

class MoneyMonthSelectorCard extends StatelessWidget {
  const MoneyMonthSelectorCard({
    super.key,
    required this.label,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final String label;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              onPressed: onPreviousMonth,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              onPressed: onNextMonth,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class MoneySummaryCard extends StatelessWidget {
  const MoneySummaryCard({
    super.key,
    required this.currencyCode,
    required this.totalWalletBalances,
    required this.netIncome,
    required this.netExpense,
  });

  final String currencyCode;
  final double totalWalletBalances;
  final double netIncome;
  final double netExpense;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF1C6D25), Color(0xFF096119)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x201C6D25),
            blurRadius: 40,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إجمالي المحافظ',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${totalWalletBalances.toStringAsFixed(2)} $currencyCode',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MoneySummaryMetric(
                    title: 'صافي دخل الشهر',
                    value: netIncome,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MoneySummaryMetric(
                    title: 'صافي مصروف الشهر',
                    value: netExpense,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneySummaryMetric extends StatelessWidget {
  const _MoneySummaryMetric({
    required this.title,
    required this.value,
  });

  final String title;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class MoneyDashboardSection extends StatelessWidget {
  const MoneyDashboardSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onMore,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Expanded(child: child),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onMore,
                  child: const Text('المزيد'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MoneySectionEmptyState extends StatelessWidget {
  const MoneySectionEmptyState({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text),
    );
  }
}

class MoneyTransactionTile extends StatelessWidget {
  const MoneyTransactionTile({
    super.key,
    required this.transaction,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final TransactionEntity transaction;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNegative = transaction.type == TransactionType.expense.value ||
        transaction.transferType ==
            TransferType.jarBalanceAdjustmentDecrease.value;
    return ListTile(
      dense: true,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        '${isNegative ? '-' : '+'}${transaction.amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isNegative
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
      ),
      onTap: onTap,
    );
  }
}

class MoneyChartPreview extends StatelessWidget {
  const MoneyChartPreview({
    super.key,
    required this.transactions,
  });

  final List<TransactionEntity> transactions;

  @override
  Widget build(BuildContext context) {
    final income = transactions
        .where(
            (transaction) => transaction.type == TransactionType.income.value)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final expense = transactions
        .where(
            (transaction) => transaction.type == TransactionType.expense.value)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final transfer = transactions
        .where(
            (transaction) => transaction.type == TransactionType.transfer.value)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final maxValue = [income, expense, transfer]
        .fold<double>(1, (max, value) => value > max ? value : max);

    return Column(
      children: [
        _MoneyChartBar(
          label: 'دخل',
          value: income,
          maxValue: maxValue,
          color: const Color(0xFF16A34A),
        ),
        _MoneyChartBar(
          label: 'مصروف',
          value: expense,
          maxValue: maxValue,
          color: const Color(0xFFDC2626),
        ),
        _MoneyChartBar(
          label: 'تحويل',
          value: transfer,
          maxValue: maxValue,
          color: const Color(0xFF2563EB),
        ),
      ],
    );
  }
}

class _MoneyChartBar extends StatelessWidget {
  const _MoneyChartBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final double value;
  final double maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 55, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 11,
                color: color,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.1),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              value.toStringAsFixed(2),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
