ALTER TABLE "api_client_bill_statement"
ADD COLUMN IF NOT EXISTS "statics_amount" NUMERIC(18, 2);

