# bi_month_tag 全量同步新增 account_id 执行计划

## 目标

新增 `public.bi_month_tag` 到 `ods.ods_bi_month_tag` 的全量同步脚本，并同步 `account_id`。

## 步骤

- [x] 新增方案对应的全量同步 SQL。
- [x] 执行字段存在性、字段顺序和 SQL 格式静态检查。
- [x] 记录变更日志并交付，默认不执行 git commit/push。

## 文件

- Create: `month-tag/bi_month_tag_full_sync.sql`
- Create: `design-docs/2026-09-17-bi-month-tag-full-sync-account-id-design.md`
- Create: `plans/2026-09-17-bi-month-tag-full-sync-account-id-plan.md`
- Create: `changelogs/2026-09-17-bi-month-tag-full-sync-account-id.md`
