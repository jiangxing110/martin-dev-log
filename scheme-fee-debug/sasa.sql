SELECT * FROM api_client_transaction 
WHERE account_id IN (SELECT account_id FROM api_account_relation WHERE root_id ='ff22382b-df2e-4a76-b92e-bc32e3b8b089') 
ORDER BY create_time DESC LIMIT 1000;

SELECT * FROM qbit_card_transaction 
WHERE "businessType"='System_Fee'
and "accountId" IN (SELECT account_id FROM api_account_relation WHERE root_id ='ff22382b-df2e-4a76-b92e-bc32e3b8b089')

SELECT * FROM qbit_card_transaction 
WHERE id in(SELECT "relatedQbitTxId" FROM qbit_card_transaction 
WHERE "businessType"='System_Fee'
and "accountId" IN (SELECT account_id FROM api_account_relation WHERE root_id ='ff22382b-df2e-4a76-b92e-bc32e3b8b089') )

SELECT * FROM "qbitCard" WHERE id in(
SELECT "cardId" FROM qbit_card_transaction 
WHERE "businessType"='System_Fee'
and "accountId" IN (SELECT account_id FROM api_account_relation WHERE root_id ='ff22382b-df2e-4a76-b92e-bc32e3b8b089') )