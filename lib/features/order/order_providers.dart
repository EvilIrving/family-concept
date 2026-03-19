import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/app_models.dart';
import '../../shared/repositories/order_repository.dart';

final activeOrderSummaryProvider = FutureProvider.family<OrderSummary?, String>(
  (ref, familyId) =>
      ref.watch(orderRepositoryProvider).fetchActiveOrderSummary(familyId),
);

final orderDetailProvider = FutureProvider.family<OrderDetail, String>(
  (ref, orderId) =>
      ref.watch(orderRepositoryProvider).fetchOrderDetail(orderId),
);

final orderHistoryProvider = FutureProvider.family<List<OrderRecord>, String>(
  (ref, familyId) =>
      ref.watch(orderRepositoryProvider).fetchOrderHistory(familyId),
);
