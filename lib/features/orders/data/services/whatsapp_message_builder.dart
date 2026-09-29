import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/features/cart/data/models/cart_item.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';

/// Builds the WhatsApp order message. Keep the format stable — it's what
/// the store owner reads.
String buildOrderMessage({
  required TenantModel tenant,
  required OrderModel order,
  required List<CartItem> items,
  required String customerName,
  required String customerPhone,
  String? couponCode,
}) {
  final StringBuffer buffer = StringBuffer()
    ..writeln(
      'Hola ${tenant.name}! Quiero hacer un pedido (#${order.orderNumber}):',
    );
  for (final CartItem item in items) {
    buffer.writeln(
      '• ${item.quantity} x ${item.title} — ${Formatters.price(item.lineTotal)}',
    );
  }
  buffer.writeln('Subtotal: ${Formatters.price(order.subtotal)}');
  if (order.discount > 0) {
    buffer.writeln(
      'Descuento (${couponCode ?? ''}): -${Formatters.price(order.discount)}',
    );
  }
  buffer.writeln('Total: ${Formatters.price(order.total)}');
  final String? notes = order.notes;
  if (notes != null && notes.trim().isNotEmpty) {
    buffer.writeln('Notas: ${notes.trim()}');
  }
  buffer.write('Nombre: $customerName · Tel: $customerPhone');
  return buffer.toString();
}

Uri buildWhatsAppUri(String phone, String message) {
  return Uri.parse(
    'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
  );
}
