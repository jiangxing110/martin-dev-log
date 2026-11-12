-- 月结默认费率修复：仅处理 Excel 标黄的标注。
-- 数字标注：只更新原记录的 rate；“补一条”标注：复制对应默认行并新增 provider 行。
-- 新增记录保留源行的 accountId、费率类型、有效期、阶梯边界等配置。
--
-- 注意：Excel 中两条新增费率写的是 provider “IQ”，脚本按字面值 IQ 写入。
-- 若 IQ 实际是 I2c 的笔误，请先把下面两个 'IQ' 改成 'I2c' 再执行。

BEGIN;

-- 一、黄标数字：只按记录 ID 更新 rate，保留其他字段不变。
-- feeType=MonthlyActiveCardFee_Caas；修复前 rate=0；修复后 rate=0.25；provider=NULL（默认行）
UPDATE public."accountFee"
SET rate = 0.25, "updateTime" = NOW()
WHERE id = 'c117a2e9-5cf8-49e9-878a-a04210716313';

-- feeType=OpenCard_Caas；修复前 rate=0.8；修复后 rate=0；provider=QbitIssuing
UPDATE public."accountFee"
SET rate = 0, "updateTime" = NOW()
WHERE id = '5173185e-b4e5-4c27-bdd1-0b783fafa06e';

-- feeType=QuantumCardATMFee_Caas；修复前 rate=0；修复后 rate=0.02；provider=NULL（默认行）
UPDATE public."accountFee"
SET rate = 0.02, "updateTime" = NOW()
WHERE id = 'e15ebc1d-4443-4470-81cc-a831f8138285';

-- feeType=QuantumCardApplePayFee_Caas；修复前 rate=0；修复后 rate=0.002；provider=NULL（默认行）
UPDATE public."accountFee"
SET rate = 0.002, "updateTime" = NOW()
WHERE id = '44ec2470-ef1e-42e6-8803-04f5b6997cb7';

-- feeType=QuantumCardAuthorizationFeeByDomestic_Caas；修复前 rate=0；修复后 rate=0.15；provider=NULL（默认行）
UPDATE public."accountFee"
SET rate = 0.15, "updateTime" = NOW()
WHERE id = 'be319ce6-6113-4e5a-ab21-9fe1011c6b8e';

-- feeType=QuantumCardAuthorizationFeeByInternational_Caas；修复前 rate=0；修复后 rate=0.15；provider=NULL（默认行）
UPDATE public."accountFee"
SET rate = 0.15, "updateTime" = NOW()
WHERE id = '86b31f3d-7e2e-486c-986e-dd0270e576c4';

-- feeType=QuantumCardCrossBorderFeeBaseRate_Caas；修复前 rate=0；修复后 rate=0.0135；provider=NULL（默认行）
UPDATE public."accountFee"
SET rate = 0.0135, "updateTime" = NOW()
WHERE id = 'ed5f7865-28b1-4e6e-8d44-d38781d4851e';

-- feeType=QuantumCardFxMarkupFeeRate_Caas；修复前 rate=0；修复后 rate=0.005；provider=NULL（默认行）
UPDATE public."accountFee"
SET rate = 0.005, "updateTime" = NOW()
WHERE id = '1e2bca8a-ffdd-4cd0-a6a7-61b9312fb183';

-- feeType=QuantumCardFxMarkupPassThroughFeeRate_Caas；修复前 rate=0；修复后 rate=0.0135；provider=NULL（默认行）
UPDATE public."accountFee"
SET rate = 0.0135, "updateTime" = NOW()
WHERE id = 'd7a81d94-2e7b-418d-ad93-e95f6b00af20';

-- feeType=QuantumCardMarkUpFeePercentage_Caas；修复前 rate=0.01；修复后 rate=0.005；provider=NULL（默认行）
UPDATE public."accountFee"
SET rate = 0.005, "updateTime" = NOW()
WHERE id = 'b417462a-3855-4bed-99b3-40e1cc56febf';

-- feeType=QuantumCardSettlementFeeDom_Caas；修复前 rate=0；修复后 rate=0.2；provider=NULL（默认行）
UPDATE public."accountFee"
SET rate = 0.2, "updateTime" = NOW()
WHERE id = 'd3f6b413-30fb-4d85-81b1-0e36e8069a23';

-- feeType=QuantumCardSettlementFeeInt_Caas；修复前 rate=0；修复后 rate=0.3；provider=NULL（默认行）
UPDATE public."accountFee"
SET rate = 0.3, "updateTime" = NOW()
WHERE id = 'd5fe6574-aee8-4acc-9dae-66e68a2fcfdd';

-- 二、“补一条”标注：以当前默认行作模板，新增对应渠道配置。
-- 若同账户、费用类型、渠道、字段和有效期的活动行已存在，则跳过，避免重复插入。

-- feeType=QuantumCardATMFee_Caas；修复前 rate=0（复制默认行）；修复后 rate=0.02；provider=I2c（新增行）
INSERT INTO public."accountFee" (
    id, remarks, "createTime", "updateTime", "deleteTime", version,
    "accountId", "feeType", rate, "collectionRate", "mathType", "childFeeType",
    "startTime", "endTime", type, low, high, threshold, raw,
    provider, "providerField", enable
)
SELECT
    uuid_generate_v4(), src.remarks, src."createTime", src."updateTime", NULL, 1,
    src."accountId", src."feeType", 0.02, src."collectionRate", src."mathType", src."childFeeType",
    src."startTime", src."endTime", src.type, src.low, src.high, src.threshold, src.raw,
    'I2c', src."providerField", src.enable
FROM public."accountFee" src
WHERE src.id = 'e15ebc1d-4443-4470-81cc-a831f8138285'
  AND NOT EXISTS (
      SELECT 1 FROM public."accountFee" dst
      WHERE dst."accountId" = src."accountId"
        AND dst."feeType" = src."feeType"
        AND dst.provider = 'I2c'
        AND dst."providerField" IS NOT DISTINCT FROM src."providerField"
        AND dst."startTime" = src."startTime"
        AND dst."endTime" = src."endTime"
        AND dst."deleteTime" IS NULL
  );

-- feeType=QuantumCardApplePayFee_Caas；修复前 rate=0（复制默认行）；修复后 rate=0.002；provider=I2c（新增行）
INSERT INTO public."accountFee" (
    id, remarks, "createTime", "updateTime", "deleteTime", version,
    "accountId", "feeType", rate, "collectionRate", "mathType", "childFeeType",
    "startTime", "endTime", type, low, high, threshold, raw,
    provider, "providerField", enable
)
SELECT
    uuid_generate_v4(), src.remarks, src."createTime", src."updateTime", NULL, 1,
    src."accountId", src."feeType", 0.002, src."collectionRate", src."mathType", src."childFeeType",
    src."startTime", src."endTime", src.type, src.low, src.high, src.threshold, src.raw,
    'I2c', src."providerField", src.enable
FROM public."accountFee" src
WHERE src.id = '44ec2470-ef1e-42e6-8803-04f5b6997cb7'
  AND NOT EXISTS (
      SELECT 1 FROM public."accountFee" dst
      WHERE dst."accountId" = src."accountId"
        AND dst."feeType" = src."feeType"
        AND dst.provider = 'I2c'
        AND dst."providerField" IS NOT DISTINCT FROM src."providerField"
        AND dst."startTime" = src."startTime"
        AND dst."endTime" = src."endTime"
        AND dst."deleteTime" IS NULL
  );

-- feeType=QuantumCardAuthorizationFeeByDomestic_Caas；修复前 rate=0（复制默认行）；修复后 rate=0；provider=IQ（新增行）
INSERT INTO public."accountFee" (
    id, remarks, "createTime", "updateTime", "deleteTime", version,
    "accountId", "feeType", rate, "collectionRate", "mathType", "childFeeType",
    "startTime", "endTime", type, low, high, threshold, raw,
    provider, "providerField", enable
)
SELECT
    uuid_generate_v4(), src.remarks, src."createTime", src."updateTime", NULL, 1,
    src."accountId", src."feeType", 0, src."collectionRate", src."mathType", src."childFeeType",
    src."startTime", src."endTime", src.type, src.low, src.high, src.threshold, src.raw,
    'IQ', src."providerField", src.enable
FROM public."accountFee" src
WHERE src.id = 'be319ce6-6113-4e5a-ab21-9fe1011c6b8e'
  AND NOT EXISTS (
      SELECT 1 FROM public."accountFee" dst
      WHERE dst."accountId" = src."accountId"
        AND dst."feeType" = src."feeType"
        AND dst.provider = 'IQ'
        AND dst."providerField" IS NOT DISTINCT FROM src."providerField"
        AND dst."startTime" = src."startTime"
        AND dst."endTime" = src."endTime"
        AND dst."deleteTime" IS NULL
  );

-- feeType=QuantumCardAuthorizationFeeByInternational_Caas；修复前 rate=0（复制默认行）；修复后 rate=0；provider=IQ（新增行）
INSERT INTO public."accountFee" (
    id, remarks, "createTime", "updateTime", "deleteTime", version,
    "accountId", "feeType", rate, "collectionRate", "mathType", "childFeeType",
    "startTime", "endTime", type, low, high, threshold, raw,
    provider, "providerField", enable
)
SELECT
    uuid_generate_v4(), src.remarks, src."createTime", src."updateTime", NULL, 1,
    src."accountId", src."feeType", 0, src."collectionRate", src."mathType", src."childFeeType",
    src."startTime", src."endTime", src.type, src.low, src.high, src.threshold, src.raw,
    'IQ', src."providerField", src.enable
FROM public."accountFee" src
WHERE src.id = '86b31f3d-7e2e-486c-986e-dd0270e576c4'
  AND NOT EXISTS (
      SELECT 1 FROM public."accountFee" dst
      WHERE dst."accountId" = src."accountId"
        AND dst."feeType" = src."feeType"
        AND dst.provider = 'IQ'
        AND dst."providerField" IS NOT DISTINCT FROM src."providerField"
        AND dst."startTime" = src."startTime"
        AND dst."endTime" = src."endTime"
        AND dst."deleteTime" IS NULL
  );

-- feeType=QuantumCardMetalMakeCardFee_Caas；修复前 rate=48（复制默认行）；修复后 rate=48；provider=I2c（新增行）
INSERT INTO public."accountFee" (
    id, remarks, "createTime", "updateTime", "deleteTime", version,
    "accountId", "feeType", rate, "collectionRate", "mathType", "childFeeType",
    "startTime", "endTime", type, low, high, threshold, raw,
    provider, "providerField", enable
)
SELECT
    uuid_generate_v4(), src.remarks, src."createTime", src."updateTime", NULL, 1,
    src."accountId", src."feeType", 48, src."collectionRate", src."mathType", src."childFeeType",
    src."startTime", src."endTime", src.type, src.low, src.high, src.threshold, src.raw,
    'I2c', src."providerField", src.enable
FROM public."accountFee" src
WHERE src.id = '3a043b7e-b6e9-49f9-9276-2d2e31478a49'
  AND NOT EXISTS (
      SELECT 1 FROM public."accountFee" dst
      WHERE dst."accountId" = src."accountId"
        AND dst."feeType" = src."feeType"
        AND dst.provider = 'I2c'
        AND dst."providerField" IS NOT DISTINCT FROM src."providerField"
        AND dst."startTime" = src."startTime"
        AND dst."endTime" = src."endTime"
        AND dst."deleteTime" IS NULL
  );

-- feeType=QuantumCardSettlementFeeDomRate_Caas；修复前 rate=0.02（复制默认行）；修复后 rate=0；provider=BlueBanc（新增行；Excel 注记 BB）
INSERT INTO public."accountFee" (
    id, remarks, "createTime", "updateTime", "deleteTime", version,
    "accountId", "feeType", rate, "collectionRate", "mathType", "childFeeType",
    "startTime", "endTime", type, low, high, threshold, raw,
    provider, "providerField", enable
)
SELECT
    uuid_generate_v4(), src.remarks, src."createTime", src."updateTime", NULL, 1,
    src."accountId", src."feeType", 0, src."collectionRate", src."mathType", src."childFeeType",
    src."startTime", src."endTime", src.type, src.low, src.high, src.threshold, src.raw,
    'BlueBanc', src."providerField", src.enable
FROM public."accountFee" src
WHERE src.id = '73acba4b-2330-4891-8538-1577692ef637'
  AND NOT EXISTS (
      SELECT 1 FROM public."accountFee" dst
      WHERE dst."accountId" = src."accountId"
        AND dst."feeType" = src."feeType"
        AND dst.provider = 'BlueBanc'
        AND dst."providerField" IS NOT DISTINCT FROM src."providerField"
        AND dst."startTime" = src."startTime"
        AND dst."endTime" = src."endTime"
        AND dst."deleteTime" IS NULL
  );

-- feeType=QuantumCardSettlementFeeIntRate_Caas；修复前 rate=0.02（复制默认行）；修复后 rate=0；provider=BlueBanc（新增行；Excel 注记 BB）
INSERT INTO public."accountFee" (
    id, remarks, "createTime", "updateTime", "deleteTime", version,
    "accountId", "feeType", rate, "collectionRate", "mathType", "childFeeType",
    "startTime", "endTime", type, low, high, threshold, raw,
    provider, "providerField", enable
)
SELECT
    uuid_generate_v4(), src.remarks, src."createTime", src."updateTime", NULL, 1,
    src."accountId", src."feeType", 0, src."collectionRate", src."mathType", src."childFeeType",
    src."startTime", src."endTime", src.type, src.low, src.high, src.threshold, src.raw,
    'BlueBanc', src."providerField", src.enable
FROM public."accountFee" src
WHERE src.id = '0741f6db-c989-4c05-bcca-3d928e87724e'
  AND NOT EXISTS (
      SELECT 1 FROM public."accountFee" dst
      WHERE dst."accountId" = src."accountId"
        AND dst."feeType" = src."feeType"
        AND dst.provider = 'BlueBanc'
        AND dst."providerField" IS NOT DISTINCT FROM src."providerField"
        AND dst."startTime" = src."startTime"
        AND dst."endTime" = src."endTime"
        AND dst."deleteTime" IS NULL
  );

-- feeType=所有 *_Caas；修复前后 rate 不变；provider=全部；createTime 改为 startTime（startTime=2026-02-01 00:00:00+08）
UPDATE public."accountFee"
SET "createTime" = "startTime"
WHERE "accountId" = '00000000-0000-0000-0000-000000000000'
  AND RIGHT("feeType", 5) = '_Caas'
  AND "startTime" = TIMESTAMPTZ '2026-02-01 00:00:00+08'
  AND "deleteTime" IS NULL;

-- feeType=所有 *_Caas；修复前后 rate 不变；provider=全部；createTime 改为 startTime（startTime=2026-03-20 00:00:00+08）
UPDATE public."accountFee"
SET "createTime" = "startTime"
WHERE "accountId" = '00000000-0000-0000-0000-000000000000'
  AND RIGHT("feeType", 5) = '_Caas'
  AND "startTime" = TIMESTAMPTZ '2026-03-20 00:00:00+08'
  AND "deleteTime" IS NULL;

COMMIT;
