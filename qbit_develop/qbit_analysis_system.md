# 分析报表体系

## 概述

分析报表是 Qbit 最大的业务模块（~760 文件），提供数据仓库分层（ODS/DWD/DWS）、多维统计分析、报表导出、标签管理、客户分析等能力。覆盖量子卡、全球账户、加密资产、融资、风控等全业务域的统计需求。

## 整体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                       管理端 (Admin)                               │
│  AdminAppointMerchantStatisticsController → 指定商户统计          │
│  AdminDwdAccountController → DWD 账户层                          │
│  AdminOdsAccountController → ODS 账户层                          │
│  AdminQuantumAppointMerchantController → 量子卡指定商户          │
│  AdminTopMerchantController → Top 商户                            │
├──────────────────────────────────────────────────────────────────┤
│                       商户端 (Merchant)                            │
│  DwsDashBoardController → Dashboard 看板                          │
│  DwsGlobalAccountController → 全球账户看板                        │
│  ClientCustomerStatisticsController → 客户统计                    │
│  DataxNoticeController → 数据通知                                 │
├──────────────────────────────────────────────────────────────────┤
│                      统计服务层                                     │
│  QbitCardStatisticsService → 量子卡统计                           │
│  QbitCardStatisticV2Service → 量子卡统计 V2                       │
│  QbitCardGroupStatisticsService → 卡组统计                        │
│  GlobalStatisticsService → 全球账户统计                           │
│  GlobalStatisticsV2Service → 全球账户统计 V2                      │
│  CryptoAssetStatisticsService → 加密资产统计                      │
│  CryptoAssetStatisticsV2Service → 加密资产统计 V2                 │
│  ParticleFinanceStatisticsService → 融资统计                      │
│  QuantumCostStatisticsService → 量子成本统计                      │
│  CnyWalletStatisticsService → 人民币钱包统计                      │
│  QbitCardWalletStatisticsService → 卡钱包统计                     │
│  QbitCardStatusSummaryService → 卡状态汇总                        │
│  SalesReportStaticService → 销售报表                              │
│  SalesReportStaticV2Service → 销售报表 V2                         │
│  ChannelStatisticsService → 渠道统计                              │
│  BiMonthTagService → 双月标签                                     │
│  BaseStatisticsService → 统计基类                                 │
├──────────────────────────────────────────────────────────────────┤
│                     数据仓库分层                                    │
│  ODS → DWD → DWS → 应用层                                         │
│  ods/ → 原始数据层                                                │
│  dwd/ → 明细数据层                                                │
│  dws/ → 汇总数据层                                                │
├──────────────────────────────────────────────────────────────────┤
│                     报表导出层                                      │
│  reportform/ → 报表格式管理                                       │
│  cardcost/ → 卡成本报表                                           │
│  globalcost/ → 全球账户成本报表                                   │
│  compliance/ → 合规报表                                           │
├──────────────────────────────────────────────────────────────────┤
│                     标签 & 客户                                    │
│  label/ → 标签服务                                                │
│  crm/ → 客户分析                                                  │
│  sales/ → 销售分析                                                │
│  retention/ → 留存分析                                            │
└──────────────────────────────────────────────────────────────────┘
```

## 核心服务

### 量子卡统计

| 服务 | 说明 |
|------|------|
| `QbitCardStatisticsService` | 量子卡基础统计（消费/充值/退款） |
| `QbitCardStatisticV2Service` | 量子卡统计 V2（增强维度） |
| `QbitCardGroupStatisticsService` | 卡组维度统计 |
| `QbitCardStatusSummaryService` | 卡状态汇总统计 |
| `QbitCardWalletStatisticsService` | 卡钱包余额统计 |
| `QuantumCostStatisticsService` | 量子卡成本统计 |

### 全球账户统计

| 服务 | 说明 |
|------|------|
| `GlobalStatisticsService` | 全球账户基础统计 |
| `GlobalStatisticsV2Service` | 全球账户统计 V2 |
| `CnyWalletStatisticsService` | 人民币钱包统计 |

### 加密资产统计

| 服务 | 说明 |
|------|------|
| `CryptoAssetStatisticsService` | 加密资产基础统计 |
| `CryptoAssetStatisticsV2Service` | 加密资产统计 V2 |

### 销售与渠道

| 服务 | 说明 |
|------|------|
| `SalesReportStaticService` | 销售报表统计 |
| `SalesReportStaticV2Service` | 销售报表统计 V2 |
| `ChannelStatisticsService` | 渠道维度统计 |
| `VendorOrderStatisticsService` | 供应商订单统计 |

## 数据分层

```
ODS (操作数据层)
  ├── ods/ → 原始数据接入
  ├── 实时同步 (ClickhouseToPgService)
  └── 数据同步 (DataDynamicSynchronization)

DWD (明细数据层)
  ├── dwd/ → 明细数据清洗
  └── 账户维度 (AdminDwdAccountController)

DWS (汇总数据层)
  ├── dws/ → 多维汇总
  ├── DashBoard 看板 (DwsDashBoardController)
  └── 全球账户看板 (DwsGlobalAccountController)

应用层
  ├── 管理端报表
  ├── 商户端 Dashboard
  └── 导出报表
```

## 管理端 Controller

| Controller | 说明 |
|------------|------|
| `AdminAppointMerchantStatisticsController` | 指定商户统计查询 |
| `AdminDwdAccountController` | DWD 账户层数据 |
| `AdminOdsAccountController` | ODS 账户层数据 |
| `AdminQuantumAppointMerchantController` | 量子卡指定商户明细 |
| `AdminTopMerchantController` | Top 商户排行 |
| `label/` | 标签管理 Controller |
| `reportform/` | 报表格式 Controller |
| `statistics/` | 统计查询 Controller |

## 商户端 Controller

| Controller | 说明 |
|------------|------|
| `DwsDashBoardController` | 商户 Dashboard |
| `DwsGlobalAccountController` | 全球账户看板 |
| `ClientCustomerStatisticsController` | 客户统计 |
| `DataxNoticeController` | 数据变更通知 |
| `board/` | 看板模块 |
| `credit/` | 信用分析 |
| `crm/` | 客户分析 |
| `label/` | 标签管理 |
| `sales/` | 销售分析 |
| `statistics/` | 统计查询 |

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `common_all/analysis/service/` | 统计服务（25+） |
| `common_all/analysis/service/ods/` | ODS 层服务 |
| `common_all/analysis/service/dwd/` | DWD 层服务 |
| `common_all/analysis/service/dws/` | DWS 层服务 |
| `common_all/analysis/service/account/` | 账户统计 |
| `common_all/analysis/service/cardcost/` | 卡成本统计 |
| `common_all/analysis/service/globalcost/` | 全球账户成本 |
| `common_all/analysis/service/compliance/` | 合规报表 |
| `common_all/analysis/service/label/` | 标签服务 |
| `common_all/analysis/service/retention/` | 留存分析 |
| `common_all/analysis/service/sales/` | 销售分析 |
| `common_all/analysis/service/reportform/` | 报表格式 |
| `common_all/analysis/service/external/` | 外部数据 |
| `common_all/analysis/service/flow/` | 流量分析 |
| `common_all/analysis/service/rd/` | RD 数据 |
| `common_all/analysis/domain/` | 分析实体 |
| `common_all/analysis/mapper/` | 分析 Mapper |
| `common_all/analysis/utils/` | 分析工具类 |
| `merchant/analysis/controller/` | 商户端分析 Controller（24个） |
| `admin/analysis/controller/` | 管理端分析 Controller |
