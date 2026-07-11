# online

金融渠道成本脚本的新目录约定：

- `online/batch/`：可传入 `start_time/end_time` 的回刷脚本，适合定向补数和区间重跑
- `online/cdc/`：不传参数，默认读取昨天 `ods_bi_month_tag.update_time` 的变更

说明：

- `batch` 版本保留参数入口，但 SQL 里也带了默认昨天逻辑，方便手工和调度兼容
- `cdc` 版本去掉了 `${start_time}` / `${end_time}` 占位符，启动时不会再要求必填参数
