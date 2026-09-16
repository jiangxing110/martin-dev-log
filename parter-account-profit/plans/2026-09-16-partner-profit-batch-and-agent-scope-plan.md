# 合伙人首页范围与返佣批次化改造执行计划

## 目标

完成二代 `Agent` 合伙人首页数据范围控制，并将 Assets 侧返佣计算改造成批次化计算、Partner 分页同步模式。

## 实施步骤

- [x] P0：重新确认三个项目的当前分支、模块依赖和公共 API 版本。
- [x] P0：在 Partner 项目增加用户类型和邀请码范围解析能力。
- [x] P0：统一首页余额、KYC、白标客户和量子卡趋势的客户范围参数。
- [x] P0：首页已完成二代 `Agent` 与普通合伙人的邀请码范围验证，可进入返佣批次化任务。
- [ ] 改造 Assets XXL-JOB，支持全部合伙人批量计算及指定合伙人补算；不新增批次表，批次号由任务参数或本次运行生成。
- [ ] 新增公共 API 的批次创建和分页推送 DTO/Feign 接口。
- [x] 删除 Partner 项目旧的主动拉取 Job；拉取接口和重复计算逻辑待批次推送接收链路完成后清理。
- [ ] 在 Partner 项目实现批次分页接收服务。
- [ ] 将 `sourceBatchNo`、`referredCustomerCount` 写入月度佣金及详情数据。
- [ ] 补充 Assets 和 Partner 的 service test、job test 及分页重试测试。
- [ ] 更新对接文档和数据质量校验 SQL。

## 关键约束

- 返佣三种模式一次返回。
- Excel 中的底价加价和弹性加价明细由 Assets 与毛利返佣一起推送，Partner 不再单独查询。
- 负毛利只在最终佣金结果处执行 0 下限。
- Partner 不重复计算 Assets 已完成的毛利返佣。
- 不保留旧 `pull` 兼容模式，直接切换为 Assets 主动推送。
- 生产批次和修复批次通过 `sourceBatchNo` 隔离。
- Assets 不持久化批次状态，Partner 通过 `sourceBatchNo + pageNo` 实现接收幂等。
- 未明确要求前不执行提交或推送。

## 验证项

- `Agent` 与非 `Agent` 的邀请码范围 SQL。
- API 主账户与子账户去重统计。
- Assets 批次重复执行幂等性。
- Assets 分页推送失败后的续推能力。
- 三种返佣模式金额与详情合计一致。
