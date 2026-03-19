import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_exception.dart';
import '../../shared/repositories/order_repository.dart';
import '../../shared/widgets/app_widgets.dart';
import '../family/family_providers.dart';
import 'order_providers.dart';

class JoinOrderPage extends ConsumerStatefulWidget {
  const JoinOrderPage({required this.shareToken, super.key});

  final String shareToken;

  @override
  ConsumerState<JoinOrderPage> createState() => _JoinOrderPageState();
}

class _JoinOrderPageState extends ConsumerState<JoinOrderPage> {
  String? _errorText;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    Future.microtask(_join);
  }

  Future<void> _join() async {
    try {
      final result = await ref
          .read(orderRepositoryProvider)
          .joinOrderByShareToken(widget.shareToken);
      await ref
          .read(currentFamilyIdProvider.notifier)
          .selectFamily(result.familyId);
      ref.invalidate(activeOrderSummaryProvider(result.familyId));
      ref.invalidate(orderDetailProvider(result.orderId));
      if (mounted) {
        context.go('/app/orders/${result.orderId}');
      }
    } catch (error) {
      setState(() {
        _errorText = AppException.from(
          error,
          fallbackMessage: '加入订单失败，请稍后重试',
        ).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '加入订单',
      body: _errorText == null
          ? const SizedBox(height: 320, child: LoadingView(label: '正在加入订单'))
          : ErrorStateView(message: _errorText!, onRetry: _join),
    );
  }
}
