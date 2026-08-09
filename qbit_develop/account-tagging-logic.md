# 账户打标结构与枚举说明

## 1. 整体结构

账户打标由两层数据组成：

1. `system_tag`：标签字典，定义有哪些标签、标签类型、类目、层级、父子关系和状态。
2. `tags`：账户标签关系，记录某个账户绑定了哪个 `system_tag`，以及来源、操作人、过期时间等信息。

可以理解为：`system_tag` 是“标签树”，`tags` 是“账户被打上的标签记录”。

## 2. 标签字典结构：system_tag

`system_tag` 用来表达标签本身及树形结构。

| 字段 | 说明 |
| --- | --- |
| `id` | 标签 ID，账户打标时最终保存到 `tags.systemTagId` |
| `tagType` | 标签大类，见 `AccountTagEnum` |
| `categoryType` | 标签业务类目，见 `TagCategoryEnum` |
| `tagGrade` | 标签层级，见 `TagGradeEnum` |
| `status` | 标签状态，见 `TagStatusEnum` |
| `name` | 标签名称 |
| `parentId` | 父标签 ID；一级标签为空 |
| `operationUserId` | 创建或最后操作人 ID |

### 2.1 标签大类：AccountTagEnum

| 枚举 | 存储值 | 说明 | 支持类目 |
| --- | --- | --- | --- |
| `PRODUCT` | `product` | 产品标签 | `PRODUCT_TYPE` |
| `BUSINESS` | `business` | 业务标签 | `CUSTOMER_TYPE`、`CUSTOMER_INDUSTRY` |
| `COMPLIANCE` | `compliance` | 合规标签 | `COMPLIANCE` |
| `SYSTEM_RISK_CONTROL` | `system_risk_control` | 系统风控标签 | 当前不参与普通标签树 V2 |

### 2.2 标签业务类目：TagCategoryEnum

| 枚举 | 存储值 | 说明 |
| --- | --- | --- |
| `CUSTOMER_TYPE` | `customer_type` | 客户类型 |
| `CUSTOMER_INDUSTRY` | `customer_industry` | 客户行业 |
| `PRODUCT_TYPE` | `product_type` | 产品类型 |
| `COMPLIANCE` | `compliance` | 合规 |

### 2.3 标签层级：TagGradeEnum

| 枚举 | 存储值 | 说明 |
| --- | --- | --- |
| `FIRST` | `first` | 一级标签 |
| `SECOND` | `second` | 二级标签 |
| `THIRD` | `third` | 三级标签 |

树形关系通过 `parentId` 维护。`FIRST` 或 `parentId = null` 的标签会被识别为根节点。

### 2.4 标签状态：TagStatusEnum

| 枚举 | 存储值 | 说明 |
| --- | --- | --- |
| `Active` | `Active` | 启用 |
| `Inactive` | `Inactive` | 停用 |

普通打标和自动规则目标标签都要求标签有效；自动规则启用时还会要求目标标签是叶子标签。

## 3. 标签树 V2 结构

标签树 V2 的核心是按 `categoryType` 分组返回，而不是只按 `tagType` 展示。

### 3.1 分组结构：SystemTagTreeV2VO

| 字段 | 说明 |
| --- | --- |
| `show` | 当前用户是否有该类目对应标签类型的展示权限 |
| `categoryType` | 当前分组的标签业务类目 |
| `tags` | 当前类目下的标签树节点列表 |

示例：

```json
{
  "show": true,
  "categoryType": "customer_type",
  "tags": []
}
```

### 3.2 节点结构：SystemTagNodeV2VO

| 字段 | 说明 |
| --- | --- |
| `id` | 标签 ID |
| `name` | 标签名称 |
| `tagType` | 标签大类 |
| `categoryType` | 标签业务类目 |
| `tagGrade` | 标签层级 |
| `status` | 标签状态 |
| `parentId` | 父标签 ID |
| `children` | 子标签列表 |

示例：

```json
{
  "id": 1001,
  "name": "直客",
  "tagType": "business",
  "categoryType": "customer_type",
  "tagGrade": "first",
  "status": "Active",
  "parentId": null,
  "children": []
}
```

### 3.3 V2 构树规则

1. 普通标签树 V2 不包含 `SYSTEM_RISK_CONTROL`。
2. 如果指定 `categoryType`，会反推支持该类目的 `tagType`。
3. 如果未指定 `categoryType` 但指定 `tagType`，只取该标签大类。
4. 如果 `categoryType` 和 `tagType` 都为空，则取除系统风控外的所有标签大类。
5. 标签按 `categoryType` 分组。
6. 每个分组内按 `parentId` 递归生成树。
7. `tagGrade = FIRST` 或 `parentId = null` 的标签作为根节点。
8. 同级节点按 `id` 升序。
9. `show` 只表示权限标记，树本身不会因为 `show = false` 被过滤掉。

### 3.4 权限标记 show

| 用户身份 | `show = true` 的范围 |
| --- | --- |
| 超级管理员 | 全部普通标签 |
| 销售、AM、运营经理 | 产品标签、业务标签 |
| 合规角色 | 合规标签 |
| 其他用户 | 无对应权限时为 `false` |

## 4. 账户标签记录结构：tags

`tags` 记录账户与标签的绑定关系。

| 字段 | 说明 |
| --- | --- |
| `accountId` | 被打标账户 ID |
| `sourceId` | 来源 ID；普通账户标签通常是 NullUUID |
| `sourceType` | 标签来源类型，见 `TagSourceTypeEnum` |
| `name` | 标签名称或历史冗余字段；新标签体系主要看 `systemTagId` 关联的名称 |
| `baseType` | 通用标签常用 `common` |
| `parentId` | 历史父标签字段，普通新标签主要依赖 `system_tag.parentId` |
| `operationUserId` | 操作人 ID |
| `systemTagId` | 关联的标签字典 ID |
| `tagSource` | 标签记录来源，见 `TagRecordSourceEnum` |
| `expiryTime` | 过期时间，主要用于系统风控临时标签 |

### 4.1 标签来源类型：TagSourceTypeEnum

| 枚举 | 说明 |
| --- | --- |
| `Account` | 账户来源，历史导入打标会使用 |
| `QbitCard` | 卡标签来源 |
| `QbitCardTransactionScene` | 量子卡交易场景 |
| `ClickHouseCreditAccount` | ClickHouse 查询到的退款客户标签专用 |
| `CSMDb` | CSM 数据库来源 |
| `CSM` | CSM 来源 |
| `AuthorizationAbnormalCard` | 0 元授权场景异常卡 |
| `ReversalAbnormalCard` | Reversal 场景异常卡 |
| `AccountCommon` | 老公共账户标签来源 |
| `product` | 产品标签来源 |
| `business` | 业务标签来源 |
| `compliance` | 合规标签来源 |
| `system_risk_control` | 系统风控标签来源 |

### 4.2 标签记录来源：TagRecordSourceEnum

| 枚举 | 存储值 | 说明 |
| --- | --- | --- |
| `MANUAL` | `MANUAL` | 人工打标 |
| `AUTO_RULE` | `AUTO_RULE` | 自动规则打标 |
| `HISTORY_MIGRATION` | `HISTORY_MIGRATION` | 历史迁移打标 |

### 4.3 sourceType 与 tagType 的对应关系

人工打标和自动规则写入 `tags` 时，会根据 `system_tag.tagType` 转换 `sourceType`：

| `system_tag.tagType` | `tags.sourceType` |
| --- | --- |
| `PRODUCT` | `product` |
| `BUSINESS` | `business` |
| `COMPLIANCE` | `compliance` |
| `SYSTEM_RISK_CONTROL` | `system_risk_control` |

历史公共标签可能仍使用 `AccountCommon` 或 `Account`。

## 5. 打标约束

1. 普通账户打标只能选择叶子标签，也就是没有子标签的 `system_tag`。
2. 自动打标规则的目标标签也必须是叶子标签。
3. 人工打标写入 `tagSource = MANUAL`。
4. 自动规则打标写入 `tagSource = AUTO_RULE`。
5. 自动规则只新增缺失标签，不会因为后续规则不命中而自动删除已有标签。
6. 系统风控标签可带 `expiryTime`，普通产品、业务、合规标签通常不依赖过期时间。

## 6. 自动打标规则结构

自动打标规则本质上也是把命中的账户绑定到某个 `systemTagId`。规则配置由逻辑树组成。

### 6.1 规则实体：tag_auto_rule

| 字段 | 说明 |
| --- | --- |
| `ruleName` | 规则名称 |
| `ruleDescription` | 规则描述 |
| `systemTagId` | 命中后要打上的目标标签 ID |
| `rawData` | 规则逻辑树 JSON |
| `status` | 规则状态：`Active` / `Inactive` |
| `dataRange` | 数据范围，按天；当前执行逻辑未实际使用 |
| `operationUserId` | 创建或最后操作人 ID |

### 6.2 规则节点结构

分组节点：

```json
{
  "concatRelation": "And",
  "children": []
}
```

条件节点：

```json
{
  "fieldName": "customer_type",
  "ruleMatch": "=",
  "fieldValue": "directCustomer"
}
```

### 6.3 分组关系

| 值 | 说明 |
| --- | --- |
| `And` / `AND` | 子节点全部命中 |
| `Or` / `OR` | 子节点任一命中 |

## 7. 自动规则字段枚举

### 7.1 TagRuleFieldEnum

| 枚举 | 字段值 | 展示名 | 支持操作符 |
| --- | --- | --- | --- |
| `INDUSTRY_CATEGORY` | `industryCategory` | 客户行业 | `=`, `!=`, `include`, `noInclude` |
| `CUSTOMER_TYPE` | `customer_type` | 客户类型 | `=`, `!=` |
| `CRYPTO_KYB` | `crypto_kyb` | 加密资产 KYB | `=`, `!=` |

### 7.2 TagRuleOperatorEnum

| 枚举 | 存储值 | 说明 |
| --- | --- | --- |
| `EQ` | `=` | 等于 |
| `NE` | `!=` | 不等于 |
| `INCLUDE` | `include` | 包含 |
| `NO_INCLUDE` | `noInclude` | 不包含 |
| `GT` | `gt` | 大于 |
| `GTE` | `gte` | 大于等于 |
| `LT` | `lt` | 小于 |
| `LTE` | `lte` | 小于等于 |

当前实际开放字段没有使用 `gt/gte/lt/lte`。

## 8. 自动规则字段值来源

| 规则字段 | 来源说明 |
| --- | --- |
| `industryCategory` | 最新全球账户 KYB，`businessType = MultiCurrencyAccount`，取 `cddKybDetail.key = industryCategory` 的值 |
| `crypto_kyb` | 最新加密资产 KYB，`businessType = DigitalCurrencies`，取 KYB 状态；没有记录时按 `Na` |
| `customer_type` | 根据账户类型、系统类型、接入类型推导出的客户类型集合 |

## 9. 客户类型枚举：AutoTagCustomerTypeEnum

`customer_type` 支持传 code 或枚举名比较，不按中文 label 比较。

| 枚举 | code | 中文说明 |
| --- | --- | --- |
| `DIRECT_CUSTOMER` | `directCustomer` | 直客 |
| `CHANNEL_PARTNER` | `channelPartner` | 渠道方 |
| `QBIT_PARTNER` | `qbitPartner` | 趣拿钱合伙人 |
| `WEB3_PARTNER` | `web3Partner` | Web3 合伙人 |
| `DISTRIBUTOR` | `distributor` | Distributor |
| `MOR` | `mor` | MOR |
| `GATEWAY` | `gateway` | Gateway |

推导规则：

| 条件 | 推导值 |
| --- | --- |
| 账户类型为 `Merchant` / `SubAccount` / `MasterAccount` | `DIRECT_CUSTOMER` |
| 账户类型为 `Agent` / `NewChannel` | `CHANNEL_PARTNER` |
| 账户类型为 `Channel` 且系统类型为 `QBIT` | `QBIT_PARTNER` |
| 账户类型为 `Channel` 且系统类型非空并且不是 `QBIT` | `WEB3_PARTNER` |
| 接入类型为 `DISTRIBUTOR` | `DISTRIBUTOR` |
| 接入类型为 `MOR` | `MOR` |
| 接入类型为 `GATEWAY` | `GATEWAY` |

## 10. 客户行业枚举：CustomerIndustryEnum

`industryCategory` 使用 KYB 行业原值匹配到 `CustomerIndustryEnum`。规则执行时实际比较的是枚举名；展示时可使用 code 或中文说明。

| 枚举 | code | 中文说明 |
| --- | --- | --- |
| `FASHION_CLOTHING_AND_ACCESSORIES` | `Fashion Clothing and Accessories` | 服装和配饰 |
| `LUGGAGE` | `Luggage` | 行李箱 |
| `ELECTRONICS` | `Electronics` | 电子产品 |
| `HEALTH_AND_HOUSEHOLD` | `Health and Household` | 健康和家居产品 |
| `HOME_AND_KITCHEN` | `Home and Kitchen` | 家庭厨房用品 |
| `SPORTS_AND_OUTDOORS` | `Sports and Outdoors` | 运动和户外用品 |
| `TOOLS_HOME_IMPROVEMENT` | `Tools Home Improvement` | 家庭工具 |
| `TOYS_AND_GAMES` | `Toys and Games` | 玩具和游戏设备 |
| `PET_SUPPLIES` | `Pet supplies` | 宠物用品 |
| `COMPUTERS` | `Computers` | 计算机 |
| `ARTS_CRAFTS` | `Arts Crafts` | 工艺品 |
| `AUTOMOTIVE` | `Automotive` | 汽车用品 |
| `BABY` | `Baby` | 婴儿用品 |
| `BEAUTY_AND_PERSONAL_CARE` | `Beauty and personal care` | 美容和护理产品 |
| `INDUSTRIAL_AND_SCIENTIFIC` | `Industrial and Scientific` | 工业和科学产品 |
| `MOVIES_TELEVISION` | `Movies Television` | 媒体和影像设备 |
| `ADVERTISING_SERVICES` | `Advertising services, advertising publishers, advertising channels and exhibitions` | 广告相关服务 |
| `WEBSITES_IT_SOFTWARE` | `Websites, IT & Software` | 软件和技术服务 |
| `FREIGHT_SHIPPING_TRANSPORTATION` | `Freight, Shipping & Transportation` | 物流运输 |
| `PASSENGER_RAILWAYS` | `Passenger railways, limousines, taxicabs, motor freight carriers` | 运输服务 |
| `MEDIA_AND_INTERNET_VIDEO_SERVICE` | `Media and Internet Video Service` | 媒体和互联网视频服务 |
| `DIGITAL_GOODS_SOFTWARE` | `Digital Goods: Computer software, mobile applications producer developers or selling (Excludes Games)` | 软件销售（不包括游戏） |
| `ONLINE_EDUCATION` | `Online Education` | 在线教育 |
| `FILE_SHARING_STORAGE` | `File sharing / storage services (cyber-lockers) ` | 文件存储服务 |
| `DATA_ENTRY_ADMIN` | `Data Entry & Admin` | 数据登记和管理服务 |
| `DIGITAL_GOODS_ONLINE_GAMES` | `Digital goods: online games` | 网络游戏 |
| `ACCOUNTING_HUMAN_RESOURCES_LEGAL` | `Accounting, Human Resources & Legal` | 会计、人力资源和法律服务 |
| `TELECOMMUNICATIONS` | `Telecommunications` | 通讯产品 |
| `TRAVEL_AGENCY` | `Travel agency, ticketing services, and tour operators` | 旅行和票务服务 |
| `LODGING_HOTELS` | `Lodging, hotels, motels resort and accommodation services` | 酒店和住宿服务 |
| `PHOTOGRAPHIC_STUDIOS` | `Photographic studios and portraits` | 摄影摄像服务 |
| `ART_DESIGN_ARCHITECTURE_AND_MEDIA` | `Art Design Architecture and Media` | 艺术设计，建筑和媒体服务 |
| `ENGINEERING_SCIENCE` | `Engineering & Science` | 工程和科学技术服务 |
| `TRANSLATION_LANGUAGES` | `Translation & Languages` | 翻译和语言相关服务 |

## 11. 命中日志结构

自动规则命中后会生成 `tag_rule_log`。

| 字段 | 说明 |
| --- | --- |
| `executeBatchNo` | 执行批次号 |
| `ruleId` | 规则 ID |
| `accountId` | 命中账户 ID |
| `accountName` | 命中时账户名称快照 |
| `systemTagId` | 命中标签 ID |
| `tagName` | 命中标签名称快照 |
| `conditionSnapshot` | 命中时规则条件树快照 |
| `fieldValueSnapshot` | 命中时实际字段值快照 |
| `hitTime` | 命中时间 |

## 12. 一个完整标签树示例

```json
[
  {
    "show": true,
    "categoryType": "customer_type",
    "tags": [
      {
        "id": 1,
        "name": "客户类型",
        "tagType": "business",
        "categoryType": "customer_type",
        "tagGrade": "first",
        "status": "Active",
        "parentId": null,
        "children": [
          {
            "id": 2,
            "name": "直客",
            "tagType": "business",
            "categoryType": "customer_type",
            "tagGrade": "second",
            "status": "Active",
            "parentId": 1,
            "children": []
          }
        ]
      }
    ]
  }
]
```

账户实际打标时，应保存叶子节点，例如上例里的 `id = 2`，而不是父节点 `id = 1`。
