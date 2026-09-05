enum PlanStatus {
  active,
  completed,
  archived;

  static PlanStatus fromName(String? value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => PlanStatus.active,
  );

  String get label => switch (this) {
    PlanStatus.active => 'Active',
    PlanStatus.completed => 'Completed',
    PlanStatus.archived => 'Archived',
  };
}
