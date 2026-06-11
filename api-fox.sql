SELECT * FROM account_user WHERE account_id='419354504246943744'; 
SELECT * FROM account_extend WHERE account_id='419354504246943744'; 
SELECT * FROM "user" WHERE id='419354503999479808'; 
SELECT tenant_id, client_id, client_secret 
FROM tenant_customer_config 
WHERE tenant_id = 489789; 

SELECT * FROM card WHERE
account_id='419354504246943744'
ORDER BY create_time desc
