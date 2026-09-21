-- 直客账单每月合并结算规则调整通知模板。
-- 先删除同名旧模板，再插入最新的中英文模板。
DELETE FROM "public"."noticeTemplateV2"
WHERE "templateName" = 'DIRECT_CUSTOMER_BILLING_SETTLEMENT_NOTICE';

INSERT INTO "public"."noticeTemplateV2"
    ("id", "remarks", "createTime", "updateTime", "deleteTime", "version", "templates",
     "label", "templateParams", "templateName", "node")
VALUES
    (gen_random_uuid(),
     '直客账单结算规则调整通知（每月20日合并结算）',
     now(), now(), NULL, 1,
     $$
     {
       "emails": [
         {
           "email": {
             "text": "尊敬的客户 <%verifiedName%>：\n\n为让您的月度账单更清晰、资金核对更省心，Qbit 将对账单结算规则进行调整，自【2026年10月生成9月份账单时】开始正式实施。核心变化是：月度返现和月度账单不再分别入账或扣款，统一改为每月20日合并结算（当月返现与费用相互抵扣，只结算差额部分）。\n\n【规则对比】\n每月3日：原规则生成返现账单，金额即时入账；新规则生成返现账单，暂不入账。\n每月18日：原规则生成费用账单，金额即时扣款；新规则生成费用账单，暂不扣款。\n每月20日：原规则无此流程；新规则系统自动合并当月返现与费用，结算差额。\n\n【结算逻辑】\n- 当月返现大于费用：差额自动发放至您的账户。\n- 当月返现小于费用：差额自动从您的账户扣除。\n\n【调整说明】\n- 返现标准、收费标准、账单核算逻辑均保持不变，不影响您的实际权益。\n- 本次调整仅优化结算时效与方式，月度收支合并为一笔，账单更直观。\n- 每月3日和18日生成的账单仍可正常查询和下载，便于核对明细。\n\n如有疑问，欢迎随时联系您的客户经理或客服。感谢您的理解与支持。",
             "allow": true,
             "tenant": false,
             "template": "customUniteNotice",
             "topicName": "[<%emailPrefix%>]账单结算规则调整通知（每月20日合并结算）"
           },
           "language": "zh"
         },
         {
           "email": {
             "text": "Dear Customer,\n\nTo make your monthly statements clearer and account reconciliation easier, Qbit is updating its billing settlement process. The update will take effect from the September 2026 billing cycle, processed in October 2026. Monthly rebates and statements will no longer be credited or deducted separately. Instead, they will be combined and settled on the 20th of each month, with only the net difference settled.\n\nComparison of Current and Updated Process\n3rd of each month: Current process — the rebate is generated and credited immediately. Updated process — the rebate is generated but not credited immediately.\n18th of each month: Current process — the monthly statement is generated and deducted immediately. Updated process — the monthly statement is generated but not deducted immediately.\n20th of each month: Current process — N/A. Updated process — the system calculates and settles the net amount between the monthly statement and rebate.\n\nNet Settlement\n- If the rebate amount exceeds the monthly statement amount, the difference will be automatically credited to your account.\n- If the monthly statement amount exceeds the rebate amount, the difference will be automatically deducted from your account.\n\nWhat Remains Unchanged\n- Rebate rates, fee rates, and billing calculations remain unchanged and your actual benefits will not be affected.\n- This update only changes the settlement timing and method by consolidating monthly rebates and fees into a single net settlement.\n- The rebate and monthly statement generated on the 3rd and 18th of each month will remain available for viewing and download.\n\nIf you have any questions, please contact your account manager or our Customer Support team.\n\nThank you for your understanding and continued support.",
             "allow": true,
             "tenant": false,
             "template": "customUniteNotice",
             "topicName": "[<%emailPrefix%>]Notice of Changes to Monthly Billing and Settlement – Net Settlement on the 20th"
           },
           "language": "en"
         }
       ],
       "sockets": [],
       "qbitNotices": [],
       "adminSockets": [],
       "feiShuRobots": [],
       "earmarkEmails": []
     }
     $$,
     '直客账单结算规则调整通知',
     '[{"name":"verifiedName","type":"string","remarks":"账户名称","require":false},{"name":"emailPrefix","type":"string","remarks":"邮件标题前缀","require":false},{"name":"qbitUrl","type":"string","remarks":"Qbit帮助中心链接","require":false},{"name":"interlaceUrl","type":"string","remarks":"Interlace帮助中心链接","require":false}]',
     'DIRECT_CUSTOMER_BILLING_SETTLEMENT_NOTICE',
     'java');
