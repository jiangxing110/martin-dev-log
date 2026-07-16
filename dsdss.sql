/Users/martinjiang/martin-dev-log/bi-cost/flink/quantum-v2
现在这里BB和QI的脚本最后我不想落原来的:
dws_bb_card_finance_daily_p,
dws_qi_card_finance_daily_p,
搞一个v2版本的表表结构可以参考之前的表结构
还是基于/Users/martinjiang/martin-dev-log/bi-cost/bi_month/BB客户成本-202606.sql
/Users/martinjiang/martin-dev-log/bi-cost/bi_month/QI客户毛利2026-06.sql
里面记录的成本逻辑
对于这两个的dwm 和dws 脚本都要考虑状态机的流转
qi渠道的很多都是   AND "status" IN ('Closed', 'Pending')
pending 能看closed 可能fail
他们都有涉及的ods dim层
BB客户成本:
account -> dim_account
salesAccountRelation -> ods_sales_account_relation
                     -> dim_sale_account_relation_p
user -> ods_user
accountExtend -> ods_account_extend
caas_open_api_extend
quantum_card_transaction_extend -> ods_quantum_card_transaction_extend
qbitCard -> ods_qbit_card
qbitCardSettlement -> ods_qbit_card_settlement
bb_card_auth_detail_2026-06

QI客户毛利:
account -> dim_account
salesAccountRelation -> ods_sales_account_relation
                     -> dim_sale_account_relation_p
user -> ods_user
accountExtend -> ods_account_extend
caas_open_api_extend
qbit_card_transaction -> ods_qbit_card_transaction
quantum_card_transaction_extend  -> ods_quantum_card_transaction_extend
api_client_bill -> ods_api_client_bill
api_client_bill_statement -> ods_api_client_bill_statement
Transaction -> ods_transaction
qbitCard -> ods_qbit_card
qbitCardWalletTransaction -> ods_qbit_card_wallet_transaction


然后这个
bi-cost/flink/total_cost/dws_online_total_channel_cost_daily-batch-sql.sql
dws_total_channel_cost_daily_p里最后我也想改成物化视图的板本



我希望你可以给我一写一个设计方案 
要记录从原始数据到ods->dwm->dws的整个数据流转过程，考虑状态机的流转，确保数据的一致性和完整性。
然后代码要怎么改也要考虑到

以下是一个设计方案：


dwm_online_bb_card_auth_detail_v2-batch-sql
auth_table_name 这个应该根据传入的时间自动计算我们一般都是一个固定的 时间段对于
batch
start_time 2026-05-01 00:00:00 
end_time 2026-05-01 00:00:00 
cdc 
start_time 2026-05-01 00:00:00 
end_time 2026-05-02 00:00:00 
这样我们肯定可以固定月份的