 dwm_online_bb_card_transaction_detail_v2-batch-sql

 [1]:TableSourceScan(table=[[vvp, default, source_quantum_card_transaction_extend, filter=[and(and(and(=(channel_provision, _UTF-16LE'BLUEBANC':VARCHAR(2147483647) CHARACTER SET &quot;UTF-16LE&quot;), IS NULL(delete_time)), OR(=(type, _UTF-16LE'Consumption':VARCHAR(11) CHARACTER SET &quot;UTF-16LE&quot;), =(type, _UTF-16LE'Credit':VARCHAR(11) CHARACTER SET &quot;UTF-16LE&quot;))), AND(&gt;=(business_time, 2026-05-01 00:00:00:TIMESTAMP(6)), &lt;(business_time, 2026-06-01 00:00:00:TIMESTAMP(6))))], project=[id, source_id, card_transaction_id, account_id, country, type, transaction_time, original_completion_time, business_time, business_code_list, remarks, card_id, detail, create_time, update_time]]], fields=[id, source_id, card_transaction_id, account_id, country, type, transaction_time, original_completion_time, business_time, business_code_list, remarks, card_id, detail, create_time, update_time])

 [4]:TableSourceScan(table=[[vvp, default, source_qbit_card, filter=[OR(=(type, _UTF-16LE'Master':VARCHAR(6) CHARACTER SET &quot;UTF-16LE&quot;), =(type, _UTF-16LE'VISA':VARCHAR(6) CHARACTER SET &quot;UTF-16LE&quot;))], project=[id, type]]], fields=[id, type])

[12]:TableSourceScan(table=[[vvp, default, source_qbit_card_settlement, filter=[and(=(provider, _UTF-16LE'BlueBancCard':VARCHAR(2147483647) CHARACTER SET &quot;UTF-16LE&quot;), IS NULL(deleteTime))], project=[id, transactionId, qbitCardTransactionId, transactionType, billingAmount, rawData]]], fields=[id, transactionId, qbitCardTransactionId, transactionType, billingAmount, rawData])
:- [13]:Calc(select=[id, transactionId, transactionType, billingAmount, rawData])
+- [19]:Calc(select=[id, qbitCardTransactionId, transactionType, billingAmount, rawData])
 
  [44]:TableSourceScan(table=[[vvp, default, source_api_account_relation, filter=[IS NULL(delete_time)], project=[account_id, root_id]]], fields=[account_id, root_id])
