#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:8787/api/v1"
C="Content-Type: application/json"

auth_header() {
  printf 'Authorization: Bearer %s' "$1"
}

echo "===== 1. Health & Bootstrap ====="
curl -s "$BASE/health" | jq .
curl -s "$BASE/bootstrap" | jq .

echo ""
echo "===== 2. 注册账号 ====="
SUFFIX=$(date +%s)
OWNER_USER="owner_${SUFFIX}"
ADMIN_USER="admin_${SUFFIX}"
MEMBER_USER="member_${SUFFIX}"
PASSWORD="password123"

OWNER_REGISTER=$(curl -s -X POST "$BASE/auth/register" -H "$C" \
  -d "{\"user_name\":\"$OWNER_USER\",\"password\":\"$PASSWORD\",\"nick_name\":\"Owner老王\"}")
echo "$OWNER_REGISTER" | jq .
OWNER_TOKEN=$(echo "$OWNER_REGISTER" | jq -r '.token')

ADMIN_REGISTER=$(curl -s -X POST "$BASE/auth/register" -H "$C" \
  -d "{\"user_name\":\"$ADMIN_USER\",\"password\":\"$PASSWORD\",\"nick_name\":\"Admin小李\"}")
echo "$ADMIN_REGISTER" | jq .
ADMIN_TOKEN=$(echo "$ADMIN_REGISTER" | jq -r '.token')

MEMBER_REGISTER=$(curl -s -X POST "$BASE/auth/register" -H "$C" \
  -d "{\"user_name\":\"$MEMBER_USER\",\"password\":\"$PASSWORD\",\"nick_name\":\"Member小张\"}")
echo "$MEMBER_REGISTER" | jq .
MEMBER_TOKEN=$(echo "$MEMBER_REGISTER" | jq -r '.token')

echo "--- 重复 user_name 应 409 ---"
curl -s -X POST "$BASE/auth/register" -H "$C" \
  -d "{\"user_name\":\"$OWNER_USER\",\"password\":\"$PASSWORD\",\"nick_name\":\"重复用户\"}" | jq .

echo "--- 登录成功 ---"
OWNER_LOGIN=$(curl -s -X POST "$BASE/auth/login" -H "$C" \
  -d "{\"user_name\":\"$OWNER_USER\",\"password\":\"$PASSWORD\"}")
echo "$OWNER_LOGIN" | jq .
OWNER_TOKEN=$(echo "$OWNER_LOGIN" | jq -r '.token')

echo "--- 当前账号信息 ---"
curl -s "$BASE/auth/me" -H "$(auth_header "$OWNER_TOKEN")" | jq .

echo ""
echo "===== 3. Onboarding: 创建 kitchen ====="
CREATE_RESULT=$(curl -s -X POST "$BASE/onboarding/complete" -H "$C" -H "$(auth_header "$OWNER_TOKEN")" \
  -d "{\"mode\":\"create\",\"nick_name\":\"Owner老王\",\"kitchen_name\":\"老王的厨房\"}")
echo "$CREATE_RESULT" | jq .

KITCHEN_ID=$(echo "$CREATE_RESULT" | jq -r '.kitchen.id')
echo "Kitchen ID: $KITCHEN_ID"

echo ""
echo "===== 4. Onboarding: 加入 kitchen ====="
INVITE_CODE=$(echo "$CREATE_RESULT" | jq -r '.kitchen.invite_code')
echo "Invite code: $INVITE_CODE"

ADMIN_JOIN=$(curl -s -X POST "$BASE/onboarding/complete" -H "$C" -H "$(auth_header "$ADMIN_TOKEN")" \
  -d "{\"mode\":\"join\",\"nick_name\":\"Admin小李\",\"invite_code\":\"$INVITE_CODE\"}")
echo "$ADMIN_JOIN" | jq .

echo "--- 重复加入同一 kitchen 应返回已有成员 ---"
curl -s -X POST "$BASE/onboarding/complete" -H "$C" -H "$(auth_header "$ADMIN_TOKEN")" \
  -d "{\"mode\":\"join\",\"nick_name\":\"Admin小李\",\"invite_code\":\"$INVITE_CODE\"}" | jq .

curl -s -X POST "$BASE/onboarding/complete" -H "$C" -H "$(auth_header "$MEMBER_TOKEN")" \
  -d "{\"mode\":\"join\",\"nick_name\":\"Member小张\",\"invite_code\":\"$INVITE_CODE\"}" | jq .

echo ""
echo "===== 5. 查看 kitchen ====="
curl -s "$BASE/kitchens/$KITCHEN_ID" -H "$(auth_header "$OWNER_TOKEN")" | jq .

echo ""
echo "===== 6. 成员列表 ====="
curl -s "$BASE/kitchens/$KITCHEN_ID/members" -H "$(auth_header "$OWNER_TOKEN")" | jq .

echo ""
echo "===== 7. 修改 kitchen 名称 (owner) ====="
curl -s -X PATCH "$BASE/kitchens/$KITCHEN_ID" -H "$C" -H "$(auth_header "$OWNER_TOKEN")" \
  -d '{"name":"老王的私房菜"}' | jq .

echo "--- member 改名应 403 ---"
curl -s -X PATCH "$BASE/kitchens/$KITCHEN_ID" -H "$C" -H "$(auth_header "$MEMBER_TOKEN")" \
  -d '{"name":"不该成功"}' | jq .

echo ""
echo "===== 8. 刷新邀请码 ====="
curl -s -X POST "$BASE/kitchens/$KITCHEN_ID/rotate_invite" -H "$(auth_header "$OWNER_TOKEN")" | jq .

echo ""
echo "===== 9. 菜品 CRUD ====="
DISH1=$(curl -s -X POST "$BASE/kitchens/$KITCHEN_ID/dishes" -H "$C" -H "$(auth_header "$OWNER_TOKEN")" \
  -d '{"name":"宫保鸡丁","category":"热菜","ingredients":["鸡胸肉","花生","干辣椒"]}')
echo "$DISH1" | jq .
DISH1_ID=$(echo "$DISH1" | jq -r '.id')

DISH2=$(curl -s -X POST "$BASE/kitchens/$KITCHEN_ID/dishes" -H "$C" -H "$(auth_header "$OWNER_TOKEN")" \
  -d '{"name":"番茄炒蛋","category":"家常","ingredients":["番茄","鸡蛋"]}')
echo "$DISH2" | jq .
DISH2_ID=$(echo "$DISH2" | jq -r '.id')

echo "--- member 创建菜品应 403 ---"
curl -s -X POST "$BASE/kitchens/$KITCHEN_ID/dishes" -H "$C" -H "$(auth_header "$MEMBER_TOKEN")" \
  -d '{"name":"不该有","category":"test"}' | jq .

echo "--- 菜品列表 ---"
curl -s "$BASE/kitchens/$KITCHEN_ID/dishes" -H "$(auth_header "$OWNER_TOKEN")" | jq .

echo "--- 编辑菜品 ---"
curl -s -X PATCH "$BASE/dishes/$DISH1_ID" -H "$C" -H "$(auth_header "$OWNER_TOKEN")" \
  -d '{"name":"宫保鸡丁升级版","ingredients":["鸡胸肉","花生","干辣椒","葱段"]}' | jq .

echo "--- 归档菜品 ---"
curl -s -X DELETE "$BASE/dishes/$DISH2_ID" -H "$(auth_header "$OWNER_TOKEN")" | jq .

echo "--- 归档后列表 ---"
curl -s "$BASE/kitchens/$KITCHEN_ID/dishes" -H "$(auth_header "$OWNER_TOKEN")" | jq .

echo ""
echo "===== 10. 订单流程 ====="
echo "--- 创建订单 ---"
ORDER=$(curl -s -X POST "$BASE/kitchens/$KITCHEN_ID/orders" -H "$(auth_header "$OWNER_TOKEN")")
echo "$ORDER" | jq .
ORDER_ID=$(echo "$ORDER" | jq -r '.id')

echo "--- 活跃订单 ---"
curl -s "$BASE/kitchens/$KITCHEN_ID/orders/open" -H "$(auth_header "$OWNER_TOKEN")" | jq .

echo "--- 追加菜品 ---"
curl -s -X POST "$BASE/orders/$ORDER_ID/items" -H "$C" -H "$(auth_header "$OWNER_TOKEN")" \
  -d "{\"dish_id\":\"$DISH1_ID\",\"quantity\":2}" | jq .

curl -s -X POST "$BASE/orders/$ORDER_ID/items" -H "$C" -H "$(auth_header "$MEMBER_TOKEN")" \
  -d "{\"dish_id\":\"$DISH1_ID\",\"quantity\":1}" | jq .

echo "--- 活跃订单含 items ---"
OPEN_RESULT=$(curl -s "$BASE/kitchens/$KITCHEN_ID/orders/open" -H "$(auth_header "$OWNER_TOKEN")")
echo "$OPEN_RESULT" | jq .
ITEM_ID=$(echo "$OPEN_RESULT" | jq -r '.items[0].id')

echo "--- 改 item 状态 ---"
curl -s -X PATCH "$BASE/order_items/$ITEM_ID" -H "$C" -H "$(auth_header "$OWNER_TOKEN")" \
  -d '{"status":"cooking"}' | jq .

echo "--- member 改状态应 403 ---"
curl -s -X PATCH "$BASE/order_items/$ITEM_ID" -H "$C" -H "$(auth_header "$MEMBER_TOKEN")" \
  -d '{"status":"done"}' | jq .

echo "--- 采购清单 ---"
curl -s "$BASE/orders/$ORDER_ID/shopping_list" -H "$(auth_header "$OWNER_TOKEN")" | jq .

echo "--- member 结束订单应 403 ---"
curl -s -X POST "$BASE/orders/$ORDER_ID/finish" -H "$(auth_header "$MEMBER_TOKEN")" | jq .

echo "--- 结束订单 ---"
curl -s -X POST "$BASE/orders/$ORDER_ID/finish" -H "$(auth_header "$OWNER_TOKEN")" | jq .

echo "--- 活跃订单应为 null ---"
curl -s "$BASE/kitchens/$KITCHEN_ID/orders/open" -H "$(auth_header "$OWNER_TOKEN")" | jq .

echo ""
echo "===== 11. 踢人 & 退出 ====="
echo "--- owner 踢 member ---"
MEMBER_ACCOUNT_ID=$(curl -s "$BASE/kitchens/$KITCHEN_ID/members" -H "$(auth_header "$OWNER_TOKEN")" | jq -r '.[] | select(.nick_name=="Member小张") | .account_id')
echo "Member account ID: $MEMBER_ACCOUNT_ID"
curl -s -X DELETE "$BASE/kitchens/$KITCHEN_ID/members/$MEMBER_ACCOUNT_ID" -H "$(auth_header "$OWNER_TOKEN")" | jq .

echo "--- 成员列表 ---"
curl -s "$BASE/kitchens/$KITCHEN_ID/members" -H "$(auth_header "$OWNER_TOKEN")" | jq .

echo "--- admin 退出 ---"
curl -s -X POST "$BASE/kitchens/$KITCHEN_ID/leave" -H "$(auth_header "$ADMIN_TOKEN")" | jq .

echo "--- 最终成员列表 ---"
curl -s "$BASE/kitchens/$KITCHEN_ID/members" -H "$(auth_header "$OWNER_TOKEN")" | jq .

echo ""
echo "===== 12. 登出 ====="
curl -s -X POST "$BASE/auth/logout" -H "$(auth_header "$OWNER_TOKEN")" | jq .

echo "--- 登出后访问应 401 ---"
curl -s "$BASE/auth/me" -H "$(auth_header "$OWNER_TOKEN")" | jq .

echo ""
echo "===== All tests done ====="
