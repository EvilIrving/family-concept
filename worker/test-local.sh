#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:8787/api/v1"
C="Content-Type: application/json"

echo "===== 1. Health & Bootstrap ====="
curl -s "$BASE/health" | jq .
curl -s "$BASE/bootstrap" | jq .

echo ""
echo "===== 2. 设备注册 ====="
DEVICE_A="test-device-aaa-$(date +%s)"
DEVICE_B="test-device-bbb-$(date +%s)"
DEVICE_C="test-device-ccc-$(date +%s)"

curl -s -X POST "$BASE/devices/register" -H "$C" \
  -d "{\"device_id\":\"$DEVICE_A\",\"display_name\":\"Owner老王\"}" | jq .

curl -s -X POST "$BASE/devices/register" -H "$C" \
  -d "{\"device_id\":\"$DEVICE_B\",\"display_name\":\"Admin小李\"}" | jq .

curl -s -X POST "$BASE/devices/register" -H "$C" \
  -d "{\"device_id\":\"$DEVICE_C\",\"display_name\":\"Member小张\"}" | jq .

# 重复注册应返回 409
echo "--- 重复注册应 409 ---"
curl -s -X POST "$BASE/devices/register" -H "$C" \
  -d "{\"device_id\":\"$DEVICE_A\",\"display_name\":\"Owner老王\"}" | jq .

echo ""
echo "===== 3. Onboarding: 创建 kitchen ====="
CREATE_RESULT=$(curl -s -X POST "$BASE/onboarding/complete" -H "$C" \
  -d "{\"mode\":\"create\",\"device_id\":\"$DEVICE_A\",\"display_name\":\"Owner老王\",\"kitchen_name\":\"老王的厨房\"}")
echo "$CREATE_RESULT" | jq .

KITCHEN_ID=$(echo "$CREATE_RESULT" | jq -r '.kitchen.id')
echo "Kitchen ID: $KITCHEN_ID"

echo ""
echo "===== 4. Onboarding: 加入 kitchen ====="
# 先拿邀请码
INVITE_CODE=$(echo "$CREATE_RESULT" | jq -r '.kitchen.invite_code')
echo "Invite code: $INVITE_CODE"

JOIN_RESULT=$(curl -s -X POST "$BASE/onboarding/complete" -H "$C" \
  -d "{\"mode\":\"join\",\"device_id\":\"$DEVICE_B\",\"display_name\":\"Admin小李\",\"invite_code\":\"$INVITE_CODE\"}")
echo "$JOIN_RESULT" | jq .

# 第三个人也加入
curl -s -X POST "$BASE/onboarding/complete" -H "$C" \
  -d "{\"mode\":\"join\",\"device_id\":\"$DEVICE_C\",\"display_name\":\"Member小张\",\"invite_code\":\"$INVITE_CODE\"}" | jq .

echo ""
echo "===== 5. 查看 kitchen ====="
curl -s "$BASE/kitchens/$KITCHEN_ID" -H "X-Device-Id: $DEVICE_A" | jq .

echo ""
echo "===== 6. 成员列表 ====="
curl -s "$BASE/kitchens/$KITCHEN_ID/members" -H "X-Device-Id: $DEVICE_A" | jq .

echo ""
echo "===== 7. 修改 kitchen 名称 (owner) ====="
curl -s -X PATCH "$BASE/kitchens/$KITCHEN_ID" -H "$C" -H "X-Device-Id: $DEVICE_A" \
  -d '{"name":"老王的私房菜"}' | jq .

# member 尝试改名应 403
echo "--- member 改名应 403 ---"
curl -s -X PATCH "$BASE/kitchens/$KITCHEN_ID" -H "$C" -H "X-Device-Id: $DEVICE_C" \
  -d '{"name":"不该成功"}' | jq .

echo ""
echo "===== 8. 刷新邀请码 ====="
curl -s -X POST "$BASE/kitchens/$KITCHEN_ID/rotate_invite" -H "X-Device-Id: $DEVICE_A" | jq .

echo ""
echo "===== 9. 菜品 CRUD ====="
# 创建菜品 (owner)
DISH1=$(curl -s -X POST "$BASE/kitchens/$KITCHEN_ID/dishes" -H "$C" -H "X-Device-Id: $DEVICE_A" \
  -d '{"name":"宫保鸡丁","category":"热菜","ingredients":["鸡胸肉","花生","干辣椒"]}')
echo "$DISH1" | jq .
DISH1_ID=$(echo "$DISH1" | jq -r '.id')

DISH2=$(curl -s -X POST "$BASE/kitchens/$KITCHEN_ID/dishes" -H "$C" -H "X-Device-Id: $DEVICE_A" \
  -d '{"name":"番茄炒蛋","category":"家常","ingredients":["番茄","鸡蛋"]}')
echo "$DISH2" | jq .
DISH2_ID=$(echo "$DISH2" | jq -r '.id')

# member 创建菜品应 403
echo "--- member 创建菜品应 403 ---"
curl -s -X POST "$BASE/kitchens/$KITCHEN_ID/dishes" -H "$C" -H "X-Device-Id: $DEVICE_C" \
  -d '{"name":"不该有","category":"test"}' | jq .

# 列表
echo "--- 菜品列表 ---"
curl -s "$BASE/kitchens/$KITCHEN_ID/dishes" -H "X-Device-Id: $DEVICE_A" | jq .

# 编辑菜品
echo "--- 编辑菜品 ---"
curl -s -X PATCH "$BASE/dishes/$DISH1_ID" -H "$C" -H "X-Device-Id: $DEVICE_A" \
  -d '{"name":"宫保鸡丁升级版","ingredients":["鸡胸肉","花生","干辣椒","葱段"]}' | jq .

# 归档菜品
echo "--- 归档菜品 ---"
curl -s -X DELETE "$BASE/dishes/$DISH2_ID" -H "X-Device-Id: $DEVICE_A" | jq .

# 列表应只剩 1 个
echo "--- 归档后列表 ---"
curl -s "$BASE/kitchens/$KITCHEN_ID/dishes" -H "X-Device-Id: $DEVICE_A" | jq .

echo ""
echo "===== 10. 订单流程 ====="
# 创建订单
echo "--- 创建订单 ---"
ORDER=$(curl -s -X POST "$BASE/kitchens/$KITCHEN_ID/orders" -H "X-Device-Id: $DEVICE_A")
echo "$ORDER" | jq .
ORDER_ID=$(echo "$ORDER" | jq -r '.id')

# 查看活跃订单
echo "--- 活跃订单 ---"
curl -s "$BASE/kitchens/$KITCHEN_ID/orders/open" -H "X-Device-Id: $DEVICE_A" | jq .

# 追加菜品
echo "--- 追加菜品 ---"
curl -s -X POST "$BASE/orders/$ORDER_ID/items" -H "$C" -H "X-Device-Id: $DEVICE_A" \
  -d "{\"dish_id\":\"$DISH1_ID\",\"quantity\":2}" | jq .

curl -s -X POST "$BASE/orders/$ORDER_ID/items" -H "$C" -H "X-Device-Id: $DEVICE_C" \
  -d "{\"dish_id\":\"$DISH1_ID\",\"quantity\":1}" | jq .

# 再次查看活跃订单（含 items）
echo "--- 活跃订单含 items ---"
OPEN_RESULT=$(curl -s "$BASE/kitchens/$KITCHEN_ID/orders/open" -H "X-Device-Id: $DEVICE_A")
echo "$OPEN_RESULT" | jq .
ITEM_ID=$(echo "$OPEN_RESULT" | jq -r '.items[0].id')

# 改 item 状态 (owner)
echo "--- 改 item 状态 ---"
curl -s -X PATCH "$BASE/order_items/$ITEM_ID" -H "$C" -H "X-Device-Id: $DEVICE_A" \
  -d '{"status":"cooking"}' | jq .

# member 改状态应 403
echo "--- member 改状态应 403 ---"
curl -s -X PATCH "$BASE/order_items/$ITEM_ID" -H "$C" -H "X-Device-Id: $DEVICE_C" \
  -d '{"status":"done"}' | jq .

# 采购清单
echo "--- 采购清单 ---"
curl -s "$BASE/orders/$ORDER_ID/shopping_list" -H "X-Device-Id: $DEVICE_A" | jq .

# 结束订单 (member 不行)
echo "--- member 结束订单应 403 ---"
curl -s -X POST "$BASE/orders/$ORDER_ID/finish" -H "X-Device-Id: $DEVICE_C" | jq .

# 结束订单 (owner)
echo "--- 结束订单 ---"
curl -s -X POST "$BASE/orders/$ORDER_ID/finish" -H "X-Device-Id: $DEVICE_A" | jq .

# 活跃订单应为 null
echo "--- 活跃订单应为 null ---"
curl -s "$BASE/kitchens/$KITCHEN_ID/orders/open" -H "X-Device-Id: $DEVICE_A" | jq .

echo ""
echo "===== 11. 踢人 & 退出 ====="
# owner 踢 member
echo "--- owner 踢 member ---"
# 先拿到 member 的 device_ref_id (即 devices 表的 id，不是 device_id)
MEMBER_C_INTERNAL_ID=$(curl -s "$BASE/kitchens/$KITCHEN_ID/members" -H "X-Device-Id: $DEVICE_A" | jq -r '.[] | select(.role=="member") | .device_ref_id')
echo "Member internal ID: $MEMBER_C_INTERNAL_ID"
curl -s -X DELETE "$BASE/kitchens/$KITCHEN_ID/members/$MEMBER_C_INTERNAL_ID" -H "X-Device-Id: $DEVICE_A" | jq .

# 验证只剩 2 人
echo "--- 成员列表 ---"
curl -s "$BASE/kitchens/$KITCHEN_ID/members" -H "X-Device-Id: $DEVICE_A" | jq .

# admin 退出
echo "--- admin 退出 ---"
curl -s -X POST "$BASE/kitchens/$KITCHEN_ID/leave" -H "X-Device-Id: $DEVICE_B" | jq .

# 只剩 owner
echo "--- 最终成员列表 ---"
curl -s "$BASE/kitchens/$KITCHEN_ID/members" -H "X-Device-Id: $DEVICE_A" | jq .

echo ""
echo "===== All tests done ====="
