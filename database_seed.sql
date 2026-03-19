-- ===== Family v1 测试数据 =====
-- 使用前：
-- 1. 先在 Supabase Dashboard > Authentication > Users 创建测试用户
-- 2. 将下面的 UUID 替换为实际用户 ID
-- 3. 在 Supabase SQL Editor 中执行此脚本

do $$
declare
  -- ===== 配置区域：替换为你的用户 UUID =====
  -- 家庭1：张家（4口人）
  zhang_wei_id uuid := 'fd27cff5-62d6-4895-b715-c4033e30a9c7';      -- 张伟
  liu_fang_id uuid := '0662fe54-bfdc-4792-a986-f104da193cc6';       -- 刘芳
  zhang_hao_id uuid := '3c19623f-63a2-493c-ad58-cefda5186255';      -- 张浩
  zhang_yue_id uuid := 'db1825c3-e574-4a1f-91f4-eaec57f145a4';      -- 张悦

  -- 家庭2：李家（5口人）
  li_jun_id uuid := '4091aff7-77a4-4bbd-af9e-880779bf2999';         -- 李军
  wang_li_id uuid := '28095500-82e8-4bb7-8252-583ecc7b12e8';        -- 王丽
  li_chen_id uuid := 'f250af9e-a93c-47e3-8462-ea72e86bc7d2';        -- 李晨
  li_xue_id uuid := '9b87bcc7-8168-4e64-91e5-7c776a11f285';         -- 李雪
  chen_guifen_id uuid := '2801c6b1-2d22-48b2-852d-c77cda262739';    -- 陈桂芬

  -- 自动生成
  family1_id uuid := extensions.gen_random_uuid();
  family2_id uuid := extensions.gen_random_uuid();
begin
  -- ===== 1. 创建用户档案 =====
  insert into public.profiles (id, username, avatar_url) values
    -- 张家
    (zhang_wei_id, 'zhangwei', null),
    (liu_fang_id, 'liufang', null),
    (zhang_hao_id, 'zhanghao', null),
    (zhang_yue_id, 'zhangyue', null),
    -- 李家
    (li_jun_id, 'lijun', null),
    (wang_li_id, 'wangli', null),
    (li_chen_id, 'lichen', null),
    (li_xue_id, 'lixue', null),
    (chen_guifen_id, 'chenguifen', null)
  on conflict (id) do update set username = excluded.username;

  -- ===== 2. 创建家庭 =====
  insert into public.families (id, name, created_by, join_code) values
    (family1_id, '张家小厨', zhang_wei_id, 'ZHANG2024A'),
    (family2_id, '李家大院', li_jun_id, 'LIJIA2024B');

  -- ===== 3. 家庭成员 =====
  insert into public.family_members (family_id, user_id, role, invited_by) values
    -- 张家：张伟(owner)、刘芳(admin)、张浩(member)、张悦(member)
    (family1_id, zhang_wei_id, 'owner', zhang_wei_id),
    (family1_id, liu_fang_id, 'admin', zhang_wei_id),
    (family1_id, zhang_hao_id, 'member', liu_fang_id),
    (family1_id, zhang_yue_id, 'member', liu_fang_id),
    -- 李家：李军(owner)、王丽(admin)、李晨(member)、李雪(member)、陈桂芬(member)
    (family2_id, li_jun_id, 'owner', li_jun_id),
    (family2_id, wang_li_id, 'admin', li_jun_id),
    (family2_id, li_chen_id, 'member', wang_li_id),
    (family2_id, li_xue_id, 'member', wang_li_id),
    (family2_id, chen_guifen_id, 'member', li_jun_id);

  -- ===== 4. 张家菜品库 =====
  insert into public.dishes (family_id, name, category, ingredients, created_by) values
    -- 家常菜
    (family1_id, '番茄炒蛋', '家常菜', '["番茄 2个", "鸡蛋 3个", "小葱 2根", "盐 适量", "白糖 1小勺"]', liu_fang_id),
    (family1_id, '酸辣土豆丝', '家常菜', '["土豆 2个", "干辣椒 5个", "花椒 10粒", "陈醋 2勺", "蒜 3瓣"]', liu_fang_id),
    (family1_id, '蒜蓉炒青菜', '家常菜', '["上海青 1把", "蒜 4瓣", "盐 适量", "蚝油 1勺"]', liu_fang_id),
    (family1_id, '葱花蛋饼', '家常菜', '["鸡蛋 2个", "面粉 3勺", "小葱 3根", "盐 少许"]', zhang_yue_id),
    -- 肉类
    (family1_id, '红烧肉', '肉类', '["五花肉 500g", "冰糖 30g", "生抽 2勺", "老抽 1勺", "料酒 2勺", "八角 2个", "桂皮 1小块", "姜 3片"]', zhang_wei_id),
    (family1_id, '可乐鸡翅', '肉类', '["鸡翅中 8个", "可乐 1罐", "生抽 2勺", "姜 3片", "蒜 2瓣"]', liu_fang_id),
    (family1_id, '糖醋排骨', '肉类', '["小排 400g", "白糖 3勺", "陈醋 2勺", "番茄酱 2勺", "料酒 1勺"]', liu_fang_id),
    (family1_id, '蒜香排骨', '肉类', '["排骨 500g", "蒜 1整头", "生抽 2勺", "蚝油 1勺", "黑胡椒 适量"]', zhang_wei_id),
    -- 海鲜
    (family1_id, '清蒸鲈鱼', '海鲜', '["鲈鱼 1条", "姜丝 适量", "葱丝 适量", "蒸鱼豉油 2勺", "料酒 1勺"]', liu_fang_id),
    (family1_id, '蒜蓉粉丝蒸虾', '海鲜', '["大虾 10只", "粉丝 1把", "蒜 1整头", "蒸鱼豉油 2勺", "小米椒 2个"]', liu_fang_id),
    -- 蔬菜
    (family1_id, '蒜蓉西兰花', '蔬菜', '["西兰花 1个", "蒜 4瓣", "蚝油 1勺", "盐 适量"]', liu_fang_id),
    (family1_id, '干煸四季豆', '蔬菜', '["四季豆 300g", "肉末 50g", "干辣椒 5个", "蒜 3瓣", "芽菜 1勺"]', zhang_wei_id),
    (family1_id, '虎皮青椒', '蔬菜', '["青椒 5个", "蒜 3瓣", "生抽 1勺", "陈醋 1勺", "白糖 半勺"]', zhang_hao_id),
    -- 汤类
    (family1_id, '番茄蛋花汤', '汤类', '["番茄 2个", "鸡蛋 2个", "香菜 少许", "盐 适量"]', liu_fang_id),
    (family1_id, '紫菜蛋花汤', '汤类', '["紫菜 1小把", "鸡蛋 1个", "虾皮 1勺", "香油 几滴"]', liu_fang_id),
    -- 主食
    (family1_id, '蛋炒饭', '主食', '["隔夜饭 1碗", "鸡蛋 2个", "火腿 50g", "青豆 30g", "玉米粒 30g", "葱花 适量"]', zhang_hao_id),
    (family1_id, '葱油拌面', '主食', '["细面 200g", "小葱 5根", "生抽 2勺", "老抽 半勺"]', zhang_hao_id);

  -- ===== 5. 李家菜品库 =====
  insert into public.dishes (family_id, name, category, ingredients, created_by) values
    -- 家常菜
    (family2_id, '西红柿炒鸡蛋', '家常菜', '["西红柿 3个", "鸡蛋 4个", "葱 1根", "盐 适量", "糖 少许"]', wang_li_id),
    (family2_id, '醋溜白菜', '家常菜', '["白菜 半颗", "干辣椒 3个", "陈醋 2勺", "蒜 3瓣"]', chen_guifen_id),
    (family2_id, '尖椒炒肉丝', '家常菜', '["猪肉 200g", "尖椒 3个", "蒜 2瓣", "生抽 1勺"]', wang_li_id),
    (family2_id, '香煎荷包蛋', '家常菜', '["鸡蛋 4个", "盐 少许", "生抽 1勺"]', li_xue_id),
    -- 肉类
    (family2_id, '红烧牛腩', '肉类', '["牛腩 600g", "土豆 2个", "胡萝卜 1根", "八角 2个", "香叶 3片", "豆瓣酱 1勺"]', li_jun_id),
    (family2_id, '回锅肉', '川菜', '["五花肉 300g", "蒜苗 2根", "青椒 2个", "豆瓣酱 1勺", "甜面酱 1勺"]', li_jun_id),
    (family2_id, '宫保鸡丁', '川菜', '["鸡胸肉 300g", "花生 50g", "干辣椒 10个", "黄瓜 1根", "花椒 20粒"]', li_jun_id),
    (family2_id, '麻婆豆腐', '川菜', '["嫩豆腐 1块", "肉末 100g", "豆瓣酱 1勺", "花椒粉 适量", "葱花 适量"]', wang_li_id),
    (family2_id, '水煮肉片', '川菜', '["猪里脊 300g", "豆芽 200g", "莴笋 1根", "干辣椒 15个", "花椒 30粒"]', li_jun_id),
    (family2_id, '辣子鸡', '川菜', '["鸡腿 3个", "干辣椒 20个", "花椒 一把", "白芝麻 适量"]', li_jun_id),
    -- 海鲜
    (family2_id, '蒜蓉蒸扇贝', '海鲜', '["扇贝 10个", "粉丝 1把", "蒜 1整头", "小米椒 2个"]', wang_li_id),
    (family2_id, '清蒸螃蟹', '海鲜', '["大闸蟹 4只", "姜 适量", "醋 适量"]', li_jun_id),
    (family2_id, '油焖大虾', '海鲜', '["大虾 500g", "番茄酱 2勺", "白糖 1勺", "料酒 1勺"]', wang_li_id),
    -- 蔬菜
    (family2_id, '地三鲜', '蔬菜', '["茄子 1个", "土豆 1个", "青椒 2个", "蒜 3瓣", "生抽 2勺"]', chen_guifen_id),
    (family2_id, '蒜蓉空心菜', '蔬菜', '["空心菜 1把", "蒜 4瓣", "盐 适量"]', wang_li_id),
    (family2_id, '凉拌黄瓜', '凉菜', '["黄瓜 2根", "蒜 3瓣", "陈醋 2勺", "辣椒油 1勺", "香油 1勺"]', li_xue_id),
    (family2_id, '凉拌木耳', '凉菜', '["黑木耳 100g", "蒜 3瓣", "香菜 适量", "陈醋 2勺", "辣椒油 1勺"]', chen_guifen_id),
    -- 汤类
    (family2_id, '酸辣汤', '汤类', '["豆腐 半块", "木耳 50g", "鸡蛋 1个", "火腿 30g", "陈醋 2勺", "胡椒粉 适量"]', chen_guifen_id),
    (family2_id, '冬瓜排骨汤', '汤类', '["排骨 300g", "冬瓜 400g", "姜 3片", "枸杞 10粒"]', wang_li_id),
    (family2_id, '玉米排骨汤', '汤类', '["排骨 300g", "玉米 1根", "胡萝卜 1根", "姜 3片"]', wang_li_id),
    -- 主食
    (family2_id, '扬州炒饭', '主食', '["米饭 2碗", "鸡蛋 2个", "火腿 80g", "虾仁 50g", "青豆 30g", "玉米粒 30g"]', li_chen_id),
    (family2_id, '担担面', '主食', '["面条 300g", "肉末 100g", "花生碎 30g", "芝麻酱 2勺", "辣椒油 2勺"]', li_jun_id),
    (family2_id, '酸辣粉', '主食', '["红薯粉 200g", "花生 30g", "黄豆 30g", "香菜 适量", "陈醋 2勺"]', li_xue_id),
    (family2_id, '韭菜盒子', '主食', '["韭菜 200g", "鸡蛋 3个", "粉丝 1把", "面粉 300g"]', chen_guifen_id);

  -- ===== 6. 张家订单 =====
  insert into public.orders (family_id, status, created_by, placed_at, finished_at) values
    (family1_id, 'finished', zhang_wei_id, now() - interval '3 days', now() - interval '3 days' + interval '90 minutes');

  -- ===== 7. 李家订单 =====
  insert into public.orders (family_id, status, created_by) values
    (family2_id, 'ordering', wang_li_id);

  raise notice '==========================================';
  raise notice '测试数据插入完成！';
  raise notice '==========================================';
  raise notice '';
  raise notice '【张家小厨】4 人 | 邀请码: ZHANG2024A';
  raise notice '  - zhangwei (张伟/owner)';
  raise notice '  - liufang (刘芳/admin)';
  raise notice '  - zhanghao (张浩/member)';
  raise notice '  - zhangyue (张悦/member)';
  raise notice '  - 菜品: 17 道';
  raise notice '';
  raise notice '【李家大院】5 人 | 邀请码: LIJIA2024B';
  raise notice '  - lijun (李军/owner)';
  raise notice '  - wangli (王丽/admin)';
  raise notice '  - lichen (李晨/member)';
  raise notice '  - lixue (李雪/member)';
  raise notice '  - chenguifen (陈桂芬/member)';
  raise notice '  - 菜品: 24 道（川菜为主）';
  raise notice '';
  raise notice '==========================================';
end $$;
