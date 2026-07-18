SELECT aar.root_id,count(*)
FROM "qbitCardTransaction" as tr
LEFT JOIN api_account_relation as aar ON tr."accountId"=aar.account_id
LEFT JOIN "accountExtend" as ae ON ae."accountId"=aar.root_id
WHERE 
tr."transactionTime" >'2026-05-26 00:00:00'
and tr."transactionTime" <'2026-05-27 00:00:00'
and aar.relation_type='api'
and ae.access_type='Gateway'
GROUP BY aar.root_id


SELECT tr.*
FROM "qbitCardTransaction" as tr
LEFT JOIN api_account_relation as aar ON tr."accountId"=aar.account_id
LEFT JOIN "accountExtend" as ae ON ae."accountId"=aar.root_id
WHERE 
tr."transactionTime" >'2026-05-26 00:00:00'
and tr."transactionTime" <'2026-05-27 00:00:00'
and aar.relation_type='api'
and aar.root_id='046a8fc4-fa68-4746-a6e2-db2d82a1fcc5'
and ae.access_type='Gateway'

