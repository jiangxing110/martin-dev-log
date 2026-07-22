
UPDATE "accountFee"
SET
  "endTime" = TIMESTAMPTZ '2026-08-01 00:00:00+08',
  "updateTime" = TIMESTAMPTZ '2026-08-01 00:00:00+08'
WHERE "deleteTime" IS NULL
  AND "feeType" IN ('VisaRiskManagerInt_Caas', 'VisaRiskManagerInt');

INSERT INTO "accountFee" (
  "accountId","feeType","rate","collectionRate","mathType","childFeeType",
  "startTime","endTime","type","low","high","threshold","raw",
  "provider","providerField","enable","remarks","createTime","updateTime","version"
)
SELECT
  "accountId",
  "feeType",
  0.09,
  "collectionRate",
  "mathType",
  "childFeeType",
  TIMESTAMPTZ '2026-08-01 00:00:00+08',
  TIMESTAMPTZ '2099-11-28 23:59:59+08',
  "type",
  "low",
  "high",
  "threshold",
  "raw",
  "provider",
  "providerField",
  "enable",
  "remarks",
  NOW(),
  NOW(),
  1
FROM "accountFee"
WHERE "deleteTime" IS NULL
  AND "feeType" IN ('VisaRiskManagerInt_Caas', 'VisaRiskManagerInt')
  AND "endTime" = TIMESTAMPTZ '2026-08-01 00:00:00+08';