import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/features/cart/data/models/cart_item.dart';
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
}
