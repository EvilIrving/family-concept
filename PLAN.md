## 内购入账最终实现计划

### 摘要
`POST /kitchens/:id/iap/sync` 只接受 `signedTransaction` 作为可信输入，幂等键仅取自 Apple 验签成功后解析出的真实 `original_transaction_id`。  
服务端返回有限状态枚举，客户端只按状态驱动 UI；`pending_verification_failed` 只表示“本次同步失败”，不表示已有 entitlement 失效，`not_found` 严格等同于“从未购买且服务端无已生效权益”。

### 关键实现
`/iap/sync` 固定流程为：验签 `signedTransaction`、区分 sandbox 与 production、解析真实 `product_id` 与 `original_transaction_id`、校验 `app_account_token` 与当前账户及目标 `kitchen` 的绑定关系，然后进入单事务完成交易绑定与 entitlement upsert。  
数据库中交易绑定记录需包含 `kitchen_id`、`original_transaction_id`、`app_account_token_hash`、`last_seen_at`，并增加显式 `version` 或等价更新时间字段，用于排查多设备并发恢复时最终哪次写入形成快照；事务提交前外部读请求不能看到只绑交易未写 entitlement 的半完成状态。  
entitlement 状态枚举收敛为 `active`、`revoked`、`pending_verification_failed`、`not_found`。`active` 表示当前权益有效，`revoked` 表示该权益已被苹果撤销且当前无效，`pending_verification_failed` 表示本次同步失败但应继续返回现有已生效 entitlement 快照，`not_found` 只用于服务端确认当前厨房从未成功入账任何购买。  
客户端 `pendingEntitlementUpgrade` 仅承担“用户刚完成购买但服务端还未确认”的短时过渡语义，不与服务端状态混用；若服务端返回 `active` 则清除过渡态并展示真实权益，若返回 `pending_verification_failed` 则保留已生效老权益并提示同步失败可重试，若返回 `not_found` 才在过渡态超时后回落到未购买状态。  
完全幂等要求保持不变：同一已验证 `original_transaction_id` 的任意重复同步，包括旧设备与新设备同时恢复购买，都必须返回一致的状态语义与同一份最终 entitlement 快照。

### 测试
补齐四类关键场景：已有老权益时本次同步失败应返回 `pending_verification_failed` 且继续展示老权益，没有任何历史权益时失败不能伪装成 `not_found` 之外的有效套餐，同一 Apple 账号多设备并发恢复购买后状态一致，以及交易绑定 `version` 或更新时间在并发写入后能明确反映最终快照来源。  
继续覆盖伪造请求字段无效、响应丢失后的重试幂等、验签成功但事务失败后的重试、撤销后返回 `revoked`、以及兑换码后首次打开 App 经恢复购买进入同一主链路。

### 假设
当前版本仍不实现自动降级、叠加购买和跨厨房迁移。  
发布阻塞项保持为 JWS 验签、事务原子性、有限状态枚举、完全幂等和多设备并发恢复一致性。
