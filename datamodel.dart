// ===== Family v1 Data Model =====

// 枚举
enum FamilyRole {
  owner,
  admin,
  member,
}

enum FamilyMemberStatus {
  active,
  removed,
}

enum OrderStatus {
  ordering,
  placed,
  finished,
}

enum ItemStatus {
  waiting,
  cooking,
  done,
}

// 用户档案
Profile {
  id: UUID                     // 对应 Supabase auth.users.id
  username: String             // 全局唯一，用于登录
  avatar_url: String?
  is_admin: Boolean            // 平台管理员标记，不参与家庭业务授权
  created_at: Timestamp
}

// 家庭（租户边界）
Family {
  id: UUID
  name: String
  created_by: UUID             // -> Profile.id
  join_code: String            // 家庭邀请码，可刷新
  join_code_rotated_at: Timestamp
  created_at: Timestamp
  archived_at: Timestamp?
}

// 家庭成员
FamilyMember {
  id: UUID
  family_id: UUID              // -> Family.id
  user_id: UUID                // -> Profile.id
  role: FamilyRole             // owner | admin | member
  status: FamilyMemberStatus   // active | removed
  joined_at: Timestamp
  removed_at: Timestamp?
  invited_by: UUID?            // -> Profile.id
  // 约束：unique(family_id, user_id)
}

// 菜品（家庭级资源）
Dish {
  id: UUID
  family_id: UUID              // -> Family.id
  name: String
  category: String             // 动态分类来源
  image_url: String?
  ingredients: JSON            // [{ name, amount, unit }]
  created_by: UUID             // -> Profile.id
  created_at: Timestamp
  updated_at: Timestamp
  archived_at: Timestamp?
  // 约束：unique(family_id, name)
}

// 订单（家庭内协作容器）
Order {
  id: UUID
  family_id: UUID              // -> Family.id
  status: OrderStatus          // ordering | placed | finished
  share_token: String          // 家庭成员加入订单的分享链接 token
  created_by: UUID             // -> Profile.id
  current_round: Int           // 当前下单轮次，初始 1
  created_at: Timestamp
  placed_at: Timestamp?
  finished_at: Timestamp?
}

// 订单成员（仅家庭成员）
OrderMember {
  id: UUID
  order_id: UUID               // -> Order.id
  user_id: UUID                // -> Profile.id
  joined_at: Timestamp
  // 约束：unique(order_id, user_id)
}

// 订单菜品项
OrderItem {
  id: UUID
  order_id: UUID               // -> Order.id
  dish_id: UUID                // -> Dish.id
  added_by_member_id: UUID?    // -> OrderMember.id
  quantity: Int
  status: ItemStatus           // waiting | cooking | done
  order_round: Int             // 第几轮下单，用于采购清单高亮
  created_at: Timestamp
}

// 核心业务关系
//
// User -> Family -> Order -> OrderItem -> Dish
//
// 规则：
// 1. Family 是租户边界，菜单、订单、成员都归属于家庭
// 2. 业务权限属于 FamilyMember.role，不属于 Profile.is_admin
// 3. 只有家庭活跃成员可以加入订单并参与点菜
