# finance CDC 触发范围统一修复方案

## 摘要

统一修复 `online/cdc/total_cost/finance` 下 v2 作业的月份触发条件，使其与各自删除函数和实际成本 provider 范围一致，避免无关月度标签更新导致重复主键写入。

## 方案

各作业继续按月重算、按 `report_date` 按天产出。月份触发查询仅读取本作业对应的 `product_line/provider` 标签：ACQUIRING 使用 OD/WP，CRYPTO_ASSET 使用各文件声明的 provider，GLOBAL_ACCOUNT 使用 BZ/CL 或 settlement 的 NULL provider，QUANTUM_CARD 使用各自 provider。保留 sink 的 `writeMode = 'insert'`。

对于月份参数嵌在 JDBC `table-name` 字符串中的作业，只修改内层“昨日变更月份”子查询，不限制外层读取该月份的完整标签数据。

## 验证

- 检查全部 13 个 v2 SQL 均有与作业范围匹配的触发过滤。
- 检查内嵌月份子查询不再使用无范围的昨日变更条件。
- 确认所有 sink 仍为 `writeMode = 'insert'`。
- 使用 `git diff --check` 检查格式。
