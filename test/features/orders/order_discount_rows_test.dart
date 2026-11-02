import 'dart:typed_data';

import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/core/constants/payment_method.dart';
import 'package:all_commerce/core/theme/app_theme.dart';
import 'package:all_commerce/features/orders/data/models/order_item_model.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/services/order_ticket_pdf.dart';
import 'package:all_commerce/features/orders/presentation/widgets/order_discount_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OrderModel _order({
  String? couponCode,
  double couponDiscount = 0,
  double bulkDiscount = 0,
  double bulkDiscountPct = 0,
  double paymentDiscount = 0,
  double paymentDiscountPct = 0,
  double discount = 0,
  double deliveryCost = 0,
  PaymentMethod paymentMethod = PaymentMethod.cash,
}) {
  return OrderModel(
    id: 'o1',
    orderNumber: 7,
    tenantId: 't1',
    customerId: 'u1',
    customerNameSnapshot: 'Ana',
    customerPhoneSnapshot: '54911',
    status: OrderStatus.requested,
    subtotal: 1000,
    discount: discount,
    total: 1000 - discount + deliveryCost,
    couponCode: couponCode,
    couponDiscount: couponDiscount,
    bulkDiscount: bulkDiscount,
    bulkDiscountPct: bulkDiscountPct,
    paymentDiscount: paymentDiscount,
    paymentDiscountPct: paymentDiscountPct,
    deliveryCost: deliveryCost,
    paymentMethod: paymentMethod,
    createdAt: DateTime(2025),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('shows coupon, bulk and payment discount lines', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        OrderCostRows(
          order: _order(
            couponCode: 'AHIJUNA10',
            couponDiscount: 100,
            bulkDiscount: 50,
            bulkDiscountPct: 5,
            paymentDiscount: 30,
            paymentDiscountPct: 3,
            discount: 180,
          ),
        ),
      ),
    );

    expect(find.textContaining('Cupón (AHIJUNA10)'), findsOneWidget);
    expect(find.textContaining('Descuento por volumen (5%)'), findsOneWidget);
    expect(find.textContaining('Descuento por pago'), findsOneWidget);
  });

  testWidgets('old orders fall back to a generic Descuento line', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(OrderCostRows(order: _order(discount: 120))));

    expect(find.text('Descuento'), findsOneWidget);
    expect(find.text('−\$120'), findsOneWidget);
  });

  test('PDF builds with tenant color and breakdown', () async {
    final Uint8List bytes = await buildOrderTicketPdf(
      order: _order(
        couponCode: 'X10',
        couponDiscount: 100,
        bulkDiscount: 50,
        bulkDiscountPct: 5,
        paymentDiscount: 30,
        paymentDiscountPct: 3,
        discount: 180,
        deliveryCost: 50,
      ),
      items: const <OrderItemModel>[
        OrderItemModel(
          id: 'i1',
          orderId: 'o1',
          titleSnapshot: 'Yerba 1kg',
          unitPrice: 800,
          listPrice: 1000,
          quantity: 5,
        ),
      ],
      tenantName: 'Almacén Don Pepe',
      primaryColorHex: '#16A34A',
    );
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
  });
}
