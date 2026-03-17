// ===== Data Model =====

// 用户档案
Profile {
  id: UUID               // 对应 Supabase auth.users.id
  username: String       // 唯一，用于登录
  avatar_url: String?
  is_admin: Boolean      // 全局管理员标记，默认 false
  created_at: Timestamp
}

// 菜品
Dish {
  id: UUID
  name: String
  category: String       // 动态分类来源
  image_url: String?
  ingredients: JSON      // [{ name, amount, unit }]
  created_by: UUID       // -> Profile.id
  created_at: Timestamp
}

// 订单
Order {
  id: UUID
  status: Enum           // ordering | placed | finished
  share_token: String    // 高随机，唯一
  created_by: UUID       // -> Profile.id（下单发起人）
  current_round: Int     // 当前下单轮次，初始 1
  created_at: Timestamp
  finished_at: Timestamp?
}

// 订单成员
OrderMember {
  id: UUID
  order_id: UUID         // -> Order.id
  user_id: UUID          // -> Profile.id
  joined_at: Timestamp
  // 约束：同一 user_id 在所有 status != finished 的订单中只能出现一次
}

// 订单菜品项
OrderItem {
  id: UUID
  order_id: UUID         // -> Order.id
  dish_id: UUID          // -> Dish.id
  added_by: UUID         // -> Profile.id
  quantity: Int
  status: Enum           // waiting | cooking | done
  order_round: Int       // 记录第几轮下单时加入，用于采购清单高亮
  created_at: Timestamp
}