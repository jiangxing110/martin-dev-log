# BB Auth CDC 斜杠字段修复方案

## 摘要

BB Auth CDC 启动时报 PostgreSQL `syntax error at or near "/"`。原因是 JDBC Source DDL 使用了 ``Trans Date / Time``、``Card Proxy`` 等带空格和斜杠的字段名，Flink JDBC 打开 Source 时生成列投影，PostgreSQL 将 `/` 解析为除号导致失败。

## 方案

- 参考 BB Auth batch/monthly-cdc，将 Source DDL 字段改为 `auth_time`、`card_proxy`、`auth_txn_guid` 等 snake_case。
- JDBC 子查询内部继续用双引号读取函数返回的原始字段，并显式别名为 snake_case。
- 下游 `v_auth_base` 统一改为引用 snake_case 字段。
- 保留默认昨天窗口和 `public.fn_bb_card_auth_detail_by_window` 函数入口。
- `source_qbit_card` 改为只读取昨天 Auth 窗口命中的 `Card Proxy` 对应卡，避免全量扫描 `ods.ods_qbit_card` 导致 TaskManager heartbeat timeout。
- 补充 `heartbeat.timeout = 600000`，与其它大窗口 CDC 作业保持一致。

## 验证

- CDC 文件不再包含会由 JDBC 投影到 PostgreSQL 的带斜杠字段名。
- Auth 时间过滤仍为 `[CURRENT_DATE - 1 day, CURRENT_DATE)`。
- `source_qbit_card` 不再裸扫 `ods.ods_qbit_card`。
- DWM 输出字段和 sink 逻辑不变。
