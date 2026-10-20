-- 仅在生产环境数据库执行：VIP 近三个月卡净消费门槛为 1,000,000。
INSERT INTO "systemConfig" ("key", "value", "type", "status", "visibleToUser", "version", "createTime", "updateTime")
SELECT 'vip_net_consumption_threshold', '1000000', 'string', 'Active', false, 1, now(), now()
WHERE NOT EXISTS (
    SELECT 1 FROM "systemConfig"
    WHERE "key" = 'vip_net_consumption_threshold' AND "status" = 'Active'
);
