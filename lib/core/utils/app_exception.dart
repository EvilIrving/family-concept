import 'package:supabase_flutter/supabase_flutter.dart';

/// User-friendly application error.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;

  static AppException from(
    Object error, {
    String fallbackMessage = '操作失败，请稍后重试',
  }) {
    if (error is AppException) {
      return error;
    }

    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials')) {
        return const AppException('用户名或密码不正确');
      }
      if (message.contains('already registered')) {
        return const AppException('这个用户名已经被使用');
      }
      if (message.contains('email not confirmed')) {
        return const AppException('当前项目需要关闭邮箱确认，才能使用用户名模式');
      }
      if (message.contains('same password')) {
        return const AppException('新密码不能与旧密码相同');
      }
    }

    if (error is PostgrestException) {
      if (error.code == '23505') {
        return const AppException('这个名称已经存在，请换一个');
      }

      final message = error.message.toLowerCase();
      if (message.contains('profiles_username_key')) {
        return const AppException('这个用户名已经被使用');
      }
      if (message.contains('invalid family join code')) {
        return const AppException('邀请码无效，请检查后重试');
      }
      if (message.contains('already an active family member')) {
        return const AppException('你已经在这个家庭中了');
      }
      if (message.contains('invalid or expired order share token')) {
        return const AppException('分享链接无效');
      }
      if (message.contains('belong to the order family')) {
        return const AppException('你不属于这个家庭，无法加入该订单');
      }
      if (message.contains('already in an active order')) {
        return const AppException('你当前已经在另一个进行中的订单里');
      }
      if (message.contains('owner cannot leave family')) {
        return const AppException('owner 暂不支持主动退出家庭');
      }
      if (message.contains('insufficient permission')) {
        return const AppException('你没有执行该操作的权限');
      }
      if (message.contains('only family owner can update member role')) {
        return const AppException('只有 owner 可以调整管理员');
      }
      if (message.contains('order creator must be an active family member') ||
          message.contains('only active family members can create an order')) {
        return const AppException('只有家庭活跃成员可以创建订单');
      }
      if (message.contains('dish must belong to the same family')) {
        return const AppException('只能添加当前家庭的菜品');
      }
      if (message.contains('invalid input syntax')) {
        return const AppException('输入内容格式不正确');
      }
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') || raw.contains('network')) {
      return const AppException('网络连接失败，请稍后重试');
    }

    return AppException(fallbackMessage);
  }
}
