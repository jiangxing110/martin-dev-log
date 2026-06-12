CREATE OR REPLACE PROCEDURE "public"."sp_init_qbit_card_settlement_bb_clean_2026_V2(p_start_time timestamp, p_end_time timestamp, p_batch_interval interval)"("p_start_time" timestamp, "p_end_time" timestamp, "p_batch_interval" interval='03:00:00'::interval)
 AS $BODY$
DECLARE
    v_curr_start TIMESTAMP := p_start_time;
    v_batch_interval INTERVAL := p_batch_interval;
    v_table_name TEXT;
BEGIN
    WHILE v_curr_start < p_end_time LOOP
        v_table_name := format(
            'qbit_card_settlement_bb_clean_2026_m%s',
            to_char(v_curr_start, 'MM')
        );

        RAISE NOTICE '%',
            format(
                'BB DWM 直写子表: %s, 时间段: %s 至 %s',
                v_table_name,
                to_char(v_curr_start, 'YYYY-MM-DD HH24:MI:SS'),
                to_char(v_curr_start + v_batch_interval, 'YYYY-MM-DD HH24:MI:SS')
            );

        EXECUTE 'SET LOCAL synchronous_commit = off';
        EXECUTE 'SET LOCAL work_mem = ''256MB''';

        EXECUTE format($SQL$
            INSERT INTO "public".%I (
              "id", "remarks", "createTime", "updateTime", "deleteTime", "version",
              "cardHashId", "transactionId", "referenceNumber", "recordType", "effectiveDate",
              "batchDate", "transactionType", "transactionCode", "billingAmount",
              "billingCurrencyCode", "transactionAmount", "transactionCurrencyCode",
              "authorizationCode", "description", "cardAcceptorId", "interchangeReference",
              "visaTransactionId", "tokenRequestorId", "tokenNumber", "billingAmountRaw",
              "transactionAmountRaw", "rawData", "settlementDay", "hash", "provider",
              "settleCompleted", "qbitCardTransactionId", "compareTime", "id_",
              "statusMessage", "country", "mid", "merchantCountry", "channel", "wallet", "mcc"
            )
            SELECT
              "id", "remarks", "createTime", "updateTime", "deleteTime", "version",
              "cardHashId", "transactionId", "referenceNumber", "recordType", "effectiveDate",
              "batchDate", "transactionType", "transactionCode", "billingAmount",
              "billingCurrencyCode", "transactionAmount", "transactionCurrencyCode",
              "authorizationCode", "description", "cardAcceptorId", "interchangeReference",
              "visaTransactionId", "tokenRequestorId", "tokenNumber", "billingAmountRaw",
              "transactionAmountRaw", "rawData", "settlementDay", "hash", "provider",
              "settleCompleted", "qbitCardTransactionId", "compareTime", "id_",
              "statusMessage", "country", "mid", "merchantCountry", "channel", "wallet", "mcc"
            FROM "public"."qbitCardSettlement"
            WHERE "provider" = 'BlueBancCard'
              AND "createTime" >= %L
              AND "createTime" < %L
            ON CONFLICT ("id", "createTime") DO NOTHING
        $SQL$, v_table_name, v_curr_start, v_curr_start + v_batch_interval);

        COMMIT;
        v_curr_start := v_curr_start + v_batch_interval;
    END LOOP;
END
$BODY$
  LANGUAGE plpgsql