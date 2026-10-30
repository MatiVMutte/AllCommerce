import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/features/orders/data/models/order_item_model.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/services/sales_csv.dart';
import 'package:flutter_test/flutter_test.dart';

OrderModel _order({String? notes, String name = 'Ana'}) {
  return OrderModel(
    id: 'o1',
    orderNumber: 42,
    tenantId: 't1',
    customerId: 'u1',
    customerNameSnapshot: name,
    customerPhoneSnapshot: '5491199999999',
    status: OrderStatus.delivered,
    subtotal: 17000,
    discount: 0,
    total: 17000,
    notes: notes,
    createdAt: DateTime(2025, 3, 5, 14, 30),
  );
}

const List<OrderItemModel> _items = <OrderItemModel>[
  OrderItemModel(
    id: 'i1',
    orderId: 'o1',
    productId: 'p1',
    titleSnapshot: 'Vaso térmico',
    unitPrice: 8500,
    quantity: 2,
    variant: 'Rojo',
  ),
];

void main() {
  test('writes header and one row per order', () {
    final String csv = SalesCsv.build(
      <OrderModel>[_order()],
      <String, List<OrderItemModel>>{'o1': _items},
    );
    final List<String> lines = csv.trim().split('\n');
    expect(lines, hasLength(2));
    expect(lines.first, startsWith('Fecha;Pedido;Cliente'));
    expect(lines[1], contains('"#42"'));
    expect(lines[1], contains('"2x Vaso térmico (Rojo)"'));
    expect(lines[1], contains('"05/03/2025 14:30"'));
    expect(lines[1], contains('"17000.00"'));
  });

  test('escapes quotes, semicolons and newlines inside cells', () {
    final String csv = SalesCsv.build(<OrderModel>[
      _order(name: 'Ana "La Grande", sos', notes: 'sin timbre\ngolpear'),
    ], <String, List<OrderItemModel>>{});
    final String row = csv.trim().split('\n').last;
    expect(row, contains('"Ana ""La Grande"", sos"'));
    expect(row, contains('"sin timbre golpear"'));
    // Each cell stays a single line — no embedded newlines leak out.
    expect(csv.trim().split('\n'), hasLength(2));
  });
}
