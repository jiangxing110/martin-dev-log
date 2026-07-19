# BB DWM card transaction detail v2 性能优化 — 执行计划

## 进度
- [x] 完成 SQL 结构梳理
- [x] 改写结算匹配逻辑
- [x] 改写销售关系回溯逻辑
- [x] 自检变更和语义一致性
- [x] 明确需要平台侧 TaskManager 内存配置配合

## 步骤
1. 定位慢点并确认高风险 join。
2. 先拆分交易-结算匹配，消除 `OR` join。
3. 再合并 direct/root 销售关系候选集，减少重复扫描。
4. 检查最终输出字段、主键和写入语义是否保持不变。
5. 若仍报 buffer 不足，转为平台侧调整 TaskManager 内存，而不是继续改 SQL。
