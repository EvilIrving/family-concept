import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_environment.dart';
import '../../core/supabase/supabase_provider.dart';
import '../../core/utils/app_exception.dart';
import '../models/app_models.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(supabaseClientProvider));
});

/// Order and order-item repository.
class OrderRepository {
  const OrderRepository(this._client);

  final SupabaseClient _client;

  Future<OrderSummary?> fetchActiveOrderSummary(String familyId) async {
    try {
      final orderRow = await _client
          .from('orders')
          .select()
          .eq('family_id', familyId)
          .neq('status', 'finished')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (orderRow == null) {
        return null;
      }

      final order = OrderRecord.fromJson(Map<String, dynamic>.from(orderRow));
      final participants = await _fetchParticipants(order.id);
      final currentUserId = _client.auth.currentUser?.id;

      return OrderSummary(
        order: order,
        participants: participants,
        isCurrentUserJoined: participants.any(
          (participant) => participant.userId == currentUserId,
        ),
      );
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '订单加载失败，请稍后重试');
    }
  }

  Future<OrderDetail> fetchOrderDetail(String orderId) async {
    try {
      final orderRow = await _client
          .from('orders')
          .select()
          .eq('id', orderId)
          .single();

      final participants = await _fetchParticipants(orderId);
      final items = await _fetchItems(orderId);

      return OrderDetail(
        order: OrderRecord.fromJson(Map<String, dynamic>.from(orderRow)),
        participants: participants,
        items: items,
      );
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '订单加载失败，请稍后重试');
    }
  }

  Future<List<OrderParticipant>> _fetchParticipants(String orderId) async {
    final response = await _client
        .from('order_members')
        .select('id, order_id, user_id, joined_at, profiles!inner(*)')
        .eq('order_id', orderId)
        .order('joined_at');

    return response
        .map((row) => OrderParticipant.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<OrderItemRecord>> _fetchItems(String orderId) async {
    final response = await _client
        .from('order_items')
        .select(
          'id, order_id, dish_id, added_by_member_id, quantity, status, '
          'order_round, created_at, dishes!inner(*)',
        )
        .eq('order_id', orderId)
        .order('created_at');

    return response
        .map((row) => OrderItemRecord.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<OrderSummary> createOrder(String familyId) async {
    try {
      final rpc = await _client.rpc(
        'create_order_for_family',
        params: {'p_family_id': familyId},
      );
      final rows = (rpc as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final orderId = rows.first['order_id'] as String;

      final summary = await fetchActiveOrderSummary(familyId);
      if (summary == null || summary.order.id != orderId) {
        throw const AppException('订单创建后未能重新加载');
      }
      return summary;
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '创建订单失败，请稍后重试');
    }
  }

  Future<({String familyId, String orderId})> joinOrderByShareToken(
    String token,
  ) async {
    try {
      final rpc = await _client.rpc(
        'join_order_by_share_token',
        params: {'p_token': token.trim()},
      );
      final rows = (rpc as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      return (
        familyId: rows.first['family_id'] as String,
        orderId: rows.first['order_id'] as String,
      );
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '加入订单失败，请稍后重试');
    }
  }

  Future<void> addDishToOrder({
    required OrderRecord order,
    required String dishId,
    required String orderMemberId,
    required int quantity,
  }) async {
    try {
      await _client.from('order_items').insert({
        'order_id': order.id,
        'dish_id': dishId,
        'added_by_member_id': orderMemberId,
        'quantity': quantity,
        'status': ItemStatus.waiting.name,
        'order_round': order.currentRound,
      });
      if (order.status == OrderStatus.placed) {
        await _client
            .from('orders')
            .update({'status': OrderStatus.ordering.name})
            .eq('id', order.id);
      }
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '加菜失败，请稍后重试');
    }
  }

  Future<void> updateItemQuantity({
    required String itemId,
    required int quantity,
  }) async {
    try {
      await _client
          .from('order_items')
          .update({'quantity': quantity})
          .eq('id', itemId);
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '数量更新失败，请稍后重试');
    }
  }

  Future<void> updateItemStatus({
    required String itemId,
    required ItemStatus status,
  }) async {
    try {
      await _client
          .from('order_items')
          .update({'status': status.name})
          .eq('id', itemId);
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '状态更新失败，请稍后重试');
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await _client.from('order_items').delete().eq('id', itemId);
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '删除菜品项失败，请稍后重试');
    }
  }

  Future<void> placeCurrentRound(OrderRecord order) async {
    try {
      await _client
          .from('orders')
          .update({
            'status': OrderStatus.placed.name,
            'current_round': order.currentRound + 1,
            'placed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', order.id);
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '下单失败，请稍后重试');
    }
  }

  Future<void> finishOrder(String orderId) async {
    try {
      await _client
          .from('orders')
          .update({
            'status': OrderStatus.finished.name,
            'finished_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '结束订单失败，请稍后重试');
    }
  }

  Future<List<OrderRecord>> fetchOrderHistory(String familyId) async {
    try {
      final response = await _client
          .from('orders')
          .select()
          .eq('family_id', familyId)
          .eq('status', OrderStatus.finished.name)
          .order('finished_at', ascending: false);

      return response
          .map((row) => OrderRecord.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (error) {
      throw AppException.from(error, fallbackMessage: '历史订单加载失败，请稍后重试');
    }
  }

  String buildShareLink(String token) {
    if (AppEnvironment.deepLinkBaseUrl.trim().isEmpty) {
      return '/app/join/$token';
    }
    final base = AppEnvironment.deepLinkBaseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/app/join/$token';
  }
}
