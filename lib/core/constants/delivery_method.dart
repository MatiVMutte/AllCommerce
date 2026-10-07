enum DeliveryMethod {
  pickup('pickup', 'Retiro en el local'),
  delivery('delivery', 'Envío a domicilio');

  const DeliveryMethod(this.id, this.label);

  final String id;
  final String label;

  static DeliveryMethod fromId(String id) {
    for (final DeliveryMethod method in values) {
      if (method.id == id) return method;
    }
    return DeliveryMethod.pickup;
  }
}
