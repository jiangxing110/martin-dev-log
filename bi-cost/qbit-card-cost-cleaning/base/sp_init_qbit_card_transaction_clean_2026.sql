CREATE OR REPLACE PROCEDURE "public"."sp_init_qbit_card_transaction_clean_2026"("p_start_time" timestamp, "p_end_time" timestamp, "p_batch_interval" interval='06:00:00'::interval)
 AS $BODY$
DECLARE
    v_curr_start TIMESTAMP := p_start_time;
    v_batch_interval INTERVAL := p_batch_interval;
    v_table_name TEXT;
BEGIN
    WHILE v_curr_start < p_end_time LOOP
        v_table_name := format(
            'qbit_card_transaction_clean_2026_m%s',
            to_char(v_curr_start, 'MM')
        );

        RAISE NOTICE 'BB DWM 直写子表: %, 时间段: % 至 %',
            v_table_name, v_curr_start, v_curr_start + v_batch_interval;

        EXECUTE 'SET LOCAL synchronous_commit = off';
        EXECUTE 'SET LOCAL work_mem = ''256MB''';

        EXECUTE format($SQL$
            INSERT INTO "public".%I (
              "id", "remarks", "createTime", "updateTime", "deleteTime", "version",
              "accountId", "cardId", "currency", "status", "displayStatus", "provider",
              "settleAmount", "originalAmount", "fee", "detail", "businessType", "sourceId",
              "transactionTime", "merchantShow", "specialSourceData", "transactionId",
              "systemTraceAuditNumber", "authorizationCode", "statusLog", "comments",
              "transactionCurrency", "transactionAmount", "relatedQbitTxId", "paymentLabel",
              "platformLabel", "secondLabel", "completeTime", "released", "thirdCompleteTime",
              "id_", "isShow"
            )
            SELECT
              "id", "remarks", "createTime", "updateTime", "deleteTime", "version",
              "accountId", "cardId", "currency", "status", "displayStatus", "provider",
              "settleAmount", "originalAmount", "fee", "detail", "businessType", "sourceId",
              "transactionTime", "merchantShow", "specialSourceData", "transactionId",
              "systemTraceAuditNumber", "authorizationCode", "statusLog", "comments",
              "transactionCurrency", "transactionAmount", "relatedQbitTxId", "paymentLabel",
              "platformLabel", "secondLabel", "completeTime", "released", "thirdCompleteTime",
              "id_", "isShow"
            FROM "public"."qbitCardTransaction"
            WHERE "createTime" >= %L
              AND "createTime" < %L
            ON CONFLICT ("id", "createTime") DO NOTHING
        $SQL$, v_table_name, v_curr_start, v_curr_start + v_batch_interval);

        COMMIT;
        v_curr_start := v_curr_start + v_batch_interval;
    END LOOP;
END
$BODY$
  LANGUAGE plpgsql