WITH target_accounts(account_id) AS (
  VALUES
    ('a54fda9d-cce8-4525-b153-dbc0f45a0c6c'::uuid),
    ('9a6e4d51-d5cf-471f-8c13-9922c1213638'::uuid),
    ('80be1f90-8f3a-4014-875a-6f71ea40551e'::uuid),
    ('b04da43a-0be5-44ae-a5c2-b8e8fdbeecd7'::uuid),
    ('e6f7db49-c103-455e-930a-acdc22f64889'::uuid),
    ('4a3bb457-d294-4ddd-8f1c-bde22b59d3fb'::uuid),
    ('ff22382b-df2e-4a76-b92e-bc32e3b8b089'::uuid),
    ('e83b6e59-cd6b-4f77-9c0e-388ec2486bc4'::uuid),
    ('f67cd913-4d76-47bf-b6f6-02c7531a2a69'::uuid),
    ('2e48629c-9216-4841-8d38-6594e3975251'::uuid)
), changes AS (
  SELECT
    l."recordId" AS account_id,
    l."createTime" AS change_time,
    l.data->'params'->'operationContent'->>'statementType' AS statement_type,
    LEAD(l."createTime") OVER (
      PARTITION BY l."recordId" ORDER BY l."createTime"
    ) AS next_change_time
  FROM public."operationLog" l
  JOIN target_accounts t ON l."recordId" = t.account_id::text
  WHERE l."operationAccountType" = 'ApiClient'
    AND l."businessType" = 'OpenApiAdmin'
    AND l."deleteTime" IS NULL
    AND l.data->>'operationType' IN (
      'OPEN_API_CLIENT_CREATION', 'UPDATE_CONFIG', 'UPDATE_DISCOUNT_CONFIG'
    )
    AND l.data->'params'->'operationContent'->>'statementType' IS NOT NULL
)
SELECT
  account_id,
  change_time AS monthly_start_time,
  next_change_time AS monthly_end_time
FROM changes
WHERE statement_type = 'Monthly'
ORDER BY monthly_start_time, account_id;