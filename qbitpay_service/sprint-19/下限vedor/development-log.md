# Vendor 写接口关停开发记录

## 本次改动

按需求从 GraphQL schema 移除商户侧公司开户写接口，并关闭所有 `Vendor` 开户费缴费入口；不为 317764 留接口例外。全球账户和海外版开户费缴费流程、Admin 查询与审批流程保持不变。

## 文件变更

### `src/modules/vendor/vendor.resolver.ts`

- 注释 `createVendor`、`resubmitVendor`、`updateVendor` 三个 resolver 方法，使 Nest GraphQL schema 不再暴露对应 Mutation。
- 保留 service 实现，不影响其他内部逻辑或现有服务层测试。

### `graphql/test-graphql-api.graphql`

- 移除上述三个 Mutation 字段及其描述。

### `src/modules/account-charging/account-charging.resolver.ts`

- `payAccountCharging` 只在 `type=Vendor` 时返回“公司开户缴费已关闭”。
- 其他收费类型继续调用原有服务。
- Admin 的 `updateAccountCharging` resolver 和共用收费 service 未修改。

## 检查记录

- `git diff --check`：通过。
- 人工检查 diff：三项 Mutation 字段已从 schema 快照移除；Vendor 缴费按类型拦截；Admin 收费更新路径未改。
- 未运行测试或构建。
