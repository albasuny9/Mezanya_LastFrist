part of 'app_cubit.dart';

mixin AppCubitGoalsMixin on AppCubitBase {
  Future<void> addGoal({
    required String name,
    required double targetAmount,
    required DateTime startDate,
    required DateTime endDate,
    String icon = 'savings',
    String iconColor = '#2f6f5e',
    String? notes,
  }) async {
    final goal = GoalEntity(
      id: _id('goal'),
      name: name,
      targetAmount: targetAmount,
      startDate: startDate,
      endDate: endDate,
      icon: icon,
      iconColor: iconColor,
      notes: notes,
    );
    final next = state.copyWith(goals: [...state.goals, goal]);
    await _applyAndLog(
      action: 'add',
      entityType: 'goal',
      entityId: goal.id,
      details: 'تمت إضافة هدف: $name',
      apply: () async => next,
    );
  }

  Future<void> updateGoal(GoalEntity goal) async {
    final next = state.copyWith(
      goals:
          state.goals.map((item) => item.id == goal.id ? goal : item).toList(),
    );
    await _applyAndLog(
      action: 'edit',
      entityType: 'goal',
      entityId: goal.id,
      details: 'تم تعديل هدف',
      apply: () async => next,
    );
  }

  Future<void> deleteGoal(String id) async {
    final next = state.copyWith(
        goals: state.goals.where((item) => item.id != id).toList());
    await _applyAndLog(
      action: 'delete',
      entityType: 'goal',
      entityId: id,
      details: 'تم حذف هدف',
      apply: () async => next,
    );
  }
}
