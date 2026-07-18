# 完整卡号/卡ID导出补充设计

## 背景
当前 `POST /api/admin/quantum/card/card-number/list` 已经承担“查询并导出卡私密信息”的职责，导出完成后会发送飞书机器人通知下载链接和密码。本次需求是在不新增接口的前提下，给这次导出的 Excel 补充经营与风控统计字段，并保证表头继续走现有国际化机制。

## 目标
- 保持现有接口、路径、通知链路不变。
- 在同一个方法内先查数据，再生成 Excel，再发送飞书机器人。
- 导出的 Excel 增加完整卡信息、近 30 天交易统计、主要交易商户详情、ATM 取现统计等列。
- 表头使用现有 `@ExcelProperty("{KEY}")` + `ExcelI18nHeaderCellWriteHandler` 方案，继续支持中英双语。
- 导出前增加限流，避免重复触发造成导出压力。

## 非目标
- 不新增新的对外接口。
- 不改飞书机器人通知模板逻辑。
- 不调整现有 `/export/3.0/完整卡号/卡ID查询-*.xlsx` 的文件命名风格。

## 总体方案
沿用现有 `cardNumberList` 方法作为唯一入口，改造为以下流程：
1. `exportService.acquireLimit("quantum_ka")` 获取导出限流。
2. 解析请求中的 `cardNumberList` / `cardIdList`，得到待导出的卡记录。
3. 批量查询卡基础信息与账户信息，补齐 `displayId`、`verifiedName`、卡创建时间、卡状态。
4. 批量查询近 30 天交易统计，按 `card_id` 汇总。
5. 生成 `ExcelExportBO<CardNumberListExportVO>` 并导出。
6. 保持现有飞书机器人通知逻辑不变，发送下载链接和密码。
7. `finally` 中释放限流。

## 数据口径
### 1. 卡基础信息
- 完整卡号：来自现有私密卡号查询逻辑，输入卡号直接带入，输入卡 ID 时通过 `QuantumCardCommService` 反查。
- 卡 ID：对应卡主键。
- `displayId`：来自 `account.displayId`。
- `verifiedName`：来自 `account.verifiedName`。
- 卡创建时间：来自 `qbitCard.createTime`。
- 卡状态：来自 `qbitCard.status`。

### 2. 近 30 天交易统计
统计对象统一基于 `quantum_card_transaction_extend`，按 `card_id` 分组。

- 近30天交易总笔数 / 总金额
  - 复用现有风控口径里的全量消费统计。
  - 笔数与金额沿用现成 SQL 片段的过滤条件，保持与系统内风控统计一致。
- 近30天拒付总笔数 / 总金额
  - 复用现有拒付口径。
- 近30天拒付率
  - 建议按 `拒付总笔数 / 近30天交易总笔数` 计算，分母为 0 时返回 0。
- 近30天强扣总笔数 / 总金额
  - `business_code_list` 包含 `1001` 的消费交易。
- 近30天退款总笔数 / 总金额
  - 复用现有退款口径。
- 近30天退款率
  - 建议按 `退款总笔数 / 近30天交易总笔数` 计算，分母为 0 时返回 0。
- 近30天0元授权笔数
  - 复用现有 `1010` 且不含 `1011` 的口径。
- 近30天主要交易商户Details
  - 以 `quantum_card_transaction_extend.detail` 为分组维度，按卡取出现次数最多的值。
  - 仅统计非空、非空白的 `detail`，输出众数。
- 近30天ATM取现总笔数 / 总金额
  - 按你确认的口径，统一使用 `business_code_list @> '1120'::jsonb`。

## 实现拆分
### 1. 新增导出 VO
新增 `CardNumberListExportVO`，字段全部用 `@ExcelProperty("{KEY}")` 标注，列顺序固定。

建议字段顺序：
1. 完整卡号
2. 卡ID
3. displayId
4. verifiedName
5. 卡创建时间
6. 卡状态
7. 近30天交易总金额
8. 近30天交易总笔数
9. 近30天拒付总金额
10. 近30天拒付总笔数
11. 近30天拒付率
12. 近30天强扣总金额
13. 近30天强扣总笔数
14. 近30天退款总金额
15. 近30天退款总笔数
16. 近30天退款率
17. 近30天0元授权笔数
18. 近30天主要交易商户Details
19. 近30天ATM取现总金额
20. 近30天ATM取现总笔数

### 2. 新增批量统计查询
在 `OdsQuantumCardTransactionExtendMapper` 增加一个导出专用批量查询方法，返回按 `card_id` 聚合的统计结果。

建议复用现有 XML 中的这些口径片段：
- `getAllConsumeCount`
- `getAllConsumeAmount`
- `getRejectCount`
- `getRejectAmount`
- `getCreditCount`
- `getCreditAmount`
- `getZeroAuthCount`

并补充：
- `mandatoryCount`
- `mandatoryAmount`
- `atmCount`
- `atmAmount`
- `mainMerchantDetail`（`MODE() WITHIN GROUP` / 众数）

### 3. 改造 `cardNumberList`
`QuantumCardService.cardNumberList` 改成：
- 先收集输入中的卡号与卡 ID。
- 再批量补齐卡号 / 卡 ID 映射。
- 再批量查询卡基础信息、账户信息、统计信息。
- 最后组装 `ExcelExportBO<CardNumberListExportVO>` 导出。

### 4. 限流
导出前后加上：
- `exportService.acquireLimit("quantum_ka")`
- `finally { exportService.releaseLimit("quantum_ka"); }`

### 5. 国际化
新增消息 key，沿用现有模板风格：
- `TENANT_ADMIN_EXPORT_CARD_NUMBER_SEARCH_*`

需要同时补充三份文件：
- `qbit-core/src/main/resources/i18n/messages.properties`
- `qbit-core/src/main/resources/i18n/messages_zh_CN.properties`
- `qbit-core/src/main/resources/i18n/messages_en_US.properties`

`ExcelI18nHeaderCellWriteHandler` 无需改动。

## 处理规则
- 数据为空时保持现有行为，继续抛出“没有数据可导出”的业务异常。
- 导出失败时保持现有异常处理与日志上下文。
- 金额字段保持 `BigDecimal`，比率字段保留小数格式，分母为 0 时统一返回 0。
- 导出通知逻辑保持现有飞书机器人两段通知不变。

## 验证建议
- 编译 `qbit-core` 确认新增 VO、mapper、service、i18n key 都能通过。
- 走一次本地导出流程，确认：
  - 文件路径仍为 `export/3.0/完整卡号/卡ID查询-*.xlsx`
  - Excel 表头中英双语可切换
  - `1120` ATM 列有值
  - 飞书机器人通知仍能发送下载链接和密码

