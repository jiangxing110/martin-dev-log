# Sales Commission Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an asynchronous sales commission Excel export with a department-specific one-sheet or four-sheet layout.

**Architecture:** The controller starts an export through the existing `ReportFactory` / `AbstractReportHandler` flow. The handler restores the requesting user context, loads snapshot details or falls back to the estimate view, converts rows into the department-specific sheet models, uploads the workbook, and notifies the user. The existing commission service remains responsible for permission checks and production/local mapper routing.

**Tech Stack:** Java 17, Spring Boot 3, MyBatis XML, JUnit 5, EasyExcel, `ReportFactory`, `ExportService`.

**Spec:** [Sales Commission Export Plan.md](Sales%20Commission%20Export%20Plan.md)

## Global Constraints

- New Java classes have Chinese class comments and `@author`; new public methods have Chinese Javadoc.
- New classes use `@RequiredArgsConstructor` and `private final` constructor injection; do not use wildcard imports, `BeanUtils.copyProperties`, or swallowed exceptions.
- Excel row fields have precise Chinese Javadocs and exact Chinese headers.
- User and department identity comes from trusted login/data records; the request only supplies `saleId` and `settlementMonth`.
- Do not create a branch, commit, push, merge, or PR.
- Complete all source and test edits before running tests/build; before that, only perform source review and `git diff --check`.

## Review Focus

- Unauthorized target sale: export is rejected before a background task is queued; cover in Task 3.
- Snapshot absent: estimate-view details are selected; cover both branches in Task 3.
- Overseas Sales Department 2: exactly one sheet and exactly five headers in the required order; cover in Task 2.
- Other departments: exactly four product sheets and exactly ten headers in each, including empty-data exports; cover in Task 2.
- API actual receipts: blank/null channel rows in `current_payout` are included and receivable/future rows are excluded; cover in Task 1.

---

### Task 1: Commission Export Detail Query

**Files:**
- Create: `qbit-core/src/main/java/com/qbit/common_all/analysis/domain/vo/salecommission/SaleCommissionExportDetailVO.java`
- Modify: `qbit-core/src/main/java/com/qbit/common_all/analysis/mapper/dws/SaleCommissionMapper.java`
- Modify: `qbit-core/src/main/resources/mapper/dws/DwsSaleCommissionMapper.xml`
- Modify: `qbit-core/src/main/resources/mapper/dws/DwsLocalSaleCommissionMapper.xml`
- Test: `qbit-core/src/test/java/com/qbit/common_all/analysis/salecommission/SaleCommissionExportSqlTest.java`

**Interfaces:**
- Produces `selectExportDetailsFromSnapshot(SaleCommissionQueryDTO)` and `selectExportDetailsFromEstimate(SaleCommissionQueryDTO)`, both returning `List<SaleCommissionExportDetailVO>`.
- The result carries department ID, product, provider, root account ID, sale ID, effective revenue, cost, GP, active days, commission rate, commission amount, customer name, sale nickname, and product activation time.

- [ ] Add SQL tests asserting both production and local mapper XML contain the two export queries; both filter sale/AM and settlement month, and local SQL avoids `dws.` schema prefixes.
- [ ] Add SQL test asserting the export query joins `account` by `root_account_id`, `"user"` by `sale_id`, and `dim_account_analysis` by `account_id`; activation date maps by product to `card_active_time`, `global_active_time`, `crypto_active_time`, or `api_active_time`.
- [ ] Add SQL test asserting detail selection uses non-deleted `current_payout` rows and API rows require `product = 'open_api'` with null/blank `provider`.
- [ ] Add `SaleCommissionExportDetailVO` with Chinese field Javadocs and fields needed by both export layouts.
- [ ] Add the two mapper methods to `SaleCommissionMapper` and corresponding SQL to both XMLs. Snapshot uses `commission_amount`; estimate uses `estimated_commission`. Join current names from `account.verifiedName` (fallback `verifiedNameEn`) and `"user".nickname`; format activation time as `yyyy-MM-dd`.
- [ ] Review mapper XML and run `git diff --check` only; defer tests until all source and test files are complete, per repository rules.

### Task 2: Department Workbook Conversion

**Files:**
- Create: `qbit-core/src/main/java/com/qbit/common_all/analysis/domain/bo/salecommission/OverseasSaleCommissionExportBO.java`
- Create: `qbit-core/src/main/java/com/qbit/common_all/analysis/domain/bo/salecommission/DepartmentSaleCommissionExportBO.java`
- Create: `qbit-core/src/main/java/com/qbit/common_all/analysis/domain/convert/salecommission/SaleCommissionExportConverter.java`
- Test: `qbit-core/src/test/java/com/qbit/common_all/analysis/salecommission/SaleCommissionExportConverterTest.java`

**Interfaces:**
- Consumes `List<SaleCommissionExportDetailVO>` and a department ID.
- Produces `Collection<ExcelExportBO<?>>` for `ExportService.export(name, collection)`.

- [ ] Add converter tests for overseas department ID `1851130772357509121`: exactly one sheet, with only `客户名称`, `销售`, `毛利`, `费率`, `提成` in that order.
- [ ] Add converter tests for other departments: sheets ordered `量子卡`, `全球账户`, `加密资产`, `API`; every sheet has only `客户名称`, `销售`, `渠道`, `有效收入`, `成本`, `毛利`, `激活时间`, `激活天数`, `费率`, `提成` in that order, including when a product has no rows.
- [ ] Add converter test that API output excludes rows with `future_payout`, includes only `open_api` rows with null/blank provider and `current_payout`, and never mixes API rows into another product sheet.
- [ ] Implement two Excel BOs with `@ExcelProperty` exact headers. Implement a focused converter that maps the VO fields and product codes; use `gp`, `commission_rate`, and commission amount for the overseas five-column row.
- [ ] Review header annotations and run `git diff --check` only; defer tests until all source and test files are complete, per repository rules.

### Task 3: Asynchronous Service, Handler, and Endpoint

**Files:**
- Modify: `qbit-core/src/main/java/com/qbit/admin/analysis/controller/reportform/v2/SaleCommissionController.java`
- Modify: `qbit-core/src/main/java/com/qbit/common_all/analysis/service/salecommission/SaleCommissionService.java`
- Modify: `qbit-core/src/main/java/com/qbit/common_all/analysis/service/impl/salecommission/SaleCommissionServiceImpl.java`
- Modify: `qbit-core/src/main/java/com/qbit/common_all/analysis/service/impl/salecommission/SaleCommissionRealServiceImpl.java`
- Modify: `qbit-core/src/main/java/com/qbit/common_all/assets/enums/ExportEnum.java`
- Create: `qbit-core/src/main/java/com/qbit/common_all/analysis/service/impl/salecommission/SaleCommissionExportExcelHandler.java`
- Test: `qbit-core/src/test/java/com/qbit/common_all/analysis/salecommission/SaleCommissionExportServiceTest.java`

**Interfaces:**
- Controller endpoint `POST /api/admin/sale/commission/export` accepts `HttpServletRequest`, `HttpServletResponse`, and validated `SaleCommissionQueryDTO`, returns `void`, and calls the service.
- Service adds the async export entry point and `List<SaleCommissionExportDetailVO> queryExportDetails(SaleCommissionQueryDTO)` for the registered handler.

- [ ] Add service tests proving export query selects snapshot details when `countSnapshot(queryDTO) > 0` and estimate-view details otherwise.
- [ ] Add service test proving failed `validateDataScope` prevents dispatch and data query.
- [ ] Add handler test proving export builds `ExcelExportBO` sheets, calls the multi-sheet `ExportService`, and notifies the initiating user; ensure `UserContext` is restored in the async task and removed afterward.
- [ ] Add `asyncExport` to `SaleCommissionService`; implement delegation in the facade and validate access/month before dispatch in the real service.
- [ ] Add the `@PostMapping("/export")` controller method with `@Operation`, then register a new export enum value and handler with `ReportFactory`.
- [ ] Implement the handler following `SnapshotBalanceExcelHandler`: capture the initiating `User`, run async, restore/clear `UserContext`, use `ExportService.export(name, Collection<ExcelExportBO<?>>)`, call `notifyExport`, and log failures with sale ID and settlement month.
- [ ] Review endpoint and handler; run `git diff --check` only; defer tests until all source and test files are complete, per repository rules.

### Task 4: Unified Verification

**Files:**
- No production changes unless verification exposes a defect.

- [ ] Run focused tests: `mvn -pl qbit-core -am test -DskipTests=false -Dtest=SaleCommissionExportSqlTest,SaleCommissionExportConverterTest,SaleCommissionExportServiceTest`.
- [ ] Run module verification: `mvn -pl qbit-core -am verify -DskipTests=false`.
- [ ] Run `git diff --check`, review `git diff --stat`, and scan for stale references to export method/type names.
- [ ] Report any environment-blocked verification by command and failure reason; do not skip tests to claim completion.

## Codebase-specific decisions and test names

- The local mapper must query the existing estimate view unqualified (`mv_sales_commission_recent_estimate`) to satisfy the repository's local SQL convention. Update `SaleCommissionDataSourceRoutingTest.localMapperSqlShouldNotRequireDwsSchema` so it continues to reject `dws.` qualifiers but permits the unqualified estimate view; add an assertion that both local export queries use it. Production SQL uses `dws.mv_sales_commission_recent_estimate`.
- If the result has rows, use its `department_id` for the workbook layout. If it is empty, resolve the target's current department with `SystemUserDepartmentMapper.selectDepartmentByUserId(saleId)` so the proper headers are still produced; when no department is available, use the non-overseas four-sheet layout.
- Implement these focused test methods: `localExportQueriesShouldUseUnqualifiedEstimateView`, `exportSqlShouldMapNamesAndActivationByProduct`, `exportSqlShouldExcludeApiReceivablesAndChannelledRows`, `overseasDepartmentUsesExactlyFiveHeadersInOneSheet`, `otherDepartmentsUseFourSheetsWithExactlyTenHeaders`, `emptyProductDataKeepsSheetHeaders`, `apiSheetIncludesOnlyUnchannelledCurrentPayoutRows`, `exportUsesSnapshotWhenAvailable`, `exportFallsBackToEstimateWhenSnapshotIsMissing`, `unauthorizedExportDoesNotDispatch`, and `asyncHandlerRestoresAndClearsUserContext`.

## Latest implementation direction

- Export is scoped to one requested `saleId` and settlement month; the existing shared mapper condition limits rows to `sale_id = saleId OR am_id = saleId`.
- The user asked not to compile. Do not run Maven compile, test, or verify commands for this change; complete source review and `git diff --check` only. Test cases are still added to the repository for later execution.
