import 'dart:math';

enum FamilyRole {
  owner,
  admin,
  member;

  String get label => switch (this) {
    FamilyRole.owner => 'Owner',
    FamilyRole.admin => 'Admin',
    FamilyRole.member => 'Member',
  };

  bool get canManageMenu =>
      this == FamilyRole.owner || this == FamilyRole.admin;
  bool get canManageMembers =>
      this == FamilyRole.owner || this == FamilyRole.admin;
  bool get canManageAdmins => this == FamilyRole.owner;

  static FamilyRole fromJson(String value) {
    return FamilyRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => FamilyRole.member,
    );
  }
}

enum FamilyMemberStatus {
  active,
  removed;

  static FamilyMemberStatus fromJson(String value) {
    return FamilyMemberStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => FamilyMemberStatus.active,
    );
  }
}

enum OrderStatus {
  ordering,
  placed,
  finished;

  String get label => switch (this) {
    OrderStatus.ordering => '进行中',
    OrderStatus.placed => '已下单',
    OrderStatus.finished => '已结束',
  };

  static OrderStatus fromJson(String value) {
    return OrderStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => OrderStatus.ordering,
    );
  }
}

enum ItemStatus {
  waiting,
  cooking,
  done;

  String get label => switch (this) {
    ItemStatus.waiting => '待做',
    ItemStatus.cooking => '制作中',
    ItemStatus.done => '已完成',
  };

  static ItemStatus fromJson(String value) {
    return ItemStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ItemStatus.waiting,
    );
  }
}

Map<String, dynamic> _asMap(dynamic raw) {
  return Map<String, dynamic>.from(raw as Map);
}

DateTime _parseDateTime(dynamic value) {
  return DateTime.parse(value as String);
}

class AppProfile {
  const AppProfile({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.isAdmin,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String? avatarUrl;
  final bool isAdmin;
  final DateTime createdAt;

  factory AppProfile.fromJson(Map<String, dynamic> json) {
    return AppProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  AppProfile copyWith({String? username, String? avatarUrl}) {
    return AppProfile(
      id: id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isAdmin: isAdmin,
      createdAt: createdAt,
    );
  }
}

class Family {
  const Family({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.joinCode,
    required this.joinCodeRotatedAt,
    required this.createdAt,
    required this.archivedAt,
  });

  final String id;
  final String name;
  final String createdBy;
  final String joinCode;
  final DateTime joinCodeRotatedAt;
  final DateTime createdAt;
  final DateTime? archivedAt;

  factory Family.fromJson(Map<String, dynamic> json) {
    return Family(
      id: json['id'] as String,
      name: json['name'] as String,
      createdBy: json['created_by'] as String,
      joinCode: json['join_code'] as String,
      joinCodeRotatedAt: _parseDateTime(json['join_code_rotated_at']),
      createdAt: _parseDateTime(json['created_at']),
      archivedAt: json['archived_at'] == null
          ? null
          : _parseDateTime(json['archived_at']),
    );
  }

  Family copyWith({
    String? name,
    String? joinCode,
    DateTime? joinCodeRotatedAt,
  }) {
    return Family(
      id: id,
      name: name ?? this.name,
      createdBy: createdBy,
      joinCode: joinCode ?? this.joinCode,
      joinCodeRotatedAt: joinCodeRotatedAt ?? this.joinCodeRotatedAt,
      createdAt: createdAt,
      archivedAt: archivedAt,
    );
  }
}

class FamilyMembership {
  const FamilyMembership({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.role,
    required this.status,
    required this.joinedAt,
    required this.removedAt,
    required this.invitedBy,
    this.family,
    this.profile,
  });

  final String id;
  final String familyId;
  final String userId;
  final FamilyRole role;
  final FamilyMemberStatus status;
  final DateTime joinedAt;
  final DateTime? removedAt;
  final String? invitedBy;
  final Family? family;
  final AppProfile? profile;

  factory FamilyMembership.fromJson(Map<String, dynamic> json) {
    final familyRaw = json['families'];
    final profileRaw = json['profiles'];

    return FamilyMembership(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      userId: json['user_id'] as String,
      role: FamilyRole.fromJson(json['role'] as String),
      status: FamilyMemberStatus.fromJson(json['status'] as String),
      joinedAt: _parseDateTime(json['joined_at']),
      removedAt: json['removed_at'] == null
          ? null
          : _parseDateTime(json['removed_at']),
      invitedBy: json['invited_by'] as String?,
      family: familyRaw == null ? null : Family.fromJson(_asMap(familyRaw)),
      profile: profileRaw == null
          ? null
          : AppProfile.fromJson(_asMap(profileRaw)),
    );
  }
}

class FamilySummary {
  const FamilySummary({required this.family, required this.membership});

  final Family family;
  final FamilyMembership membership;

  String get id => family.id;
  String get name => family.name;
  FamilyRole get role => membership.role;
}

class DishIngredient {
  const DishIngredient({
    required this.name,
    required this.amount,
    required this.unit,
  });

  final String name;
  final double amount;
  final String unit;

  factory DishIngredient.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final amount = switch (rawAmount) {
      int value => value.toDouble(),
      double value => value,
      String value => double.tryParse(value) ?? 0.0,
      _ => 0.0,
    };

    return DishIngredient(
      name: json['name'] as String? ?? '',
      amount: amount,
      unit: json['unit'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'amount': amount, 'unit': unit};
  }
}

class Dish {
  const Dish({
    required this.id,
    required this.familyId,
    required this.name,
    required this.category,
    required this.imageUrl,
    required this.ingredients,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.archivedAt,
  });

  final String id;
  final String familyId;
  final String name;
  final String category;
  final String? imageUrl;
  final List<DishIngredient> ingredients;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  factory Dish.fromJson(Map<String, dynamic> json) {
    final ingredientsRaw = json['ingredients'] as List<dynamic>? ?? const [];

    return Dish(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      imageUrl: json['image_url'] as String?,
      ingredients: ingredientsRaw
          .map((raw) => DishIngredient.fromJson(_asMap(raw)))
          .where((ingredient) => ingredient.name.trim().isNotEmpty)
          .toList(),
      createdBy: json['created_by'] as String,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      archivedAt: json['archived_at'] == null
          ? null
          : _parseDateTime(json['archived_at']),
    );
  }

  Dish copyWith({String? imageUrl}) {
    return Dish(
      id: id,
      familyId: familyId,
      name: name,
      category: category,
      imageUrl: imageUrl ?? this.imageUrl,
      ingredients: ingredients,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      archivedAt: archivedAt,
    );
  }
}

class OrderRecord {
  const OrderRecord({
    required this.id,
    required this.familyId,
    required this.status,
    required this.shareToken,
    required this.createdBy,
    required this.currentRound,
    required this.createdAt,
    required this.placedAt,
    required this.finishedAt,
  });

  final String id;
  final String familyId;
  final OrderStatus status;
  final String shareToken;
  final String createdBy;
  final int currentRound;
  final DateTime createdAt;
  final DateTime? placedAt;
  final DateTime? finishedAt;

  factory OrderRecord.fromJson(Map<String, dynamic> json) {
    return OrderRecord(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      status: OrderStatus.fromJson(json['status'] as String),
      shareToken: json['share_token'] as String,
      createdBy: json['created_by'] as String,
      currentRound: json['current_round'] as int? ?? 1,
      createdAt: _parseDateTime(json['created_at']),
      placedAt: json['placed_at'] == null
          ? null
          : _parseDateTime(json['placed_at']),
      finishedAt: json['finished_at'] == null
          ? null
          : _parseDateTime(json['finished_at']),
    );
  }

  bool get isActive => status != OrderStatus.finished;
}

class OrderParticipant {
  const OrderParticipant({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.joinedAt,
    this.profile,
  });

  final String id;
  final String orderId;
  final String userId;
  final DateTime joinedAt;
  final AppProfile? profile;

  factory OrderParticipant.fromJson(Map<String, dynamic> json) {
    final profileRaw = json['profiles'];

    return OrderParticipant(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      userId: json['user_id'] as String,
      joinedAt: _parseDateTime(json['joined_at']),
      profile: profileRaw == null
          ? null
          : AppProfile.fromJson(_asMap(profileRaw)),
    );
  }
}

class OrderItemRecord {
  const OrderItemRecord({
    required this.id,
    required this.orderId,
    required this.dishId,
    required this.addedByMemberId,
    required this.quantity,
    required this.status,
    required this.orderRound,
    required this.createdAt,
    this.dish,
  });

  final String id;
  final String orderId;
  final String dishId;
  final String? addedByMemberId;
  final int quantity;
  final ItemStatus status;
  final int orderRound;
  final DateTime createdAt;
  final Dish? dish;

  factory OrderItemRecord.fromJson(Map<String, dynamic> json) {
    final dishRaw = json['dishes'];

    return OrderItemRecord(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      dishId: json['dish_id'] as String,
      addedByMemberId: json['added_by_member_id'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      status: ItemStatus.fromJson(json['status'] as String),
      orderRound: json['order_round'] as int? ?? 1,
      createdAt: _parseDateTime(json['created_at']),
      dish: dishRaw == null ? null : Dish.fromJson(_asMap(dishRaw)),
    );
  }
}

class OrderSummary {
  const OrderSummary({
    required this.order,
    required this.participants,
    required this.isCurrentUserJoined,
  });

  final OrderRecord order;
  final List<OrderParticipant> participants;
  final bool isCurrentUserJoined;
}

class ShoppingListEntry {
  const ShoppingListEntry({
    required this.name,
    required this.amount,
    required this.unit,
    required this.isLatestRound,
  });

  final String name;
  final double amount;
  final String unit;
  final bool isLatestRound;
}

class ShoppingListRoundGroup {
  const ShoppingListRoundGroup({required this.round, required this.entries});

  final int round;
  final List<ShoppingListEntry> entries;
}

class OrderRoundGroup {
  const OrderRoundGroup({required this.round, required this.items});

  final int round;
  final List<OrderItemRecord> items;
}

class OrderDetail {
  const OrderDetail({
    required this.order,
    required this.participants,
    required this.items,
  });

  final OrderRecord order;
  final List<OrderParticipant> participants;
  final List<OrderItemRecord> items;

  bool get isFinished => order.status == OrderStatus.finished;
  bool get hasItemsInCurrentRound =>
      items.any((item) => item.orderRound == order.currentRound);
  bool get isOrdering =>
      order.status == OrderStatus.ordering ||
      (order.status == OrderStatus.placed && hasItemsInCurrentRound);
  int get latestRound =>
      items.isEmpty ? 1 : items.map((item) => item.orderRound).reduce(max);

  String? currentMemberIdForUser(String userId) {
    for (final participant in participants) {
      if (participant.userId == userId) {
        return participant.id;
      }
    }
    return null;
  }

  List<ShoppingListEntry> aggregateShoppingList() {
    final buffer = <String, ShoppingListEntry>{};
    final latest = latestRound;

    for (final item in items) {
      final dish = item.dish;
      if (dish == null) {
        continue;
      }

      for (final ingredient in dish.ingredients) {
        final key =
            '${ingredient.name.toLowerCase()}|${ingredient.unit.toLowerCase()}';
        final total = ingredient.amount * item.quantity;
        final previous = buffer[key];

        buffer[key] = ShoppingListEntry(
          name: ingredient.name,
          amount: (previous?.amount ?? 0.0) + total,
          unit: ingredient.unit,
          isLatestRound:
              (previous?.isLatestRound ?? false) || item.orderRound == latest,
        );
      }
    }

    final entries = buffer.values.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    return entries;
  }

  List<OrderRoundGroup> groupItemsByRound() {
    final grouped = <int, List<OrderItemRecord>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.orderRound, () => []).add(item);
    }

    final rounds = grouped.keys.toList()..sort();
    return rounds
        .map(
          (round) => OrderRoundGroup(
            round: round,
            items: grouped[round]!
              ..sort((left, right) {
                final leftDish = left.dish?.name ?? '';
                final rightDish = right.dish?.name ?? '';
                final compareDish = leftDish.compareTo(rightDish);
                if (compareDish != 0) {
                  return compareDish;
                }
                return left.createdAt.compareTo(right.createdAt);
              }),
          ),
        )
        .toList();
  }

  List<ShoppingListRoundGroup> groupShoppingListByRound() {
    final grouped = <int, Map<String, ShoppingListEntry>>{};

    for (final item in items) {
      final dish = item.dish;
      if (dish == null) {
        continue;
      }

      final roundBuffer = grouped.putIfAbsent(item.orderRound, () => {});
      for (final ingredient in dish.ingredients) {
        final key =
            '${ingredient.name.toLowerCase()}|${ingredient.unit.toLowerCase()}';
        final total = ingredient.amount * item.quantity;
        final previous = roundBuffer[key];

        roundBuffer[key] = ShoppingListEntry(
          name: ingredient.name,
          amount: (previous?.amount ?? 0.0) + total,
          unit: ingredient.unit,
          isLatestRound: item.orderRound == latestRound,
        );
      }
    }

    final rounds = grouped.keys.toList()..sort();
    return rounds
        .map(
          (round) => ShoppingListRoundGroup(
            round: round,
            entries: grouped[round]!.values.toList()
              ..sort((left, right) => left.name.compareTo(right.name)),
          ),
        )
        .toList();
  }
}

class AppSessionData {
  const AppSessionData({
    required this.isConfigured,
    required this.initError,
    required this.authenticatedUserId,
    required this.profile,
    required this.families,
    required this.currentFamily,
  });

  final bool isConfigured;
  final Object? initError;
  final String? authenticatedUserId;
  final AppProfile? profile;
  final List<FamilySummary> families;
  final FamilySummary? currentFamily;

  bool get hasBackend => isConfigured && initError == null;
  bool get isAuthenticated => authenticatedUserId != null;
  bool get needsOnboarding => isAuthenticated && families.isEmpty;
}
