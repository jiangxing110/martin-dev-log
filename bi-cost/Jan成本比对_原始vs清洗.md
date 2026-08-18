# 1月 成本比对：原始库 vs 清洗库

## 结论速览
- 清洗库总成本 **686,494.03**，原始库 **688,809.14**，清洗库 **低 2,315.10**（降幅 **0.34%**）。
- 差异 **97.1% 集中在 Count Fee（交易笔数费）**，合计 -2,247.91。
- 10 个费用项两库完全一致（Decline Fee 全系、Active Card、Dollar Volume 两项、Fixed Fee）。
- 3 个 Refund Fee 在清洗库反而略高（+8.52），属反向小差异。

## 逐项比对（Δ = 清洗库 − 原始库）

| # | 费用项 | 原始库 | 清洗库 | Δ(清洗−原始) | 说明 |
|---|--------|--------|--------|--------------|------|
|1|Mastercard Domestic Count Fee|18370.4240|18342.6290|-27.7950|↓|
|2|Mastercard International Count Fee|125363.4060|124283.9400|-1079.4660|↓ 最大单项|
|3|VISA Domestic Count Fee|5613.3850|5589.9675|-23.4175|↓|
|4|VISA International Count Fee|42718.6890|42568.9110|-149.7780|↓|
|5|AC Mastercard Domestic Count Fee|44469.1660|44046.6820|-422.4840|↓|
|6|AC Mastercard International Count Fee|46580.7990|46085.6400|-495.1590|↓|
|7|AC VISA Domestic Count Fee|4843.3625|4820.7425|-22.6200|↓|
|8|AC VISA International Count Fee|9674.5140|9647.3250|-27.1890|↓|
|9|Mastercard Domestic Dollar Volume Fee|10228.0801|10228.0801|0.0000|一致|
|10|Mastercard International Dollar Volume Fee|106761.9760|106761.9372|-0.0388|≈一致|
|11|Visa Domestic Dollar Volume Fee|2988.1087|2988.1087|0.0000|一致|
|12|Visa International Dollar Volume Fee|17411.0947|17410.9965|-0.0982|≈一致|
|13|Mastercard International Reversal Fee|13190.7740|13151.9480|-38.8260|↓|
|14|Visa International Reversal Fee|6560.9460|6546.6660|-14.2800|↓|
|15|Domestic Reversal Fee|3574.0620|3551.6340|-22.4280|↓|
|16|Mastercard International Refund Fee|1891.9725|1896.8175|+4.8450|↑ 反向|
|17|VISA International Refund Fee|556.1820|557.1360|+0.9540|↑ 反向|
|18|Domestic Refund Fee|675.2550|677.9800|+2.7250|↑ 反向|
|19|Mastercard International Decline Fee|55533.0435|55533.0435|0.0000|一致|
|20|Visa International Decline Fee|23268.1890|23268.1890|0.0000|一致|
|21|Domestic Decline Fee|28138.0620|28138.0620|0.0000|一致|
|22|AC Mastercard International Decline Fee|6325.7620|6325.7620|0.0000|一致|
|23|AC Visa International Decline Fee|1384.4460|1384.4460|0.0000|一致|
|24|AC Domestic Decline Fee|10490.6970|10490.6970|0.0000|一致|
|25|Active Card Account Fee|20767.8000|20767.8000|0.0000|一致|
|26|Volume Fee Cost|81428.9391|81428.8912|-0.0479|≈一致|
|27|Fixed Fee|0.0000|0.0000|0.0000|一致|
| |**TOTAL**|**688809.1352**|**686494.0317**|**-2315.1035**| |

## 差异归因
- **Count Fee（1–8 项）**：合计 Δ = -2,247.91，占全部差异的 **97.1%**。Count Fee 按交易笔数计费，清洗库笔数更少 → 费用更低。与“清洗/去重后交易笔数口径变化”高度一致。
- **Reversal Fee（13–15 项）**：合计 -75.53，方向与 Count Fee 一致，量级小。
- **Refund Fee（16–18 项）**：清洗库反而高 +8.52，方向相反，疑为退款交易归类微调，量级极小。
- **Dollar Volume / Volume Fee Cost（9–12, 26）**：几乎完全一致（差异 < 0.1），说明按金额计费的口径未被清洗影响。
- **Decline Fee（19–24）/ Active Card（25）/ Fixed Fee（27）**：完全一致，说明这部分口径两库相同。

## 建议
1. 核心问题：清洗库比原始库 **少计了约 2,315 的交易笔数费**。需确认清洗逻辑（去重/剔除测试单/void 单等）是否应当减少这些笔数。
2. 若清洗是“修正重复/脏数据”，则差异为**合理修正**；若清洗误删了真实交易，则为**数据丢失**，需回补。
3. 建议核查两库的 Count Fee 口径 SQL（笔数来源表/过滤条件），定位 2,247.91 的笔数缺口对应多少笔交易。
4. 反向的 3 个 Refund Fee（+8.52）也建议顺带核对退款归类逻辑。
