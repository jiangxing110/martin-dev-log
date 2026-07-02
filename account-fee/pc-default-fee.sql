-- Card creation fee($/card) Virtual 0.8
INSERT INTO "public"."accountFee" ( "remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate") 
VALUES ( '', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'OpenCard_Caas', '0.8', 'Count', '2026-03-13 17:28:48.745604+08', '2099-12-31 08:00:00+08', 'Single', NULL, NULL, NULL, 'MasterAccount', NULL, 'Corpay', NULL, 't', '0');

-- Monthly card fee($ / active card) 0.1
INSERT INTO "public"."accountFee" ( "remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate") 
VALUES ( '',  now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'MonthlyActiveCardFee_Caas', '0.1', 'Count', '2026-03-13 17:28:50.962905+08', '2099-12-31 08:00:00+08', 'Single', NULL, NULL, NULL, 'MasterAccount', NULL, 'Corpay', NULL, 't', '0');


--Settlement fee International
-- 0 - $30, $0.1/txn
-- $30+, $0/txn
-- Domestic
-- 0 - $30, $0.1/txn
-- $30+, $0/txn
INSERT INTO "public"."accountFee" ( "remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate") 
VALUES ( '', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'QuantumCardSettlementFeeDomRate_Caas', '0', 'Percent', '2026-03-13 17:28:49.606352+08', '2099-12-31 08:00:00+08', 'Single', NULL, NULL, NULL, 'MasterAccount', NULL, 'Corpay', NULL, 't', '0');

INSERT INTO "public"."accountFee" ( "remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate") 
VALUES ( '', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'QuantumCardSettlementFeeIntRate_Caas', '0', 'Percent', '2026-03-13 17:28:49.77591+08', '2099-12-31 08:00:00+08', 'Single', NULL, NULL, NULL, 'MasterAccount', NULL, 'Corpay', NULL, 't', '0');

INSERT INTO "public"."accountFee" ( "remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate") 
VALUES ( '', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'QuantumCardSettlementFeeDom_Caas', '0.1', 'Count', '2026-03-13 17:28:49.945023+08', '2099-02-01 23:59:59+08', 'Tiered', '0', '30', NULL, 'MasterAccount', NULL, 'Corpay', NULL, 't', '0');

INSERT INTO "public"."accountFee" ( "remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate") 
VALUES ( '', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'QuantumCardSettlementFeeDom_Caas', '0', 'Count', '2026-03-13 17:28:50.114212+08', '2099-02-01 23:59:59+08', 'Tiered', '30', NULL, NULL, 'MasterAccount', NULL, 'Corpay', NULL, 't', '0');

INSERT INTO "public"."accountFee" ( "remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate") 
VALUES ( '', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'QuantumCardSettlementFeeInt_Caas', '0.1', 'Count', '2026-03-13 17:28:50.284329+08', '2099-02-01 23:59:59+08', 'Tiered', '0', '30', NULL, 'MasterAccount', NULL, 'Corpay', NULL, 't', '0');

INSERT INTO "public"."accountFee" ( "remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate") 
VALUES ( '', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'QuantumCardSettlementFeeInt_Caas', '0', 'Count', '2026-03-13 17:28:50.452046+08', '2099-02-01 23:59:59+08', 'Tiered', '30', NULL, NULL, 'MasterAccount', NULL, 'Corpay', NULL, 't', '0');


-- Reversal Fee $1 per txn
INSERT INTO "public"."accountFee" ( "remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate") 
VALUES ( '', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'QuantumCardTransactionReversalFee_Caas', '1', 'Count', '2000-01-01 08:00:00+08', '2099-12-31 08:00:00+08', 'Single', NULL, NULL, NULL, 'MasterAccount', NULL, 'Corpay', NULL, 't', '0');

-- Refund Fee 2%
INSERT INTO "public"."accountFee" ( "remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate") 
VALUES ( '', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'TransactionRefundFee_Caas', '0.02', 'Percent', '2022-01-01 23:02:39+08', '2099-11-28 23:02:54+08', 'Single', NULL, NULL, NULL, 'MasterAccount', NULL, 'Corpay', NULL, 't', '0');



--fx|cb
INSERT INTO "public"."accountFee" ( "remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate") 
VALUES ( '', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'QuantumCardMarkUpFeePercentage_Caas', '0.0005', 'Percent', '2026-03-13 17:28:48.922326+08', '2099-12-31 08:00:00+08', 'Single', NULL, NULL, NULL, 'MasterAccount', NULL, 'Corpay', NULL, 't', '0');

INSERT INTO "public"."accountFee" ( "remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate") 
VALUES ( '', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'QuantumCardCrossBorderFeeBaseRate_Caas', '0.011', 'Percent', '2026-03-13 17:28:49.091897+08', '2099-12-31 08:00:00+08', 'Single', NULL, NULL, NULL, 'MasterAccount', NULL, 'Corpay', NULL, 't', '0');

INSERT INTO "public"."accountFee" ( "remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate") 
VALUES ( '', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'QuantumCardFxMarkupFeeRate_Caas', '0.0005', 'Percent', '2026-03-13 17:28:49.262669+08', '2099-12-31 08:00:00+08', 'Single', NULL, NULL, NULL, 'MasterAccount', NULL, 'Corpay', NULL, 't', '0');

INSERT INTO "public"."accountFee" ( "remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate") 
VALUES ( '', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'QuantumCardFxMarkupPassThroughFeeRate_Caas', '0.011', 'Percent', '2026-03-13 17:28:49.437243+08', '2099-12-31 08:00:00+08', 'Single', NULL, NULL, NULL, 'MasterAccount', NULL, 'Corpay', NULL, 't', '0');




INSERT INTO "public"."accountFee" ( "remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate") 
VALUES ('', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'QuantumCardCeramicMakeCardFee_Caas', '100', 'Count', '2024-08-01 19:48:28.63+08', '2099-01-01 00:00:00+08', 'Single', NULL, NULL, NULL, 'MasterAccount', NULL, NULL, NULL, 't', '0');