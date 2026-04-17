shopping list 根据食材数量调整高度。最大不超过 2/3 屏幕，最小不少于 1/4 屏幕

我喜欢的菜

今日推荐(根据最常吃的菜)

真的有好多事情要做，到底该怎么规划才能有条不紊的推进？

后端和前端如何同步开发？

先约束好数据库 schema，然后根据 schema 开发后端和前端。

如何测试 不同的角色 不同的权限？

数据库：

devices table
dishs table
orders table
kitchens table
members table
invites table

order_items table

ingredients 用 json 存 
后端：

生成 device_id, display_name，并存入数据库。
创建厨房、加入厨房、成员列表
生成 invite_code，并存入数据库。
菜品增删改查、订单创建查询流转、历史订单分页查询、
上传菜品：name image 食材
订单：所属厨房 有哪些菜 制作状态 创建时间 结束时间 菜是谁点的
历史订单：历史数据

更改权限：owner 改 member 为 admin， 或者降级

解散厨房：owner 解散

image 处理：去背景 检查主体  格式转换 AVIF 

前端：

区分角色会有一些不一样的显示和行为。

生成 logo 删除多余文字



发布前要做好的事情

多语言
编辑显示图片 编辑操作优化
图片主体提取后粒子消散效果
内购模式： 免费 10个菜  100个菜以内 2美元， 无限制 10美元
增加一个导出备份功能，会调用接口把所有数据全部download下载一个 zip 包
删除账号









发布要做的事情
先发布 testflight 测试




