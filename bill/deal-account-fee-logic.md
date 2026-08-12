# dealAccountFee 拒付罚款逻辑梳理

## 代码位置

- 主方法：`qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/impl/ApiClientBillServiceImpl.java`
- 入口方法：`dealMonthlyRejectPayByAccount(...)`
- 核心方法：`dealAccountFee(...)`
- 下沉计算方法：`rejectPayFine(...)`、`dealFeeStatementAndStageFee(...)`、`getAccountStageFees(...)`、`getStageFee(...)`、`getMatchRejectAccountFee(...)`

## 一句话结论

当前逻辑是：**先按渠道 provider 选择对应渠道的费率配置，再用账户整体拒付率匹配这组配置里的 low/high 阶梯，最后用当前渠道拒付笔数计算金额**。

也就是说，渠道字段是参与 rate 选择的；但渠道自己的拒付率没有参与阶梯匹配。

```text
每个渠道罚款 = 当前渠道拒付笔数 * 当前渠道配置中按账户整体拒付率匹配出来的 rate
总拒付罚款 = 所有渠道罚款之和
```

## 入口流程：dealMonthlyRejectPayByAccount

`dealMonthlyRejectPayByAccount(...)` 先初始化一个 `monthlyReject` Map：

| Key | 含义 | 初始值 |
| --- | --- | --- |
| `rejectPayCount` | 拒付数量/笔数 | `0` |
| `rejectPayRateCount` | 按数量计算的拒付率 | `0` |
| `conCount` | 无验证消费数量 | `0` |
| `rejectPayFine` | 拒付罚款 | `0` |

然后调用：

```java
quantumCardService.getAccountQuantumCardRiskRateFilterDeletedCard(quantumCardRiskParamDTO)
```

获取账户维度的风控统计结果 `QuantumCardRiskRuleParamsVO`。

如果返回为空，或者 `rejectPayCount`、`rejectPayRateCount`、`conCount` 任意一个为空：

- 不计算罚款
- 异步记录日志：`OpenApiAdmin`
- 返回初始化后的 `monthlyReject`

如果数据完整，则调用：

```java
dealAccountFee(quantumCardRiskRuleParamsVO, monthlyReject, quantumCardRiskParamDTO, apiClientBillStatements)
```

## 主流程：dealAccountFee

### 1. 写入账户整体统计值

方法先从 `quantumCardRiskRuleParamsVO` 取账户整体统计值，并写入 `monthlyReject`：

```java
rejectPayCount = quantumCardRiskRuleParamsVO.getRejectPayCount();
rejectPayRateCount = quantumCardRiskRuleParamsVO.getRejectPayRateCount();
conCount = quantumCardRiskRuleParamsVO.getConCount();
```

对应写入：

```java
monthlyReject.put("rejectPayCount", rejectPayCount);
monthlyReject.put("rejectPayRateCount", rejectPayRateCount);
monthlyReject.put("conCount", conCount);
```

### 2. 拒付笔数为 0 时直接返回

```java
if (rejectPayCount.compareTo(new BigDecimal("0")) <= 0) {
    return;
}
```

含义：

- 当账户整体拒付笔数小于等于 0，不计算拒付罚款
- `rejectPayFine` 保持入口方法初始化的 `0`

### 3. 查询当前生效的拒付费率配置

查询 `accountFee` 表中的费率配置，条件如下：

| 条件 | 含义 |
| --- | --- |
| `startTime <= 当前时间` | 配置已生效 |
| `endTime > 当前时间` | 配置未过期 |
| `accountId in (当前账户, Constant.NULL_UUID)` | 查当前账户配置和默认配置 |
| `rate is not null` | 费率不能为空 |
| `feeType = DECLINE_FEE_API_ACCOUNT_CAAS` | 只查 CaaS API 账户拒付费 |
| `order by createTime desc` | 新配置优先 |

对应代码：

```java
lambdaQueryWrapper.le(AccountFee::getStartTime, date);
lambdaQueryWrapper.gt(AccountFee::getEndTime, date);
lambdaQueryWrapper.in(AccountFee::getAccountId, Arrays.asList(quantumCardRiskParamDTO.getAccountId(), Constant.NULL_UUID));
lambdaQueryWrapper.isNotNull(AccountFee::getRate);
lambdaQueryWrapper.orderByDesc(AccountFee::getCreateTime);
lambdaQueryWrapper.eq(AccountFee::getFeeType, AccountFeeType.DECLINE_FEE_API_ACCOUNT_CAAS);
```

### 4. 有配置才计算罚款

```java
BigDecimal rejectPayFine = BigDecimal.ZERO;
if (CollectionUtil.isNotEmpty(accountFees)) {
    rejectPayFine = rejectPayFine(accountFees, quantumCardRiskParamDTO, quantumCardRiskRuleParamsVO, apiClientBillStatements);
}
monthlyReject.put("rejectPayFine", rejectPayFine);
```

如果没有任何费率配置：

- 当前不会走默认硬编码罚款逻辑
- 历史硬编码逻辑已经被注释掉
- 最终 `rejectPayFine = 0`

被注释掉的历史逻辑大致是：

```text
20% <= 拒付率 < 50%：每笔 0.3
拒付率 >= 50%：每笔 0.6
```

但当前不生效。

## 渠道拆分流程：rejectPayFine

### 1. 查询渠道/卡段维度拒付数量

方法先调用：

```java
quantumCardService.getQuantumCardRiskRateFilterDeletedCardAndChannelProvision(quantumCardRiskParamDTO)
```

获取按渠道/卡段拆分后的拒付数据。

如果返回为空：

```java
return BigDecimal.ZERO;
```

即没有渠道拆分数据时，不计算罚款。

### 2. 账户费率优先，默认费率兜底

先从全部 `accountFees` 中筛选当前账户自己的配置：

```java
accountFees.stream()
    .filter(a -> a.getAccountId().equals(quantumCardRiskParamDTO.getAccountId()))
```

如果当前账户没有配置，则使用默认配置：

```java
accountFees.stream()
    .filter(a -> a.getAccountId().equals(Constant.NULL_UUID))
```

同时 `accountId` 标记为 `Constant.NULL_UUID`。

优先级是：

```text
当前账户配置 > 默认配置 Constant.NULL_UUID
```

### 3. 遍历每个渠道分别计算

对每个 `QuantumCardRiskRuleParamsChannelProvisionVO`：

```java
for (QuantumCardRiskRuleParamsChannelProvisionVO item : channelProvisions) {
    ...
}
```

每个渠道都会单独：

- 确定 provider
- 匹配费率配置
- 计算当前渠道罚款
- 生成一条账单明细
- 累加到总拒付罚款

## provider 处理规则

默认 provider 来自：

```java
quantumCardRiskRuleParamsChannelProvisionVO.getChannelProvision()
```

特殊处理：

```java
if (SystemTypeTransEnum.QBIT.name().equals(channelProvision)) {
    provider = "QbitIssuing";
}
```

即：

```text
QBIT -> QbitIssuing
```

后续用这个 provider 去匹配 `AccountFee.provider`。

生成账单明细时，还会通过枚举转成 provider 编码：

```java
String cardProvider = AccountFeeCardProvider.getItem(provider).getName();
apiClientBillStatement.setProvider(cardProvider);
```

例如 `QbitIssuing` 对应编码是 `IQ`。

注意：如果 `AccountFeeCardProvider.getItem(provider)` 返回 `null`，当前代码会有空指针风险，因为直接调用了 `.getName()`。

## 费率匹配规则

### 当前代码使用账户整体拒付率

费率匹配时传入的是：

```java
quantumCardRiskRuleParamsVO.getRejectPayRateCount()
```

这个值来自账户整体统计，不是渠道维度对象。

对应调用：

```java
getAccountStageFees(accountFee, provider, accountId, quantumCardRiskRuleParamsVO.getRejectPayRateCount())
getMatchRejectAccountFee(stageAccountFee, quantumCardRiskRuleParamsVO.getRejectPayRateCount())
```

所以当前是按渠道 provider 找对应渠道配置，但不是按渠道自己的拒付率匹配阶梯。

### 区间匹配规则

`getMatchRejectAccountFee(...)` 的区间规则是：

```text
low <= 账户整体拒付率 < high
```

边界特殊处理：

```text
当 high = 100 且 账户整体拒付率 = 100 时，也算匹配
```

对应代码：

```java
a.getLow().compareTo(rejectPayRateCount) <= 0
&& (
    a.getHigh().compareTo(rejectPayRateCount) > 0
    || (
        a.getHigh().compareTo(new BigDecimal("100")) == 0
        && rejectPayRateCount.compareTo(new BigDecimal("100")) == 0
    )
)
```

## 当前账户配置下的渠道配置选择规则

逻辑在 `getAccountStageFees(...)` 和 `getStageFee(...)`。

### 1. 如果使用的是默认配置

当 `uuid = Constant.NULL_UUID` 时：

```java
if (Constant.NULL_UUID.equals(uuid)) {
    return accountFees.stream()
        .filter(a -> 匹配拒付率区间)
        .toList();
}
```

默认配置分支只按拒付率区间过滤，没有在这里按 provider 过滤。

后续还会再调用 `getMatchRejectAccountFee(...)` 做一次同样的拒付率区间过滤。

#### Constant.NULL_UUID 没有配置渠道时

如果默认账户 `Constant.NULL_UUID` 的配置没有渠道，即：

```text
accountId = Constant.NULL_UUID
provider = null
```

当前代码会把它当作默认通用费率。只要 `low/high` 命中账户整体拒付率，这条配置就可以被任何渠道使用。

示例：

```text
默认配置：accountId = Constant.NULL_UUID, provider = null, low = 20, high = 50, rate = 0.3
账户整体拒付率：30%
当前渠道：Penny，且当前账户没有 Penny 配置
```

结果：

```text
Penny 会回退使用 Constant.NULL_UUID + provider = null 的 rate = 0.3
```

需要注意的是，默认配置分支当前不按 provider 过滤。如果默认配置里同时存在多条同区间配置，例如：

```text
Constant.NULL_UUID + provider = null + low = 20 + high = 50 + rate = 0.3
Constant.NULL_UUID + provider = Penny + low = 20 + high = 50 + rate = 0.5
```

当前代码会先把这些命中区间的默认配置都返回，后续 `dealFeeStatementAndStageFee(...)` 会取最大 `rate`，因此最终可能使用 `0.5`。

### 2. 如果使用的是当前账户配置

先取当前账户配置中最新的 `createTime`：

```java
Date maxTime = getMaxTime(accountFees, null);
```

然后调用：

```java
getStageFee(accountFees, maxTime, provider)
```

### 3. 最新批次存在通用配置时，所有渠道共用

在同一个最新 `createTime` 批次里，如果存在：

```java
provider == null
```

则直接返回这些通用配置：

```java
List<AccountFee> commonFee = leastAccountFees.stream()
    .filter(a -> Objects.isNull(a.getProvider()))
    .toList();
```

含义：

```text
最新配置如果是不带 provider 的通用配置，则所有渠道都使用该通用配置。
```

### 4. 最新批次没有通用配置时，按 provider 匹配

如果最新批次没有通用配置，则按当前渠道匹配：

```java
provider.equalsIgnoreCase(a.getProvider())
```

匹配到则使用该渠道配置。

### 5. 当前批次找不到当前渠道时，继续找更早配置

如果最新批次既没有通用配置，也没有当前渠道配置，则取更早的 `createTime` 继续递归查找：

```java
maxTime = getMaxTime(accountFees, maxTime);
if (Objects.nonNull(maxTime)) {
    return getStageFee(accountFees, maxTime, provider);
}
```

直到找到，或者没有更早配置。

### 6. 当前账户找不到渠道配置时，回退默认配置

在 `rejectPayFine(...)` 中，如果当前渠道没有可用配置：

```java
if (CollectionUtil.isEmpty(stageAccountFee)) {
    stageAccountFee = accountFees.stream()
        .filter(a -> a.getAccountId().equals(Constant.NULL_UUID))
        .toList();
}
```

含义：

```text
当前账户存在配置，但当前渠道没匹配到时，会回退到默认账户配置。
```

## 金额计算规则：dealFeeStatementAndStageFee

### 1. 默认金额为 0

```java
BigDecimal rejectPayFine = BigDecimal.ZERO;
apiClientBillStatement.setAmount(BigDecimal.ZERO);
```

如果没有匹配到费率配置，当前渠道罚款就是 `0`。

### 2. 多条配置匹配时取最大 rate

```java
Optional<AccountFee> max = matchAccountFee.stream()
    .max(Comparator.comparing(AccountFee::getRate));
```

即：

```text
同一拒付率区间匹配到多条配置时，取 rate 最大的一条。
```

### 3. 当前渠道罚款公式

```java
BigDecimal amount = rejectFeeVO.getCount().multiply(rate);
```

其中：

| 字段 | 来源 | 含义 |
| --- | --- | --- |
| `count` | `quantumCardRiskRuleParamsChannelProvisionVO.getRejectPayCount()` | 当前渠道拒付笔数 |
| `rate` | 匹配到的 `AccountFee.rate` | 每笔拒付罚款 |

公式：

```text
当前渠道罚款 = 当前渠道拒付笔数 * rate
```

## 账单明细生成规则

每个渠道都会生成一条 `ApiClientBillStatement`，并添加到 `apiClientBillStatements`。

字段设置如下：

| 字段 | 值 |
| --- | --- |
| `accountId` | 当前账户 ID |
| `provider` | `AccountFeeCardProvider.getItem(provider).getName()` |
| `amount` | 当前渠道罚款金额，未匹配费率则为 `0` |
| `rejectInfo` | `RejectFeeVO` 的 JSON 字符串 |
| `item` | `ApiClientFeeEnum.DECLINE_FEE.getDesc()` |
| `type` | `ApiClientFeeEnum.DECLINE_FEE.getValue()` |
| `isSum` | `false` |

`RejectFeeVO` 内容：

| 字段 | 含义 | 来源 |
| --- | --- | --- |
| `rejectRate` | 拒付率 | 账户整体拒付率 |
| `rate` | 每笔拒付罚款 | 匹配到的 `AccountFee.rate` |
| `count` | 当前渠道拒付笔数 | 渠道维度统计 |
| `total` | 账户总拒付笔数 | 账户整体统计 |

## 日志规则

在所有渠道计算完成后，会异步记录一次日志：

```java
CompletableFuture.runAsync(() -> dealLog(
    accountFees,
    quantumCardRiskRuleParamsVO,
    OperationLogEnums.OperationLogBusinessTypeEnum.OpenApiAdminBillStatementReject
));
```

日志记录的是：

- 当前计算使用的费率配置 `accountFees`
- 账户整体拒付统计 `quantumCardRiskRuleParamsVO`
- 业务类型 `OpenApiAdminBillStatementReject`

## 完整优先级总结

### 费率来源优先级

```text
1. 当前账户 accountId 的费率配置
2. 默认账户 Constant.NULL_UUID 的费率配置
3. 都没有则罚款为 0
```

### 当前账户内的渠道配置优先级

```text
1. 最新 createTime 批次的 provider = null 通用配置
2. 最新 createTime 批次中匹配当前 provider 的配置
3. 更早 createTime 批次的 provider = null 通用配置
4. 更早 createTime 批次中匹配当前 provider 的配置
5. 仍找不到，则回退默认账户配置
```

### rate 匹配口径

```text
provider 来源 = 当前渠道，用于匹配对应渠道的费率配置
low/high 阶梯判断 = 账户整体 rejectPayRateCount，不是渠道自己的拒付率
最终 rate = 当前渠道配置中，按账户整体拒付率命中的 rate
```

### 渠道维度使用口径

```text
渠道 provider：用于匹配渠道配置，决定查哪一组 AccountFee.rate
渠道 rejectPayCount：用于计算当前渠道金额
渠道自己的拒付率：当前逻辑未用于 low/high 阶梯匹配
```

## 示例

假设账户整体数据：

```text
账户总拒付笔数 = 10
账户整体拒付率 = 30%
```

渠道拆分：

```text
QbitIssuing 拒付 6 笔
Penny 拒付 4 笔
```

费率配置：

```text
QbitIssuing：20% <= 拒付率 < 50%，rate = 0.5
Penny：20% <= 拒付率 < 50%，rate = 0.3
```

当前计算：

```text
QbitIssuing：先按 provider = QbitIssuing 找到 QbitIssuing 配置，再用账户整体 30% 命中 rate = 0.5
Penny：先按 provider = Penny 找到 Penny 配置，再用账户整体 30% 命中 rate = 0.3

QbitIssuing 罚款 = 6 * 0.5 = 3.0
Penny 罚款 = 4 * 0.3 = 1.2
总拒付罚款 = 3.0 + 1.2 = 4.2
```

这里 `30%` 是账户整体拒付率。渠道 provider 会决定使用哪一组 rate 配置；即使 QbitIssuing 或 Penny 自己有不同的渠道拒付率，当前代码也不会用它们来匹配 low/high 阶梯。

## Corpay 新渠道没有账户费率配置时

`AccountFeeCardProvider` 枚举中已经存在 Corpay：

```java
Corpay("Corpay", "PC")
```

所以如果渠道返回的是 `Corpay`，生成账单明细时不会因为枚举缺失而空指针，明细中的 provider 会被设置为：

```text
PC
```

如果当前账户没有配置 `provider = Corpay` 的拒付手续费，当前逻辑会按下面顺序查找：

```text
1. 当前账户最新 createTime 批次里是否有 provider = null 的通用配置
   有：Corpay 使用这批通用配置

2. 当前账户最新 createTime 批次里是否有 provider = Corpay 的渠道配置
   有：Corpay 使用这批渠道配置

3. 当前账户更早 createTime 批次里是否有 provider = null 或 provider = Corpay 的配置
   有：使用找到的配置

4. 当前账户历史配置都找不到
   回退 Constant.NULL_UUID 默认配置

5. Constant.NULL_UUID 默认配置中，只要 low/high 命中账户整体拒付率
   就会被用于 Corpay

6. 默认配置也没有命中
   Corpay 当前渠道罚款 = 0
```

因此，Corpay 新渠道没有账户级费率配置时，通常结果是：

```text
如果存在当前账户通用配置 provider = null：用当前账户通用配置
否则如果存在 Constant.NULL_UUID 默认配置：用默认配置
否则：Corpay 罚款为 0
```

注意：回退到 `Constant.NULL_UUID` 后，默认配置分支当前不按 provider 过滤，所以默认配置不需要专门配置 `provider = Corpay`。如果默认配置有 `provider = null` 且区间命中，Corpay 可以直接使用。

## 需要注意的潜在问题

1. `AccountFeeCardProvider.getItem(provider).getName()` 有空指针风险。
   - 如果 provider 不在 `AccountFeeCardProvider` 枚举里，会直接 NPE。

2. 默认配置分支没有按 provider 过滤。
   - 当使用 `Constant.NULL_UUID` 默认配置时，`getAccountStageFees(...)` 只按拒付率区间过滤。
   - `Constant.NULL_UUID + provider = null` 会作为通用默认费率，所有回退到默认配置的渠道都可以使用。
   - 如果默认配置里同时存在多个 provider 或通用配置的同一区间配置，后续会取最大 `rate`，可能导致不同渠道都使用默认配置中的最高费率。

3. 渠道自己的拒付率未参与阶梯匹配。
   - 当前会按渠道 provider 匹配对应渠道的 rate 配置。
   - 当前会用渠道拒付笔数参与金额计算。
   - 但 low/high 阶梯匹配使用的是账户整体拒付率。
   - 如果业务要求“每个渠道按自己的拒付率套自己的渠道阶梯”，需要调整传入 `getAccountStageFees(...)` 和 `getMatchRejectAccountFee(...)` 的拒付率来源。

4. `rejectPayCount <= 0` 时提前返回，不会覆盖 `rejectPayFine`。
   - 当前依赖入口方法已经初始化 `rejectPayFine = 0`。
   - 如果未来复用 `dealAccountFee(...)` 且传入的 Map 未初始化，可能产生旧值残留风险。
