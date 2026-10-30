import 'package:all_commerce/features/orders/data/models/order_item_model.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:intl/intl.dart';

/// Builds the sales CSV the owner downloads from the panel.
/// `;` separator + UTF-8 BOM so Excel (es-AR) opens it correctly.
class SalesCsv {
  static String build(
    List<OrderModel> orders,
    Map<String, List<OrderItemModel>> itemsByOrder,
  ) {
    final StringBuffer out = StringBuffer()
      ..writeln(
        'Fecha;Pedido;Cliente;Telefono;Items;Subtotal;Descuento;Envio;'
        'Total;Estado;Pago;Entrega;Direccion;Notas',
      );
    final DateFormat fmt = DateFormat('dd/MM/yyyy HH:mm');
    for (final OrderModel o in orders) {
      final String items = (itemsByOrder[o.id] ?? const <OrderItemModel>[])
          .map(
            (OrderItemModel i) =>
                '${i.quantity}x ${i.titleSnapshot}'
                '${i.variant == null ? '' : ' (${i.variant})'}',
          )
          .join(' | ');
      out.writeln(
        <String>[
          fmt.format(o.createdAt.toLocal()),
          '#${o.orderNumber}',
          o.customerNameSnapshot,
          o.customerPhoneSnapshot,
          items,
          o.subtotal.toStringAsFixed(2),
          o.discount.toStringAsFixed(2),
          o.deliveryCost.toStringAsFixed(2),
          o.total.toStringAsFixed(2),
          o.status.label,
          o.paymentMethod.label,
          o.deliveryMethod.label,
          o.deliveryAddress ?? '',
          o.notes ?? '',
        ].map(_cell).join(';'),
      );
    }
    return out.toString();
  }

  static String _cell(String value) =>
      '"${value.replaceAll('"', '""').replaceAll('\n', ' ')}"';
}
