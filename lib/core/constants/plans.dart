enum PlanType {
  trial('trial', 'Prueba', 30),
  inicial('inicial', 'Inicial', 30),
  crecimiento('crecimiento', 'Crecimiento', 150),
  pro('pro', 'Pro', 1000);

  const PlanType(this.id, this.label, this.maxProducts);

  /// Value stored in the database.
  final String id;

  /// Spanish display label.
  final String label;
  final int maxProducts;

  static PlanType fromId(String id) {
    for (final PlanType plan in values) {
      if (plan.id == id) return plan;
    }
    return PlanType.trial;
  }
}
