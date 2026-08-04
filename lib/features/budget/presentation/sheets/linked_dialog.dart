import 'package:flutter/material.dart';

import '../../../wallets/presentation/screens/jar_editor_screen.dart';
import '../../domain/entities/budget_setup_entity.dart';

Future<void> showLinkedWalletDialog(
  BuildContext context, {
  required BudgetSetupEntity budget,
  required LinkedWalletEntity? current,
  required String Function(String prefix) idFactory,
  required Future<void> Function(BudgetSetupEntity budget) onSaveBudget,
}) async {
  if (budget.incomeSources.isEmpty && current == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('يُنصح بإضافة مصدر دخل أولاً لتفعيل التمويل'),
        duration: Duration(seconds: 3),
      ),
    );
  }
  final result = await Navigator.of(context).push<JarEditorResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => JarEditorScreen(
        current: current,
        incomeSources: budget.incomeSources,
        idFactory: idFactory,
      ),
    ),
  );
  if (result == null) {
    return;
  }
  if (result.deleteRequested && current != null) {
    final next =
        budget.linkedWallets.where((e) => e.id != current.id).toList();
    await onSaveBudget(budget.copyWith(linkedWallets: next));
    return;
  }
  final entity = result.entity;
  if (entity == null) {
    return;
  }
  final next = current == null
      ? [...budget.linkedWallets, entity]
      : budget.linkedWallets
          .map((e) => e.id == current.id ? entity : e)
          .toList();
  await onSaveBudget(budget.copyWith(linkedWallets: next));
}
