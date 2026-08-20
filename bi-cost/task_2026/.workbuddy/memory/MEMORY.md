# 项目长期记忆 (qbit-card-cost-cleaning / task_2026)

## Flink v2 脚本约定（flink_reference/）
- 生成器 `gen_all_jobs.py` 解析 `../insert_task_job.sql`（23 个 INSERT 目标表）→ 每表 4 件套。
- 文件命名（参考 bb 项目 `quantum-v2/bb` 风格）：
  - `table/<base>_ddl.sql`、`table/register_fn_<base>_cdc_delete_v2.sql`
  - `cdc/<base>_v2-cdc-sql.sql`
  - `batch/<base>_v2-batch-sql.sql`
- 唯一 key = `id = ABS(HASH_CODE(CONCAT(业务键)))`，sink 声明 `PRIMARY KEY (id) NOT ENFORCED` + `writeMode='upsert'`。
- 删除范式：非 sale 表「按唯一业务键精准删」；sale 表（11 张：9×dws_sale_* + ods_sale_fund_profits + ods_sale_qbit_card）「按(日期,账户)作用域删」+ 三通道变更窗口(create/update/deleteTime)。sale 表保留单列 `sale_or_am_id`(unnest 扇出两行)。
- 分表 `_2024/_2025/_2026/_2027`：删除函数按源 createTime 年份动态路由；Flink 按 create_date 年份分发 INSERT。
- ODS 原始表用源表自然主键（ODS_KEYS 字典）。

## 已知遗留风险
- 非 sale 表 status 晚翻转可能产生旧 status 残留行（按当前 key 删不到旧行）。sale 表已规避。
- 2 张 ODS UNION 表（ods_sale_fund_profits / ods_sale_qbit_card）生成脚本打 `[TODO]`，上线前人工复核 affected-key 子查询。

## 重生成命令
- `python3 gen_all_jobs.py`（在 flink_reference/ 下，依赖 `../insert_task_job.sql` 存在）。
