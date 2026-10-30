import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/features/store/data/models/coupon_model.dart';
import 'package:all_commerce/features/store/data/repositories/coupon_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final couponRepositoryProvider = Provider<CouponRepository>(
  (Ref ref) => CouponRepository(ref.watch(supabaseClientProvider)),
);

final ownerCouponsProvider = FutureProvider.autoDispose
    .family<List<CouponModel>, String>(
      (Ref ref, String tenantId) =>
          ref.watch(couponRepositoryProvider).list(tenantId),
    );
