package com.qbit.job.settle;

import com.alibaba.excel.EasyExcelFactory;
import com.alibaba.excel.ExcelWriter;
import com.alibaba.excel.enums.WriteDirectionEnum;
import com.alibaba.excel.write.metadata.fill.FillConfig;
import com.alibaba.excel.write.metadata.fill.FillWrapper;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.qbit.admin.api.client.enums.ApiAccessTypeEnum;
import com.qbit.common.enums.CryptoConversionCurrencyEnum;
import com.qbit.common.utils.CompletableFutureUtils;
import com.qbit.common.utils.DateUtil;
import com.qbit.common_all.rate.service.RateService;
import com.qbit.core.entity.account.Account;
import com.qbit.core.entity.account.AccountExtend;
import com.qbit.core.mapper.account.AccountExtendMapper;
import com.qbit.core.mapper.account.AccountMapper;
import com.qbit.core.mapper.account.AccountRelationMapper;
import com.qbit.core.service.ExportService;
import com.qbit.core.service.RedisService;
import com.qbit.job.settle.dto.DailySettleParamDTO;
import com.qbit.openapi.domain.entity.AccountRelation;
import com.qbit.openapi.v3.statement.domain.vo.BalanceSummaryUSDVO;
import com.qbit.openapi.v3.statement.domain.vo.BalanceSummaryVO;
import com.qbit.openapi.v3.statement.domain.vo.DailyTransactionVO;
import com.qbit.openapi.v3.statement.mapper.DailyStatementFileMapper;
import com.qbit.openapi.v3.statement.mapper.DailyStatementTransactionMapper;
import com.qbit.openapi.v3.statement.service.StatementHandler;
import com.qbit.openapi.v3.statement.service.StatementHandlerRegistry;
import com.qbit.openapi.v3.statement.util.StatementFormulaWriter;
import com.xxl.job.core.context.XxlJobHelper;
import com.xxl.job.core.handler.annotation.XxlJob;
import jakarta.annotation.Resource;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.collections4.CollectionUtils;
import org.apache.commons.lang3.StringUtils;
import org.redisson.api.RLock;
import org.redisson.api.RedissonClient;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import org.springframework.util.StopWatch;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/**
 * @author martinjiang
 * @description 日账单定时任务，每日凌晨生成 D-1 日 XLSX（含公式/样式）上传 OSS
 * @date 2026/5/15
 */
@Slf4j
@Component
public class DailySettleJob {

    @Resource
    private StatementHandlerRegistry handlerRegistry;

    @Resource
    private RedissonClient redissonClient;

    @Resource
    private RedisService redisService;

    @Resource
    private AccountMapper accountMapper;

    @Resource
    private AccountExtendMapper accountExtendMapper;

    @Resource
    private DailyStatementFileMapper dailyStatementFileMapper;

    @Resource
    private DailyStatementTransactionMapper dailyStatementTransactionMapper;

    @Resource
    private ExportService exportService;

    @Resource
    private AccountRelationMapper accountRelationMapper;

    @Resource
    private RateService rateService;

    /**
     * 已处理账户 Set 的存活时间（7天）
     */
    private static final long PROCESSED_SET_ALIVE_DAYS = 7;

    /**
     * 每批扫描的账户数量
     */
    private static final int BATCH_SIZE = 500;

    private static final String STATUS_ACTIVE = "Active";
    private static final long LOCK_WAIT_SECONDS = 30;

    @XxlJob("daily_settle")
    public void dailySettleHandler() {
        String param = XxlJobHelper.getJobParam();
        DailySettleParamDTO settleParam = DailySettleParamDTO.parse(param);
        String accountId = settleParam.getAccountId();
        String settleDate = settleParam.getDate() != null ? settleParam.getDate() : getYesterday();
        String lockKey = "qbit:assets:daily-settle:" + settleDate;
        RLock lock = redissonClient.getLock(lockKey);
        try {
            if (!lock.tryLock(LOCK_WAIT_SECONDS, TimeUnit.SECONDS)) {
                log.warn("DailySettleJob 已在运行，日期: {}", settleDate);
                return;
            }
            log.info("DailySettleJob 开始执行，日期: {}, accountId: {}", settleDate, accountId);
            processDailySettle(settleDate, accountId);
            log.info("DailySettleJob 执行完成，日期: {}", settleDate);
        } catch (Exception e) {
            log.error("DailySettleJob 执行失败，日期: {}", settleDate, e);
        } finally {
            if (lock.isHeldByCurrentThread()) {
                lock.unlock();
            }
        }
    }

    /**
     * 处理日账单生成
     * 当 accountId 非空时仅处理该账户，否则全量扫描所有活跃账户
     */
    public void processDailySettle(String settleDate, String accountId) {
        if (StringUtils.isNotBlank(accountId)) {
            processSingleAccount(accountId, settleDate);
            return;
        }
        Date startTime = getStartOfDay(settleDate);
        Date endTime = getNextDayStart(settleDate);
        String processedSetKey = "qbit:assets:daily-settle:processed:" + settleDate;
        String lastId = null;
        int totalScanned = 0;
        int totalGenerated = 0;
        int totalSkipped = 0;
        int totalNoHandler = 0;
        int totalFailed = 0;
        while (true) {
            List<String> accountIds = dailyStatementTransactionMapper.selectAutoStatementAccountIds(startTime, endTime, lastId, BATCH_SIZE);
            if (CollectionUtils.isEmpty(accountIds)) {
                break;
            }
            for (String accId : accountIds) {
                if (Boolean.TRUE.equals(redisService.sIsMember(processedSetKey, accId))) {
                    totalSkipped++;
                    continue;
                }
                totalScanned++;
                try {
                    Account account = accountMapper.selectById(accId);
                    if (account == null) {
                        log.warn("账户不存在: accountId={}", accId);
                        totalFailed++;
                        continue;
                    }
                    List<StatementHandler> handlers = resolveHandlersForAccount(account);
                    boolean isDistributor = isDistributorAccount(account);
                    if (handlers.isEmpty() && !isDistributor) {
                        redisService.sAdd(processedSetKey, accId);
                        totalNoHandler++;
                        continue;
                    }
                    generateDailyStatement(handlers, account, settleDate);
                    redisService.sAdd(processedSetKey, accId);
                    totalGenerated++;
                } catch (Exception e) {
                    totalFailed++;
                    log.error("处理日账单失败: accountId={}, date={}", accId, settleDate, e);
                }
            }
            lastId = accountIds.get(accountIds.size() - 1);
        }
        redisService.expire(processedSetKey, PROCESSED_SET_ALIVE_DAYS, TimeUnit.DAYS);
        log.info("DailySettleJob 处理完成: date={}, scanned={}, generated={}, noHandler={}, skipped={}, failed={}",
                settleDate, totalScanned, totalGenerated, totalNoHandler, totalSkipped, totalFailed);
    }

    /**
     * 根据账户信息匹配所有适用的 StatementHandler
     * 一个账户可能同时拥有多种钱包类型（量子钱包、储值卡、预算组等），
     * 所有匹配的 Handler 都需要参与余额汇总和交易流水
     */
    private List<StatementHandler> resolveHandlersForAccount(Account account) {
        AccountExtend extend = accountExtendMapper.getAccountExtendByAccountId(account.getId());
        if (extend == null) {
            return List.of();
        }
        List<StatementHandler> handlers = new ArrayList<>();
        // 量子账户功能可用 → 量子账户、储值卡、预算卡
        if (STATUS_ACTIVE.equals(extend.getQbitAccountStatus())) {
            handlers.add(handlerRegistry.getHandler("InfinityAccount"));
            handlers.add(handlerRegistry.getHandler("PrepaidCard"));
            handlers.add(handlerRegistry.getHandler("BudgetCard"));
        }
        // 全球账户功能可用 → 全球账户
        if (STATUS_ACTIVE.equals(extend.getGlobalAccountStatus())) {
            handlers.add(handlerRegistry.getHandler("BusinessAccount"));
        }
        // 加密理财功能可用 → 加密资产
        if (STATUS_ACTIVE.equals(extend.getCryptoFinanceStatus())) {
            handlers.add(handlerRegistry.getHandler("CryptoAsset"));
        }
        return handlers;
    }

    /**
     * 生成日账单 ZIP（内含 XLSX 文件）并上传 OSS
     * <p>
     * Distributor 账户：为每个子账户生成独立 XLSX，打包到 ZIP
     * 普通账户：单 XLSX 打包到 ZIP
     * </p>
     */
    private void generateDailyStatement(List<StatementHandler> handlers, Account account, String date) {
        StopWatch watch = new StopWatch("日账单ZIP全过程 accountId=" + account.getId() + ", date=" + date);
        String accountId = account.getId();
        boolean isDistributor = isDistributorAccount(account);
        // 收集待打包的 XLSX 文件
        List<byte[]> xlsxList = new ArrayList<>();
        List<String> filenames = new ArrayList<>();
        try {
            if (isDistributor) {
                watch.start("查询Distributor子账户");
                LambdaQueryWrapper<AccountRelation> lambdaQueryWrapper = new LambdaQueryWrapper<>();
                lambdaQueryWrapper.eq(AccountRelation::getRootId, accountId);
                lambdaQueryWrapper.eq(AccountRelation::getParentAccountId, accountId);
                lambdaQueryWrapper.ne(AccountRelation::getAccountId, accountId);
                List<AccountRelation> subRelations = accountRelationMapper.selectList(lambdaQueryWrapper);
                watch.stop();
                watch.start("并行生成子账户XLSX");
                List<CompletableFuture<SubAccountResult>> subFutures = subRelations.stream()
                        .map(rel -> CompletableFutureUtils.reportSupplyAsync(
                                () -> processSubAccount(rel, date)))
                        .toList();
                try {
                    CompletableFuture.allOf(subFutures.toArray(new CompletableFuture[0])).join();
                } catch (Exception e) {
                    throw new IllegalStateException("Distributor 子账户并行处理失败: accountId=" + accountId, e);
                }
                for (CompletableFuture<SubAccountResult> f : subFutures) {
                    try {
                        SubAccountResult r = f.getNow(null);
                        if (r != null) {
                            xlsxList.add(r.xlsx);
                            filenames.add(r.filename);
                        }
                    } catch (Exception e) {
                        throw new IllegalStateException("Distributor 子账户结果获取失败: accountId=" + accountId, e);
                    }
                }
                watch.stop();
            } else {
                watch.start("生成单账户XLSX");
                byte[] xlsx = generateXlsxBytes(handlers, account, date);
                if (xlsx != null) {
                    xlsxList.add(xlsx);
                    filenames.add("daily-statement-" + accountId + "-" + date + ".xlsx");
                }
                watch.stop();
            }
            if (xlsxList.isEmpty()) {
                log.warn("无账单文件可打包: accountId={}, date={}", accountId, date);
                return;
            }
            watch.start("打包ZIP");
            ByteArrayOutputStream zipBaos = new ByteArrayOutputStream();
            try (ZipOutputStream zos = new ZipOutputStream(zipBaos)) {
                for (int i = 0; i < xlsxList.size(); i++) {
                    zos.putNextEntry(new ZipEntry(filenames.get(i)));
                    zos.write(xlsxList.get(i));
                    zos.closeEntry();
                }
            } catch (IOException e) {
                log.error("ZIP 打包失败: accountId={}, date={}", accountId, date, e);
                return;
            }
            watch.stop();
            watch.start("上传ZIP并记录");
            uploadZipAndSaveRecord(zipBaos, accountId, date, xlsxList.size());
            watch.stop();
        } finally {
            if (watch.isRunning()) {
                watch.stop();
            }
            log.info("日账单ZIP耗时明细: accountId={}, date={}\n{}", accountId, date, watch.prettyPrint());
        }
    }

    /**
     * 上传 ZIP 到 OSS 并保存文件记录
     */
    private void uploadZipAndSaveRecord(ByteArrayOutputStream zipBaos, String accountId, String date, int fileCount) {
        String timestamp = DateUtil.dateFormat(new Date(), "yyyyMMddHHmmssSSS");
        String filepath = "export/3.0/daily-statement-" + accountId + "-" + date + "-" + timestamp + ".zip";
        byte[] zipBytes = zipBaos.toByteArray();
        ByteArrayOutputStream uploadBaos = new ByteArrayOutputStream(zipBytes.length);
        uploadBaos.write(zipBytes, 0, zipBytes.length);
        String fileUrl = exportService.upload(filepath, uploadBaos);

       /* DailyStatementFile existing = dailyStatementFileMapper.selectByAccountIdAndDate(accountId, java.sql.Date.valueOf(date));
        DailyStatementFile file = new DailyStatementFile();
        file.setAccountId(accountId);
        file.setStatementDate(java.sql.Date.valueOf(date));
        file.setStatementType("DAILY");
        file.setFileUrl(fileUrl);
        file.setStatus("completed");
        file.setOccurrenceTime(new Date());
        if (existing != null) {
            file.setId(existing.getId());
            dailyStatementFileMapper.updateById(file);
        } else {
            dailyStatementFileMapper.insert(file);
        }*/
        log.info("日账单 ZIP 已生成: accountId={}, date={}, fileUrl={}, fileCount={}", accountId, date, fileUrl, fileCount);
    }

    private record HandlerBalanceResult(String accountType, List<BalanceSummaryVO> summaries) {
    }

    private record HandlerTxResult(String accountType, List<DailyTransactionVO> transactions) {
    }

    private record StatementQueryResult(List<BalanceSummaryVO> balanceSummaries,
                                        List<DailyTransactionVO> transactions) {
    }

    /**
     * 为单个账户生成 XLSX 字节数组（两 Sheet：余额汇总 + 交易流水）
     *
     * @return XLSX 字节数组，无数据时返回 null
     */
    private byte[] generateXlsxBytes(List<StatementHandler> handlers, Account account, String date) {
        StopWatch watch = new StopWatch("日账单Excel全过程 accountId=" + account.getId() + ", date=" + date);
        String accountId = account.getId();
        int balanceSummaryCount = 0;
        int transactionCount = 0;
        try {
            watch.start("并行查询余额汇总和交易流水");
            StatementQueryResult queryResult = queryStatementData(handlers, accountId, date);
            watch.stop();
            List<BalanceSummaryVO> allBalanceSummaries = queryResult.balanceSummaries();
            if (allBalanceSummaries.isEmpty()) {
                log.warn("无余额汇总数据: accountId={}, date={}", accountId, date);
                return null;
            }
            balanceSummaryCount = allBalanceSummaries.size();
            List<DailyTransactionVO> allTransactions = queryResult.transactions();
            if (allTransactions.isEmpty()) {
                log.warn("无交易数据: accountId={}, date={}", accountId, date);
                return null;
            }
            transactionCount = allTransactions.size();
            watch.start("构建余额Sheet数据");
            Map<String, Object> singleDataMap = buildSingleDataMap(account, date);
            List<Map<String, Object>> balanceData = buildBalanceSheetData(allBalanceSummaries);
            watch.stop();

            watch.start("构建交易Sheet数据");
            List<Map<String, Object>> txData = buildTransactionSheetData(allTransactions);
            watch.stop();
            watch.start("填充Excel模板和公式");
            byte[] xlsx = fillExcelTemplate(singleDataMap, balanceData, txData, accountId, date);
            watch.stop();
            return xlsx;
        } finally {
            if (watch.isRunning()) {
                watch.stop();
            }
            log.info("日账单Excel耗时明细: accountId={}, date={}, handlerCount={}, balanceSummaryCount={}, transactionCount={}\n{}",
                    accountId, date, handlers.size(), balanceSummaryCount, transactionCount, watch.prettyPrint());
        }
    }

    /**
     * 并行查询余额汇总和交易流水，任一查询失败则整单失败。
     */
    private StatementQueryResult queryStatementData(List<StatementHandler> handlers, String accountId, String date) {
        long balanceStart = System.currentTimeMillis();
        CompletableFuture<List<BalanceSummaryVO>> balanceFuture = CompletableFutureUtils.reportSupplyAsync(
                () -> {
                    try {
                        return queryBalanceSummaries(handlers, accountId, date);
                    } finally {
                        log.info("余额汇总总查询完成: accountId={}, date={}, elapsedMs={}",
                                accountId, date, System.currentTimeMillis() - balanceStart);
                    }
                });
        long transactionStart = System.currentTimeMillis();
        CompletableFuture<List<DailyTransactionVO>> transactionFuture = CompletableFutureUtils.reportSupplyAsync(
                () -> {
                    try {
                        return queryTransactions(handlers, accountId, date);
                    } finally {
                        log.info("交易流水总查询完成: accountId={}, date={}, elapsedMs={}",
                                accountId, date, System.currentTimeMillis() - transactionStart);
                    }
                });
        waitAll(List.of(balanceFuture, transactionFuture));
        return new StatementQueryResult(balanceFuture.join(), transactionFuture.join());
    }

    /**
     * 并行查询各 Handler 余额汇总，任一 Handler 失败则整单失败。
     */
    private List<BalanceSummaryVO> queryBalanceSummaries(List<StatementHandler> handlers, String accountId, String date) {
        List<CompletableFuture<HandlerBalanceResult>> futures = handlers.stream()
                .map(handler -> CompletableFutureUtils.reportSupplyAsync(() -> queryHandlerBalance(handler, accountId, date)))
                .toList();
        waitAll(futures);
        List<BalanceSummaryVO> summaries = new ArrayList<>();
        for (CompletableFuture<HandlerBalanceResult> future : futures) {
            HandlerBalanceResult result = future.join();
            if (result.summaries != null) {
                summaries.addAll(result.summaries);
            }
        }
        return summaries;
    }

    /**
     * 查询单个 Handler 余额汇总并记录耗时。
     */
    private HandlerBalanceResult queryHandlerBalance(StatementHandler handler, String accountId, String date) {
        long handlerStart = System.currentTimeMillis();
        try {
            List<BalanceSummaryVO> summaries = handler.getBalanceSummary(accountId, date, null);
            log.info("Handler {} 余额汇总查询完成: accountId={}, date={}, summaryCount={}, elapsedMs={}",
                    handler.getAccountType(), accountId, date, summaries == null ? 0 : summaries.size(),
                    System.currentTimeMillis() - handlerStart);
            return new HandlerBalanceResult(handler.getAccountType(), summaries);
        } catch (Exception e) {
            log.error("Handler {} 余额汇总查询失败: accountId={}, date={}, elapsedMs={}",
                    handler.getAccountType(), accountId, date, System.currentTimeMillis() - handlerStart, e);
            throw new IllegalStateException("Handler 余额汇总查询失败: handler=" + handler.getAccountType()
                    + ", accountId=" + accountId + ", date=" + date, e);
        }
    }

    /**
     * 并行查询各 Handler 交易流水，任一 Handler 失败则整单失败。
     */
    private List<DailyTransactionVO> queryTransactions(List<StatementHandler> handlers, String accountId, String date) {
        List<CompletableFuture<HandlerTxResult>> futures = handlers.stream()
                .map(handler -> CompletableFutureUtils.reportSupplyAsync(() -> queryHandlerTransactions(handler, accountId, date)))
                .toList();
        waitAll(futures);
        List<DailyTransactionVO> transactions = new ArrayList<>();
        for (CompletableFuture<HandlerTxResult> future : futures) {
            HandlerTxResult result = future.join();
            if (result.transactions != null) {
                transactions.addAll(result.transactions);
            }
        }
        return transactions;
    }

    /**
     * 查询单个 Handler 交易流水并记录耗时。
     */
    private HandlerTxResult queryHandlerTransactions(StatementHandler handler, String accountId, String date) {
        long handlerStart = System.currentTimeMillis();
        try {
            List<DailyTransactionVO> transactions = handler.pageTransactions(accountId, date);
            log.info("Handler {} 交易流水查询完成: accountId={}, date={}, transactionCount={}, elapsedMs={}",
                    handler.getAccountType(), accountId, date, transactions == null ? 0 : transactions.size(),
                    System.currentTimeMillis() - handlerStart);
            return new HandlerTxResult(handler.getAccountType(), transactions);
        } catch (Exception e) {
            log.error("Handler {} 交易流水查询失败: accountId={}, date={}, elapsedMs={}",
                    handler.getAccountType(), accountId, date, System.currentTimeMillis() - handlerStart, e);
            throw new IllegalStateException("Handler 交易流水查询失败: handler=" + handler.getAccountType()
                    + ", accountId=" + accountId + ", date=" + date, e);
        }
    }

    /**
     * 等待所有并行任务完成，不设置超时也不主动 cancel，避免 JDBC 查询被中断。
     */
    private void waitAll(List<? extends CompletableFuture<?>> futures) {
        CompletableFuture.allOf(futures.toArray(new CompletableFuture<?>[0])).join();
    }

    /**
     * 构建模板公共数据。
     */
    private Map<String, Object> buildSingleDataMap(Account account, String date) {
        Map<String, Object> data = new HashMap<>(4);
        data.put("statementDate", date);
        data.put("accountName", account.getVerifiedName());
        data.put("accountId", account.getId());
        return data;
    }

    /**
     * 构建余额 Sheet 数据。
     */
    private List<Map<String, Object>> buildBalanceSheetData(List<BalanceSummaryVO> summaries) {
        List<Map<String, Object>> rows = new ArrayList<>();
        int no = 1;
        for (BalanceSummaryVO summary : summaries) {
            rows.add(buildBalanceRow(no++, summary));
        }
        rows.add(buildUsdBalanceRow(summaries));
        return rows;
    }

    /**
     * 构建单行余额数据。
     */
    private Map<String, Object> buildBalanceRow(int no, BalanceSummaryVO summary) {
        Map<String, Object> row = new HashMap<>(10);
        row.put("no", no);
        row.put("accountType", summary.getAccountType() != null ? summary.getAccountType() : "");
        row.put("debit", summary.getTotalDebitAmount());
        row.put("credit", summary.getTotalCreditAmount());
        row.put("currency", summary.getCurrency() != null ? summary.getCurrency() : "");
        row.put("frozenAmount", summary.getClosingBalance());
        row.put("unfrozenAmount", summary.getTotalFrozenAmount());
        row.put("beginningBalance", summary.getOpeningBalance());
        row.put("endingBalance", summary.getClosingBalance());
        return row;
    }

    /**
     * 构建 USD 汇总行。
     */
    private Map<String, Object> buildUsdBalanceRow(List<BalanceSummaryVO> summaries) {
        List<String> nonUsdCurrencies = summaries.stream()
                .map(BalanceSummaryVO::getCurrency)
                .filter(ccy -> ccy != null && !CryptoConversionCurrencyEnum.USD.getValue().equals(ccy))
                .toList();
        Map<String, BigDecimal> rateMap = nonUsdCurrencies.isEmpty() ? Map.of() : rateService.getRateMap(nonUsdCurrencies);
        BalanceSummaryUSDVO usdSummary = BalanceSummaryUSDVO.aggregate(summaries, rateMap);
        Map<String, Object> row = new HashMap<>(10);
        row.put("accountType", "USD Total");
        row.put("debit", usdSummary.getTotalDebitUsd());
        row.put("credit", usdSummary.getTotalCreditUsd());
        row.put("currency", "USD");
        row.put("frozenAmount", usdSummary.getClosingBalanceUsd());
        row.put("unfrozenAmount", usdSummary.getTotalFrozenUsd());
        row.put("beginningBalance", usdSummary.getOpeningBalanceUsd());
        row.put("endingBalance", usdSummary.getClosingBalanceUsd());
        return row;
    }

    /**
     * 构建交易流水 Sheet 数据。
     */
    private List<Map<String, Object>> buildTransactionSheetData(List<DailyTransactionVO> transactions) {
        List<Map<String, Object>> rows = new ArrayList<>(transactions.size());
        for (DailyTransactionVO transaction : transactions) {
            rows.add(buildTransactionRow(transaction));
        }
        return rows;
    }

    /**
     * 构建单行交易流水数据。
     */
    private Map<String, Object> buildTransactionRow(DailyTransactionVO transaction) {
        Map<String, Object> row = new HashMap<>(16);
        row.put("transactionId", transaction.getTransactionId());
        row.put("accountId", transaction.getAccountId());
        row.put("accountName", transaction.getAccountName());
        row.put("transactionCreationTime", transaction.getTransactionCreationTime());
        row.put("transactionCompletionTime", transaction.getTransactionCompletionTime());
        row.put("accountType", transaction.getAccountType());
        row.put("transactionType", transaction.getTransactionType());
        row.put("counterpartyName", transaction.getCounterpartyName());
        row.put("counterpartyAccount", transaction.getCounterpartyAccount());
        row.put("currency", transaction.getCurrency());
        row.put("direction", transaction.getDirection());
        row.put("amount", transaction.getAmount());
        row.put("fee", transaction.getFee());
        row.put("transactionStatus", transaction.getTransactionStatus());
        row.put("description", transaction.getDescription());
        return row;
    }

    /**
     * 填充 XLSX 模板并追加余额公式
     */
    private byte[] fillExcelTemplate(Map<String, Object> singleDataMap, List<Map<String, Object>> balanceData,
                                     List<Map<String, Object>> txData, String accountId, String date) {
        StopWatch watch = new StopWatch("日账单Excel模板填充 accountId=" + accountId + ", date=" + date);
        try {
            watch.start("加载Excel模板");
            InputStream templateStream;
            try {
                templateStream = new ClassPathResource("/templates/dailySettleTemp.xlsx").getInputStream();
            } catch (IOException e) {
                log.error("加载日账单模板失败: accountId={}", accountId, e);
                return null;
            }
            watch.stop();

            watch.start("EasyExcel填充Sheet");
            ByteArrayOutputStream xlsxOut = new ByteArrayOutputStream();
            try (ExcelWriter excelWriter = EasyExcelFactory.write(xlsxOut).withTemplate(templateStream).build()) {
                excelWriter.fill(singleDataMap, EasyExcelFactory.writerSheet(0).build());
                excelWriter.fill(singleDataMap, EasyExcelFactory.writerSheet(1).build());
                FillConfig fillConfig = FillConfig.builder().direction(WriteDirectionEnum.VERTICAL).build();
                excelWriter.fill(new FillWrapper("balances", balanceData), fillConfig, EasyExcelFactory.writerSheet(0).build());
                excelWriter.fill(new FillWrapper("transactions", txData), fillConfig, EasyExcelFactory.writerSheet(1).build());
            } catch (Exception e) {
                log.error("XLSX 模板填充失败: accountId={}, date={}", accountId, date, e);
                return null;
            }
            watch.stop();

            watch.start("追加余额公式");
            try {
                byte[] xlsxBytes = StatementFormulaWriter.appendBalanceFormulas(xlsxOut.toByteArray(), balanceData.size());
                watch.stop();
                return xlsxBytes;
            } catch (Exception e) {
                log.error("追加余额公式失败，使用无公式版本: accountId={}", accountId, e);
                watch.stop();
                return xlsxOut.toByteArray();
            }
        } finally {
            if (watch.isRunning()) {
                watch.stop();
            }
            log.info("日账单Excel模板耗时明细: accountId={}, date={}, balanceRows={}, transactionRows={}\n{}",
                    accountId, date, balanceData.size(), txData.size(), watch.prettyPrint());
        }
    }

    /**
     * 判断账户是否为 Distributor（分发商），其账单需要按子账户生成多份 XLSX
     */
    private boolean isDistributorAccount(Account account) {
        AccountExtend extend = accountExtendMapper.getAccountExtendByAccountId(account.getId());
        return extend != null && ApiAccessTypeEnum.DISTRIBUTOR.equals(extend.getAccessType());
    }

    /**
     * 处理单账户日账单生成
     *
     * @param accountId 账户ID
     * @param date      账单日期 yyyy-MM-dd
     */
    private void processSingleAccount(String accountId, String date) {
        StopWatch watch = new StopWatch("单账户日账单全过程 accountId=" + accountId + ", date=" + date);
        try {
            watch.start("查询账户");
            Account account = accountMapper.selectById(accountId);
            watch.stop();
            if (account == null) {
                log.warn("账户不存在: accountId={}", accountId);
                return;
            }

            watch.start("解析账户Handler");
            boolean isDistributor = isDistributorAccount(account);
            List<StatementHandler> handlers = resolveHandlersForAccount(account);
            watch.stop();
            if (handlers.isEmpty() && !isDistributor) {
                log.warn("无匹配 Handler: accountId={}", accountId);
                return;
            }

            if (!isDistributor) {
                watch.start("检查账户是否有交易");
                boolean anyHasTx = dailyStatementTransactionMapper.existsByRootAccountIdAndTimeRange(
                        accountId, getStartOfDay(date), getNextDayStart(date));
                watch.stop();
                if (!anyHasTx) {
                    log.warn("无交易: accountId={}, date={}", accountId, date);
                    return;
                }
            }

            watch.start("生成并上传日账单");
            generateDailyStatement(handlers, account, date);
            watch.stop();
            log.info("单账户日账单处理完成: accountId={}, date={}", accountId, date);
        } catch (Exception e) {
            log.error("处理单账户日账单失败: accountId={}, date={}", accountId, date, e);
        } finally {
            if (watch.isRunning()) {
                watch.stop();
            }
            log.info("单账户日账单耗时明细: accountId={}, date={}\n{}", accountId, date, watch.prettyPrint());
        }
    }

    private record SubAccountResult(byte[] xlsx, String filename) {
    }

    /**
     * 处理单个 Distributor 子账户（封装并行粒度：各子账户可并发执行）
     */
    private SubAccountResult processSubAccount(AccountRelation rel, String date) {
        String subId = rel.getAccountId();
        Account subAccount = accountMapper.selectById(subId);
        if (subAccount == null) {
            return null;
        }
        List<StatementHandler> subHandlers = resolveHandlersForAccount(subAccount);
        if (subHandlers.isEmpty()) {
            return null;
        }
        byte[] xlsx = generateXlsxBytes(subHandlers, subAccount, date);
        if (xlsx == null) {
            return null;
        }
        return new SubAccountResult(xlsx, "daily-statement-" + subId + "-" + date + ".xlsx");
    }

    /**
     * 获取昨天的日期字符串 yyyy-MM-dd
     */
    private static String getYesterday() {
        Calendar cal = Calendar.getInstance();
        cal.add(Calendar.DAY_OF_YEAR, -1);
        return new java.text.SimpleDateFormat(DateUtil.YYYY_MM_DD).format(cal.getTime());
    }

    /**
     * 获取账单日期的开始时间。
     */
    private static Date getStartOfDay(String date) {
        return java.sql.Timestamp.valueOf(LocalDate.parse(date).atStartOfDay());
    }

    /**
     * 获取账单日期下一天的开始时间，作为半开时间区间结束值。
     */
    private static Date getNextDayStart(String date) {
        return java.sql.Timestamp.valueOf(LocalDate.parse(date).plusDays(1).atStartOfDay());
    }
}
