给我看看bb每月的init 
/Users/martinjiang/VsCodeProjects/martin-dev-log/bi-cost/flink/quantum-v2/bb/month-init
和
/Users/martinjiang/VsCodeProjects/martin-dev-log/bi-cost/flink/quantum-v2/bb/batch/dws_online_bb_active_card_count_v2-batch-sql.sql
/Users/martinjiang/VsCodeProjects/martin-dev-log/bi-cost/flink/quantum-v2/bb/batch/dws_online_bb_card_finance_daily_v2-batch-sql.sql
/Users/martinjiang/VsCodeProjects/martin-dev-log/bi-cost/flink/quantum-v2/bb/batch/dws_online_bb_channel_fixed_fee_v2-batch-sql.sql
这三个点差异目前我看了结果78 两个月差距较大,之前也遇到这种情况我冲涮batch脚本后恢复正常
/Users/martinjiang/VsCodeProjects/martin-dev-log/bi-cost/online/check/v2/query_bb_card_cost_detail_v5.sql
INSERT INTO "MY_TABLE"(month, calculated_cost, actual_channel_cost, cost_diff, calculated_cashback, actual_cashback, cashback_diff) VALUES ('2026-03', 581667.9331, 581667.9400, 0.0069, 377909.97180495, 377910.00000000, -0.0282);
INSERT INTO "MY_TABLE"(month, calculated_cost, actual_channel_cost, cost_diff, calculated_cashback, actual_cashback, cashback_diff) VALUES ('2026-04', 493871.0229, 493871.0000, -0.0229, 339556.00903875, 339556.00000000, 0.0090);
INSERT INTO "MY_TABLE"(month, calculated_cost, actual_channel_cost, cost_diff, calculated_cashback, actual_cashback, cashback_diff) VALUES ('2026-05', 458270.9767, 458271.0000, 0.0233, 352991.01638325, 352991.00000000, 0.0164);
INSERT INTO "MY_TABLE"(month, calculated_cost, actual_channel_cost, cost_diff, calculated_cashback, actual_cashback, cashback_diff) VALUES ('2026-06', 413839.2824, 413824.0000, -15.2824, 332501.77455203, 332480.00000000, 21.7746);
INSERT INTO "MY_TABLE"(month, calculated_cost, actual_channel_cost, cost_diff, calculated_cashback, actual_cashback, cashback_diff) VALUES ('2026-07', 420110.0729, 432056.0000, 11945.9271, 345608.39997791, 359663.00000000, -14054.6000);
INSERT INTO "MY_TABLE"(month, calculated_cost, actual_channel_cost, cost_diff, calculated_cashback, actual_cashback, cashback_diff) VALUES ('2026-08', 346200.0847, 465253.0000, 119052.9153, 243076.25625916, 340422.00000000, -97345.7437);


给我更新一下/Users/martinjiang/VsCodeProjects/martin-dev-log/bi-cost/online/check/v2/query_bb_card_cost_detail_v5.sql
BB:2026-08
成本：465,253
渠道返现：340,422

BB:总成本：465,253
BB实际返现：-340,422

BB:2026-08
BB成本：472,402
BB渠道返现：332,071


select detail_url
from api_client_bill
where delete_time is null and customer_type='API'
  and bill_month='2026-08' and type='MonthlyStatement'
这个文件是一个zip 文件里面包含活跃卡的列表但是现在产品说不能显示provider字段 
所以我们要修一下这个，生产都已经生成了有上万个数据所以我想说
怎么修这个数据最快