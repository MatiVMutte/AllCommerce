enum PaymentMethod {
  cash('cash', 'Efectivo'),
  transfer('transfer', 'Transferencia'),
  mercadoPago('mercado_pago', 'Mercado Pago');

  const PaymentMethod(this.id, this.label);

  final String id;
  final String label;

  static PaymentMethod fromId(String id) {
    for (final PaymentMethod method in values) {
      if (method.id == id) return method;
    }
    return PaymentMethod.cash;
  }
}
