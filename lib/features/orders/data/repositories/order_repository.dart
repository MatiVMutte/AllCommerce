import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/features/cart/data/models/cart_item.dart';
import 'package:all_commerce/features/orders/data/models/order_item_model.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Provider<OrderRepository> orderRepositoryProvider =
    Provider<OrderRepository>(
  (Ref ref) => OrderRepository(ref.watch(supabaseClientProvider)),
);

class OrderRepository {
  const OrderRepository(this._client);

  final SupabaseClient _client;

  Future<OrderModel> placeOrder({
    required String tenantId,
    required List<CartItem> items,
    String? couponCode,
    String? notes,
  }) async {
    final Map<String, dynamic> row = await _client.rpc(
      'place_order',
      params: <String, dynamic>{
        'p_tenant_id': tenantId,
        'p_items': items
            .map(
              (CartItem i) => <String, dynamic>{
                'product_id': i.productId,
                'quantity': i.quantity,
              },
            )
            .toList(),
        'p_coupon_code': couponCode,
        'p_notes': notes,
      },
    );
    return OrderModel.fromJson(row);
  }

  /// Latest orders for [tenantId], newest first.
  Future<List<OrderModel>> listByTenant(String tenantId) async {
    final List<dynamic> rows = await _client
        .from('orders')
        .select()
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false)
        .limit(200);
    return rows
        .map((dynamic r) => OrderModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Orders placed by the logged-in customer, newest first.
  Future<List<OrderModel>> listMine(String customerId) async {
    final List<dynamic> rows = await _client
        .from('orders')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(100);
    return rows
        .map((dynamic r) => OrderModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<OrderItemModel>> listItems(String orderId) async {
    final List<dynamic> rows = await _client
        .from('order_items')
        .select()
        .eq('order_id', orderId);
    return rows
        .map(
          (dynamic r) => OrderItemModel.fromJson(r as Map<String, dynamic>),
        )
        .toList();
  }

  /// RLS only allows the owner to update the `status` column.
  Future<OrderModel> updateStatus(
    String orderId,
    String tenantId,
    OrderStatus status,
  ) async {
    final Map<String, dynamic> row = await _client
        .from('orders')
        .update(<String, dynamic>{'status': status.id})
        .eq('id', orderId)
        .eq('tenant_id', tenantId)
        .select()
        .single();
    return OrderModel.fromJson(row);
  }
}
