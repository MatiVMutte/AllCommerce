import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/features/cart/data/models/cart_item.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/services/whatsapp_message_builder.dart';
import 'package:flutter_test/flutter_test.dart';

TenantModel _tenant() {
  return TenantModel(
    id: 't1',
    slug: 'mi-local',
    name: 'Mi Local',
    whatsapp: '5491122334455',
    primaryColor: '#0052FF',
    plan: PlanType.trial,
    trialStartedAt: DateTime(2024),
    planExpiresAt: DateTime.now().add(const Duration(days: 30)),
    isActive: true,
      isClaimed: true,
    createdAt: DateTime(2024),
  );
}

OrderModel _order({double discount = 0, String? notes}) {
  return OrderModel(
    id: 'o1',
    orderNumber: 42,
    tenantId: 't1',
    customerId: 'u1',
    customerNameSnapshot: 'Ana',
    customerPhoneSnapshot: '5491199999999',
    status: OrderStatus.requested,
    subtotal: 25500,
    discount: discount,
    total: 25500 - discount,
    notes: notes,
    createdAt: DateTime(2024),
  );
}

const List<CartItem> _items = <CartItem>[
  CartItem(productId: 'p1', title: 'Vaso térmico', price: 8500, quantity: 2),
  CartItem(productId: 'p2', title: 'Remera', price: 8500, quantity: 1),
];

void main() {
  test('builds the exact message without coupon or notes', () {
    final String message = buildOrderMessage(
      tenant: _tenant(),
      order: _order(),
      items: _items,
      customerName: 'Ana',
      customerPhone: '5491199999999',
    );
    expect(
      message,
      'Hola Mi Local! Quiero hacer un pedido (#42):\n'
      '• 2 x Vaso térmico — \$17.000\n'
      '• 1 x Remera — \$8.500\n'
      'Subtotal: \$25.500\n'
      'Total: \$25.500\n'
      'Entrega: Retiro en el local\n'
      'Pago: Efectivo\n'
      'Nombre: Ana · Tel: 5491199999999',
    );
  });

  test('includes discount and notes lines when present', () {
    final String message = buildOrderMessage(
      tenant: _tenant(),
      order: _order(discount: 2550, notes: 'Sin cebolla'),
      items: _items,
      customerName: 'Ana',
      customerPhone: '5491199999999',
      couponCode: 'CODIGO',
    );
    expect(message, contains('Descuento (CODIGO): -\$2.550'));
    expect(message, contains('Total: \$22.950'));
    expect(message, contains('Notas: Sin cebolla'));
  });

  test('buildWhatsAppUri encodes message and uses wa.me', () {
    final Uri uri = buildWhatsAppUri('5491122334455', 'Hola! Quiero pedir');
    expect(uri.toString(),
        'https://wa.me/5491122334455?text=Hola!%20Quiero%20pedir');
  });
}
