enum GoalStatus {
  active,
  achieved,
  archived;

  static GoalStatus fromName(String? value) => values.firstWhere(
        (e) => e.name == value,
        orElse: () => GoalStatus.active,
      );

  String get label => switch (this) {
        GoalStatus.active => 'In progress',
        GoalStatus.achieved => 'Achieved',
        GoalStatus.archived => 'Archived',
      };
}
