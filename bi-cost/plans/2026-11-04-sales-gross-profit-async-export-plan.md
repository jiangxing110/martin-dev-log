# 销售毛利异步导出实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Use checkbox (`- [ ]`) syntax to track progress.

**Goal:** 将销售毛利汇总和明细导出改成后台全量分页生成单个 CSV，并通过 WebSocket 推送下载通知。

**Architecture:** Controller 保留现有两个导出 URL 和筛选 DTO，但立即返回受理结果。Service 在请求线程校验筛选条件并捕获当前用户，后台任务恢复 `UserContext`，调用已有 ReportFactory CSV Handler 循环读取所有匹配页；所有页合并为一个 CSV 后调用一次 `notifyExport` 推送下载地址，不压缩为 ZIP。实现参考自然人黑名单的全量结果单文件导出流程。

**Tech Stack:** Java 17、Spring Boot、MyBatis-Plus、`CompletableFuture`、项目现有 `ReportFactory` / `AbstractReportHandler`、WebSocket 通知。

**Spec:** [销售毛利异步导出设计](../design-docs/2026-11-04-sales-gross-profit-async-export-design.md)

## Global Constraints

- 导出使用当前查询条件的全部匹配结果，不受页面分页游标限制。
- CSV Handler 按每页 500 条循环至空页；所有页面暂存后写入一个 CSV。
- 每个导出任务只通过 `admin_message_notice` WebSocket 推送一次，不打 ZIP。
- 单文件方案需要在生成前暂存全部查询结果，行为与黑名单导出一致；若后续明细数据量显著增大，再评估流式写入。
- 异步查询恢复发起用户的 `UserContext`，完成后清除线程上下文。
- 不改两个分页查询接口、SQL 数据口径、筛选条件和权限判断。
- 不编译、不提交、不推送；不新增或运行测试。

## Review Focus

- 查询结果超过 500 条：确认所有页面合并进同一个 CSV，最后一页不足 500 条也完整包含。
- 查询结果恰为 500 条整数倍：确认 Handler 的终止空页只用于停止循环，不产生额外文件。
- 无匹配记录：生成仅含表头的 CSV 并发送一次下载通知；导出异常时发送失败通知。
- 非管理员数据权限：确认后台线程恢复发起用户后，所有页仍受原数据权限过滤。
- 明细导出：确认 saleId、账户、产品和日期筛选进入后台 DTO；provider、metricCode 不作为请求筛选。

---

### Task 1: 将销售毛利导出切换为异步 CSV 通知

**Files:**
- Modify: `/Users/martinjiang/IdeaProjects/qbit-assets/qbit-core/src/main/java/com/qbit/admin/analysis/controller/reportform/v2/SalesGrossProfitController.java`
- Modify: `/Users/martinjiang/IdeaProjects/qbit-assets/qbit-core/src/main/java/com/qbit/common_all/analysis/service/salesgrossprofit/SalesGrossProfitService.java`
- Modify: `/Users/martinjiang/IdeaProjects/qbit-assets/qbit-core/src/main/java/com/qbit/common_all/analysis/service/impl/salesgrossprofit/SalesGrossProfitServiceImpl.java`
- Read/Reuse: `.../assets/service/report/salesgrossprofit/SalesGrossProfitSummaryCsvHandler.java`
- Read/Reuse: `.../assets/service/report/salesgrossprofit/SalesGrossProfitDetailCsvHandler.java`

**Interfaces:**
- Change `SalesGrossProfitService.exportSummary(SalesGrossProfitQueryDTO)` to return `void` after scheduling a job.
- Change `SalesGrossProfitService.exportDetail(SalesGrossProfitQueryDTO)` to return `void` after scheduling a job.
- Change the two controller export methods to return an empty success `Result` immediately.
- Keep each `exportUrl` handler's all-pages loop at 500 rows per page. Invoke it on a background thread with the correct summary/detail export DTO.
- On the background thread, set the captured `User` in `UserContext`, merge all queried pages into one CSV, notify that file URL once through the selected `AbstractReportHandler`, notify failure on an exception, and always call `UserContext.remove()`.

- [x] Update service and controller signatures so export requests return success without a file URL list.
- [x] Add shared async orchestration in `SalesGrossProfitServiceImpl` for export type and query DTO; retain synchronous validation and permission application before scheduling.
- [x] Capture the authenticated user before scheduling; set and clear `UserContext` in the worker; use existing `exportUrl` and `notifyExport` methods.
- [x] Generate one CSV per export task; the filename starts with `userId_yyyyMMddHHmmss` and includes report type, settlement month, and detail saleId when applicable.
- [x] Inspect source diffs for generic type compatibility, DTO field preservation, exception handling, and absence of build/test execution.
- [x] Run `git diff --check` only.

**Expected behavior:** HTTP returns an empty success payload promptly. After all matching pages are processed, the user receives one WebSocket download notification for the single CSV; an empty result produces a header-only CSV, while export errors trigger a failure notification. The existing endpoint paths and filter fields remain unchanged.
