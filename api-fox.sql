SELECT * FROM "openApiClient" WHERE "clientId"='interlace30d3685ec81f9270'
SELECT * FROM account_card_bin_permission WHERE card_bin_id='1987713856125325316'

SELECT * FROM card_bin WHERE id='1987713856125325316'

SELECT * FROM "openApiClientConfig" WHERE "clientId"='c2ac76e6-016a-4925-a125-6bfb26e54a07'

SELECT * FROM "qbitCard" WHERE id='7306e36e-afa5-4aa7-9fe2-183e402637c3'

SELECT * FROM balance WHERE "accountId"='de758323-5263-4312-98d7-df47a1f1e8df'

SELECT * FROM account WHERE "id"='de758323-5263-4312-98d7-df47a1f1e8df'

SELECT * FROM account WHERE "id"='c2ac76e6-016a-4925-a125-6bfb26e54a07'

SELECT * FROM "qbitCardWalletTransaction" WHERE "accountId"='de758323-5263-4312-98d7-df47a1f1e8df'

---------------------------------------------------------------------------------------------------------------------
SELECT * FROM account_user WHERE account_id='419354504246943744';
SELECT * FROM account_extend WHERE account_id='419354504246943744';
SELECT * FROM "user" WHERE id='419354503999479808';


SELECT tenant_id, client_id, client_secret
FROM tenant_customer_config
WHERE tenant_id = 489789;

SELECT * FROM card WHERE account_id='419354504246943744';

ORDER BY create_time desc
