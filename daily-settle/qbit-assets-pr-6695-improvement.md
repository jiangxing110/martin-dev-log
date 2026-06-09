# qbit-assets PR 6695 改进建议

日期：2026-06-05  
范围：日账单 API、Distributor 导出、异步重生成、Excel 生成链路

## 背景

这次 PR 已经把日账单的主链路搭起来了，包括在线导出、异步重生成、Distributor ZIP 导出、任务进度查询和 Excel 模板填充。
整体方向是对的，但现在仍然有几处会影响线上稳定性、账单准确性和后续维护的点，建议在合并前再收一轮。

## 优先级最高的问题

### 1. 重生成任务会先落库，再抢执行占位

当前 `regenerate()` 的顺序是先 `initProgress()`，再去抢 `runningKey`。如果同一账单已经在跑，后进来的请求会直接返回旧任务 ID，但新建出来的 `task_progress` 记录不会被回滚，容易留下孤儿任务。

建议：

- 先抢 `runningKey`，成功后再创建 `task_progress`
- 如果必须先创建任务，也要在复用旧任务时主动清理刚插入的进度记录

### 2. Distributor 导出会吞掉 master 失败，导致半成品 ZIP

Distributor 导出里，单个 master 查询异常会被记录后返回 `null`，外层只要还有其他 master 成功，就继续打 ZIP 并返回成功。
这类账单属于金融结果导出，静默缺页比直接失败更危险，用户很容易拿着不完整文件继续使用。

建议：

- 任一 master 失败时，整单失败
- 或者明确在结果里标记哪些 master 失败，并在文件名/任务状态中体现“部分失败”

### 3. Excel 公式追加行数少算了一行

`buildBalanceSheetData()` 已经额外追加了 `USD Total` 汇总行，但 `appendBalanceFormulas()` 仍然只接收 `balanceSummaries.size()`。
这样公式说明区的起始行会比实际数据位置提前一行，存在模板错位或覆盖内容的风险。

建议：

- 传入真实写入的余额行数
- 或者让公式 writer 根据 sheet 实际末行自动定位，不要依赖外部传参

## 中优先级问题

### 4. 账单日期校验仍建议收紧到 Controller 边界

目前日期校验依赖 service 内部的 `LocalDate.parse()` 和业务判断，虽然能拦住非法值，但不够直观。
对外接口最好在 DTO / Controller 边界就把格式和范围限定住，避免错误参数一路走到业务层才报异常。

建议：

- `StatementExportReqDTO` 补日期格式校验
- `regenerate` 的路径参数也补边界校验或统一封装成 DTO

### 5. `hasTransactions()` 与 `exportXlsx()` / `regenerate()` 的检查口径需要统一说明

当前前置判断和真正导出逻辑都在查交易，但 Distributor、Gateway、普通户的目标范围并不完全一样。
如果后续再扩展账户类型，容易出现“前置判断通过，真正生成失败”或相反的问题。

建议：

- 把“是否存在可导出交易”的判断抽成统一的领域方法
- 明确每种 accessType 的查询口径，并写进注释或文档

## 代码维护性建议

### 6. `DailyStatementServiceImpl` 责任太重

这个类现在同时负责：

- 权限校验
- 日期校验
- 账户类型路由
- 多账户并行查询
- Distributor ZIP 打包
- 重生成幂等和限流
- 任务进度创建与查询
- Excel 模板填充和公式追加

建议后续按职责拆分：

- `DailyStatementExportService`
- `DailyStatementRegenerateService`
- `DailyStatementDistributorService`
- `DailyStatementProgressService`

先不急着大拆，但建议至少把 Distributor、重生成、Excel 构建这些大块继续下沉成独立组件，避免 service impl 继续膨胀。

### 7. Distributor 导出建议改为流式打包

当前实现会先把所有 master 的 XLSX 都放进 `List<byte[]>`，再统一写 ZIP。
当 master 数量或单个账单体积较大时，内存压力会明显上升。

建议：

- 改为边生成边写 `ZipOutputStream`
- 不要同时保存所有 `byte[]`

## 推荐改造顺序

1. 先调整 `regenerate()` 的任务创建和 running 锁顺序
2. 再把 Distributor 的“局部成功”改成“明确失败”或“明确部分失败”
3. 修正 Excel 公式追加的行数偏差
4. 补齐 DTO / Controller 边界校验
5. 再考虑把 service 继续拆小和把 ZIP 改成流式写入

## 验证建议

建议补这几类测试或回归检查：

- 同一 `accountId + date` 重复点击 regenerate，是否只保留一个有效任务
- Distributor 某个 master 查询失败时，是否会整单失败
- 生成的 Excel 中 USD 汇总行和公式说明区是否位置正确
- 账单日期传今天、未来日期、超过 90 天时是否都能正确拦截

