使用superpower skill 插件分析下面的需求
QbitCardOnlineProviderEnum 
新增了一个渠道PC("PC", "CorpayCard556766,CorpayCardRecharge556766," +
"CorpayCard530483,CorpayCardRecharge530483," +
            "CorpayCard537843,CorpayCardRecharge537843");
我想知道bi统计相关的我要改那些地方

使用superpower skill 插件分析 
我们之前曾经写过一次i2c 的新增
https://github.com/PalmDrive/qbit-assets/pull/5476


Skill(superpowers:systematic-debugging)
  ⎿  Successfully loaded skill

⏺ 好，我去拉取 PR #5476 的改动来对照分析。

  Called plugin:ecc:github (ctrl+o to expand)

⏺ Bash(gh pr view 5476 --repo PalmDrive/qbit-assets --json title,body,files,commits 2>/dev/null || echo "FALLBACK: using gh
      api directly")
  ⎿  FALLBACK: using gh api directly

⏺ Bash(gh api repos/PalmDrive/qbit-assets/pulls/5476 --jq '{title: .title, body: .body}' 2>&1 | head -50)
  ⎿  To get started with GitHub CLI, please run:  gh auth login
     Alternatively, populate the GH_TOKEN environment variable with a GitHub API authentication token.

⏺ GitHub CLI 未认证，直接从本地代码库分析 BZ(I2C) 的实现模式。

  Searched for 4 patterns, read 2 files (ctrl+o to expand)

⏺ Bash(git log --all --oneline --grep="I2c\|BZ\|i2c" --since="2026-01-01" | head -15)
  ⎿  e854eb2dc2 Merge branch 'feature/kk/i2c-deleteCard' into test
     c3eabbd5e8 I2c 卡私密信息解密
     03a825607f 【量子卡】Fx/cb fee 退回逻辑调整 (#6587)
     … +12 lines (ctrl+o to expand)

  Searched for 2 patterns, read 1 file (ctrl+o to expand)

⏺ 分析完成。以下是使用 superpowers:systematic-debugging 的数据流追溯结果。

  ---
  Phase 1: 对比分析 BZ vs PC 的模式差异
  
  BZ(I2C) 的改动范围（PR #5476）

  从代码库追踪，BZ 只在 2 个地方 出现：

  ┌────────────────────────────────────┬────────────────────────────────┐
  │                文件                │              改动              │
  ├────────────────────────────────────┼────────────────────────────────┤
  │ BzStatisticsProviderImpl.java      │ 新增 — BZ渠道余额统计          │
  ├────────────────────────────────────┼────────────────────────────────┤
  │ DwsDashBoardV2ServiceImpl.java:106 │ QUANTUM_PROVIDER 列表加上 "BZ" │
  └────────────────────────────────────┴────────────────────────────────┘

  没有 I2cCardCostServiceImpl、没有 getPlatform() 路由、没有成本采集。这是因为 BZ 
  是实体卡/银行渠道，不走虚拟卡的成本核算链路。

  PC(CorpayCard) 的差异

  PC 的 desc 包含 CorpayCard556766,CorpayCardRecharge556766 等，和以下渠道同模式：
  - NM: "NiumCard,NiumCardRecharge"
  - RP: "ReapCard414631,ReapCardRecharge414631"
  - TP: "ThepennyincCard,ThepennyincCardRecharge"

  这些都有完整的 CardProviderCostService 实现。所以 PC 需要的是完整接入，不能只像 BZ 那样轻量处理。

  ---
  Phase 2: 完整改动清单（Pattern Analysis）
  
  ✅ 自动生效（无需动）

  ┌──────────────────────────────────────┬──────────────────────────────────┐
  │                 方法                 │               原因               │
  ├──────────────────────────────────────┼──────────────────────────────────┤
  │ getOnlineProviders()                 │ 遍历 values()，PC 自动包含       │
  ├──────────────────────────────────────┼──────────────────────────────────┤
  │ getOnlineValues()                    │ 同上                             │
  ├──────────────────────────────────────┼──────────────────────────────────┤
  │ getAllValues()                       │ 同上                             │
  ├──────────────────────────────────────┼──────────────────────────────────┤
  │ SalesEarningDashBoardServiceImpl:235 │ 使用 getOnlineValues()，自动生效 │
  ├──────────────────────────────────────┼──────────────────────────────────┤
  │ ApiClientTransactionServiceImpl:337  │ 同上                             │
  └──────────────────────────────────────┴──────────────────────────────────┘

  🔴 P0 — 核心链路（必须改）

  ┌─────┬──────────────────────────────────────────────────────┬────────────────────────────────────────────────────────┐
  │  #  │                         文件                         │                          改动                          │
  ├─────┼──────────────────────────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ 1   │ 新建 cardcost/CorpayCardCostServiceImpl.java         │ 实现 CardProviderCostService，参考                     │
  │     │                                                      │ RainCardCostServiceImpl                                │
  ├─────┼──────────────────────────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ 2   │ CardProviderCostFactoryImpl.java:209-222             │ 加 CorpayCard 系列卡段路由                             │
  │     │ getPlatform()                                        │                                                        │
  ├─────┼──────────────────────────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ 3   │ DwsQbitCardTempServiceImpl.java:226-241              │ 加 CorpayCard 成本并行采集                             │
  ├─────┼──────────────────────────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ 4   │ SalesReportStaticServiceImpl.java:~327-364           │ 加 CorpayCard rebate/cost 采集                         │
  └─────┴──────────────────────────────────────────────────────┴────────────────────────────────────────────────────────┘

  🔶 P1 — Dashboard 级联（需要确认是否要展示）

  ┌─────┬────────────────────────────────────────────────────────────┬──────────────────────────────────────────────────┐
  │  #  │                            文件                            │                       改动                       │
  ├─────┼────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────┤
  │ 5   │ DwsDashBoardV2ServiceImpl.java:106 QUANTUM_PROVIDER        │ 加 "PC"（参考 BZ）                               │
  ├─────┼────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────┤
  │ 6   │ DwsDashBoardV2ServiceImpl.java:110-117 PROVIDER_TAG_MAP    │ 加 "PC" -> "CorpayCard" 映射（如果 PC            │
  │     │                                                            │ 有成本数据）                                     │
  ├─────┼────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────┤
  │ 7   │ DwsDashBoardV2ServiceImpl.java:881-901                     │ 加 CorpayCard rebate 采集                        │
  │     │ getRebateByProvider()                                      │                                                  │
  └─────┴────────────────────────────────────────────────────────────┴──────────────────────────────────────────────────┘

  🔶 P2 — 量子卡利润 Tab（需确认 PC 是否独立展示）

  ┌─────┬─────────────────────────────────────────────────────────────────────┬─────────────────────┐
  │  #  │                                文件                                 │        改动         │
  ├─────┼─────────────────────────────────────────────────────────────────────┼─────────────────────┤
  │ 8   │ QuantumCostStatisticsServiceImpl.java:52-53                         │ 加 PROVIDER_PC 常量 │
  ├─────┼─────────────────────────────────────────────────────────────────────┼─────────────────────┤
  │ 9   │ QuantumCostStatisticsServiceImpl.java:163-176 getTabProviders()     │ 加 PC 处理分支      │
  ├─────┼─────────────────────────────────────────────────────────────────────┼─────────────────────┤
  │ 10  │ QuantumCostStatisticsServiceImpl.java:336-346 filterSummaryByTab()  │ 同上                │
  ├─────┼─────────────────────────────────────────────────────────────────────┼─────────────────────┤
  │ 11  │ QuantumCostStatisticsServiceImpl.java:349-356 toPageV2Row()         │ 同上                │
  ├─────┼─────────────────────────────────────────────────────────────────────┼─────────────────────┤
  │ 12  │ QuantumCostStatisticsServiceImpl.java:1029-1039 normalizeProvider() │ 同上                │
  └─────┴─────────────────────────────────────────────────────────────────────┴─────────────────────┘

  只有确认了 PC 在量子卡利润页面需要独立 tab，才改 #8~#12。

  ---
  Phase 3: PC 是否需要独立 tab？
  
  先看 desc 模式来判断：CorpayCard556766,CorpayCardRecharge556766 — 和现有渠道一样，有交易卡段和充值卡段。大概率 PC 
  只需要归入 ALL，不需要像 BB/IQ 那样占独立 tab，除非产品有特殊要求。

  需要你确认两个问题：
  1. PC(CorpayCard) 在 Dashboard 上要不要展示成本/返现数据？ — 这决定是否改 P1 的 QUANTUM_PROVIDER/PROVIDER_TAG_MAP
  2. PC 在量子卡利润统计页面是否需要独立 tab 展示？ — 这决定是否改 P2 的 QuantumCostStatisticsServiceImpl



 public static final List<QbitCardProviderEnum> PC = List.of(
            CorpayCard556766,
            CorpayCardRecharge556766,
            CorpayCard530483,
            CorpayCardRecharge530483,
            CorpayCard537843,
            CorpayCardRecharge537843
);
前端
1.数据看板新增 pc相关
消费交易数据,(卡数据,卡交易详情)参考其他渠道
2.业务全局数据 量子卡新增pc
3.量子卡业绩报表新增有效收入新增 BZ PC
4.新用户全量信息,量子卡统计新增 PC


必须改 🔴

  ┌─────┬────────────────────────────────────────────────┬────────────────────────────────────────────────────────────┐
  │  #  │                      文件                      │                          改动内容                          │
  ├─────┼────────────────────────────────────────────────┼────────────────────────────────────────────────────────────┤
  │ 1   │ 新建 CorpayCardCostServiceImpl.java            │ 实现 CardProviderCostService，参考 RainCardCostServiceImpl │
  ├─────┼────────────────────────────────────────────────┼────────────────────────────────────────────────────────────┤
  │ 2   │ CardProviderCostFactoryImpl.java getPlatform() │ 加 CorpayCard 系列卡段的路由                               │
  ├─────┼────────────────────────────────────────────────┼────────────────────────────────────────────────────────────┤
  │ 3   │ DwsQbitCardTempServiceImpl.java                │ 加 CorpayCard 的成本并行采集                               │
  ├─────┼────────────────────────────────────────────────┼────────────────────────────────────────────────────────────┤
  │ 4   │ SalesReportStaticServiceImpl.java              │ 加 CorpayCard 的 rebate/cost 采集                          │
  └─────┴────────────────────────────────────────────────┴────────────────────────────────────────────────────────────┘

好的
getPlatform 把i2c 也放进去吧
因为PC 暂时没有计算逻辑 所有返回0

DwsDashBoardV2ServiceImpl QUANTUM_PROVIDER 这个能不能直接按 QbitCardOnlineProviderEnum
  
  需先确认再改 🟡

  ┌─────┬─────────────────────────────────────────┬──────────────────────────────────────────────────────────┐
  │  #  │                  文件                   │                     需要你确认的问题                     │
  ├─────┼─────────────────────────────────────────┼──────────────────────────────────────────────────────────┤
  │ 5   │ DwsDashBoardV2ServiceImpl.java          │ PC 是否要加到 QUANTUM_PROVIDER 列表和 PROVIDER_TAG_MAP？ │
  ├─────┼─────────────────────────────────────────┼──────────────────────────────────────────────────────────┤
  │ 6   │ QuantumCostStatisticsServiceImpl.java   │ PC 是否需要独立 tab？（大概率归入 ALL，不用改）          │
  ├─────┼─────────────────────────────────────────┼──────────────────────────────────────────────────────────┤
  │ 7   │ AccountBasedSalesReportServiceImpl.java │ PC 是否有独立 cashback 字段？                            │
  └─────┴─────────────────────────────────────────┴──────────────────────────────────────────────────────────┘

  要我先把 必须改的 4 个 做了吗？


  api/admin/system/tags/insert
  api/admin/system/tags/update
  api/admin/system/tags/delete
  api/admin/system/tags/status/update
  api/admin/system/tags/list
  api/admin/system/tags/tree
  api/admin/system/tags/tree/v2
