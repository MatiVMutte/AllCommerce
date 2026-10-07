import 'package:all_commerce/core/constants/delivery_method.dart';
import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/core/constants/payment_method.dart';

class OrderModel {
  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.tenantId,
    required this.customerId,
    required this.customerNameSnapshot,
    required this.customerPhoneSnapshot,
    required this.status,
    required this.subtotal,
    required this.discount,
    required this.total,
    this.couponId,
    this.notes,
    this.deliveryMethod = DeliveryMethod.pickup,
    this.deliveryAddress,
    this.deliveryCost = 0,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentNotes,
    required this.createdAt,
  });

  final String id;
  final int orderNumber;
  final String tenantId;
  final String customerId;
  final String customerNameSnapshot;
  final String customerPhoneSnapshot;
  final OrderStatus status;
  final double subtotal;
  final double discount;
  final double total;
  final String? couponId;
  final String? notes;
  final DeliveryMethod deliveryMethod;
  final String? deliveryAddress;
  final double deliveryCost;
  final PaymentMethod paymentMethod;
  final String? paymentNotes;
  final DateTime createdAt;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      orderNumber: num.parse(json['order_number'].toString()).toInt(),
      tenantId: json['tenant_id'] as String,
      customerId: json['customer_id'] as String,
      customerNameSnapshot: json['customer_name_snapshot'] as String,
      customerPhoneSnapshot: json['customer_phone_snapshot'] as String,
      status: OrderStatus.fromId(json['status'] as String),
      subtotal: num.parse(json['subtotal'].toString()).toDouble(),
      discount: num.parse(json['discount'].toString()).toDouble(),
      total: num.parse(json['total'].toString()).toDouble(),
      couponId: json['coupon_id'] as String?,
      notes: json['notes'] as String?,
      deliveryMethod:
          DeliveryMethod.fromId(json['delivery_method'] as String? ?? 'pickup'),
      deliveryAddress: json['delivery_address'] as String?,
      deliveryCost:
          num.tryParse(json['delivery_cost']?.toString() ?? '0')?.toDouble() ?? 0,
      paymentMethod:
          PaymentMethod.fromId(json['payment_method'] as String? ?? 'cash'),
      paymentNotes: json['payment_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  OrderModel copyWith({
    String? id,
    int? orderNumber,
    String? tenantId,
    String? customerId,
    String? customerNameSnapshot,
    String? customerPhoneSnapshot,
    OrderStatus? status,
    double? subtotal,
    double? discount,
    double? total,
    String? Function()? couponId,
    String? Function()? notes,
    DeliveryMethod? deliveryMethod,
    String? Function()? deliveryAddress,
    double? deliveryCost,
    PaymentMethod? paymentMethod,
    String? Function()? paymentNotes,
    DateTime? createdAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      tenantId: tenantId ?? this.tenantId,
      customerId: customerId ?? this.customerId,
      customerNameSnapshot:
          customerNameSnapshot ?? this.customerNameSnapshot,
      customerPhoneSnapshot:
          customerPhoneSnapshot ?? this.customerPhoneSnapshot,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      couponId: couponId != null ? couponId() : this.couponId,
      notes: notes != null ? notes() : this.notes,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      deliveryAddress:
          deliveryAddress != null ? deliveryAddress() : this.deliveryAddress,
      deliveryCost: deliveryCost ?? this.deliveryCost,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentNotes:
          paymentNotes != null ? paymentNotes() : this.paymentNotes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
