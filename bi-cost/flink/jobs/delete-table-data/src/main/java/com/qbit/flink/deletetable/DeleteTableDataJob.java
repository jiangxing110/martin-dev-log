package com.qbit.flink.deletetable;

import org.apache.flink.api.common.RuntimeExecutionMode;
import org.apache.flink.api.common.functions.RichMapFunction;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

import java.io.Serializable;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.Locale;
import java.util.regex.Pattern;

public class DeleteTableDataJob {
    private static final Pattern IDENTIFIER = Pattern.compile("[A-Za-z_][A-Za-z0-9_]*");

    public static void main(String[] args) throws Exception {
        try {
            run(args);
        } catch (Exception e) {
            System.err.println("delete-table-data failed: " + buildErrorMessage(e));
            System.err.println("received args: " + maskArgs(args));
            throw new RuntimeException("delete-table-data failed: " + buildErrorMessage(e), e);
        }
    }

    private static void run(String[] args) throws Exception {
        ParameterTool params = ParameterTool.fromArgs(args);
        DeleteConfig config = DeleteConfig.from(params);
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.setRuntimeMode(RuntimeExecutionMode.BATCH);
        env.setParallelism(1);

        env.fromElements(1)
                .map(new JdbcDeleteFunction(config))
                .name("delete-adbpg-table-data")
                .print()
                .name("print-delete-result");

        env.execute(config.jobName());
    }

    private static String buildErrorMessage(Throwable throwable) {
        Throwable current = throwable;
        while (current != null) {
            if (current.getMessage() != null && !current.getMessage().trim().isEmpty()) {
                return current.getClass().getSimpleName() + ": " + current.getMessage();
            }
            current = current.getCause();
        }
        return throwable.getClass().getSimpleName();
    }

    private static String maskArgs(String[] args) {
        String[] masked = Arrays.copyOf(args, args.length);
        for (int i = 0; i < masked.length; i++) {
            String key = masked[i].toLowerCase(Locale.ROOT);
            if ("--password".equals(key) && i + 1 < masked.length) {
                masked[i + 1] = "******";
            }
        }
        return Arrays.toString(masked);
    }

    private static final class JdbcDeleteFunction extends RichMapFunction<Integer, String> {
        private final DeleteConfig config;

        private JdbcDeleteFunction(DeleteConfig config) {
            this.config = config;
        }

        @Override
        public String map(Integer ignored) throws Exception {
            Class.forName("org.postgresql.Driver");

            try (Connection connection = DriverManager.getConnection(
                    config.jdbcUrl,
                    config.username,
                    config.password)) {
                connection.setAutoCommit(false);
                try {
                    String result = config.dryRun
                            ? countRows(connection, config)
                            : deleteRows(connection, config);
                    connection.commit();
                    return result;
                } catch (Exception e) {
                    rollbackQuietly(connection);
                    throw e;
                }
            }
        }

        private static String countRows(Connection connection, DeleteConfig config) throws SQLException {
            if (config.deleteType == DeleteType.BB_CHANNEL_FIXED_FEE_CDC) {
                return countBbChannelFixedFeeCdc(connection, config);
            }

            String sql = "SELECT COUNT(*) FROM " + config.qualifiedTableName()
                    + " WHERE " + config.dateColumn + " >= ? AND " + config.dateColumn + " < ?";

            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                bindDates(statement, config);
                try (ResultSet resultSet = statement.executeQuery()) {
                    resultSet.next();
                    long rows = resultSet.getLong(1);
                    return "Dry run matched " + rows + " rows in "
                            + config.qualifiedTableName() + " for [" + config.startDate + ", " + config.endDate + ")";
                }
            }
        }

        private static String deleteRows(Connection connection, DeleteConfig config) throws SQLException {
            if (config.deleteType == DeleteType.BB_CHANNEL_FIXED_FEE_CDC) {
                return deleteBbChannelFixedFeeCdc(connection, config);
            }

            String sql = "DELETE FROM " + config.qualifiedTableName()
                    + " WHERE " + config.dateColumn + " >= ? AND " + config.dateColumn + " < ?";

            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                bindDates(statement, config);
                int rows = statement.executeUpdate();
                return "Deleted " + rows + " rows from "
                        + config.qualifiedTableName() + " for [" + config.startDate + ", " + config.endDate + ")";
            }
        }

        private static String countBbChannelFixedFeeCdc(Connection connection, DeleteConfig config) throws SQLException {
            String sql = "WITH changed_months AS ("
                    + " SELECT DISTINCT DATE_TRUNC('month', statistics_time)::date AS report_month"
                    + " FROM ods.ods_bi_month_tag"
                    + " WHERE delete_time IS NULL"
                    + " AND tag = 'CHANNEL_COST'"
                    + " AND provider = 'BB'"
                    + " AND update_time >= CURRENT_DATE - INTERVAL '1 day'"
                    + " AND update_time < CURRENT_DATE"
                    + " AND statistics_time IS NOT NULL"
                    + ")"
                    + " SELECT COUNT(*)"
                    + " FROM dws.dws_bb_card_finance_daily_v2_p AS target"
                    + " WHERE target.special_fee_type = 'CHANNEL_FIXED_FEE'"
                    + " AND EXISTS ("
                    + " SELECT 1 FROM changed_months month_scope"
                    + " WHERE target.report_date >= month_scope.report_month"
                    + " AND target.report_date < month_scope.report_month + INTERVAL '1 month'"
                    + ")";

            try (PreparedStatement statement = connection.prepareStatement(sql);
                 ResultSet resultSet = statement.executeQuery()) {
                resultSet.next();
                return "Dry run matched " + resultSet.getLong(1)
                        + " rows for delete type " + config.deleteType.argumentValue;
            }
        }

        private static String deleteBbChannelFixedFeeCdc(Connection connection, DeleteConfig config) throws SQLException {
            String sql = "WITH changed_months AS ("
                    + " SELECT DISTINCT DATE_TRUNC('month', statistics_time)::date AS report_month"
                    + " FROM ods.ods_bi_month_tag"
                    + " WHERE delete_time IS NULL"
                    + " AND tag = 'CHANNEL_COST'"
                    + " AND provider = 'BB'"
                    + " AND update_time >= CURRENT_DATE - INTERVAL '1 day'"
                    + " AND update_time < CURRENT_DATE"
                    + " AND statistics_time IS NOT NULL"
                    + ")"
                    + " DELETE FROM dws.dws_bb_card_finance_daily_v2_p AS target"
                    + " WHERE target.special_fee_type = 'CHANNEL_FIXED_FEE'"
                    + " AND EXISTS ("
                    + " SELECT 1 FROM changed_months month_scope"
                    + " WHERE target.report_date >= month_scope.report_month"
                    + " AND target.report_date < month_scope.report_month + INTERVAL '1 month'"
                    + ")";

            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                int rows = statement.executeUpdate();
                return "Deleted " + rows + " rows for delete type " + config.deleteType.argumentValue;
            }
        }

        private static void bindDates(PreparedStatement statement, DeleteConfig config) throws SQLException {
            statement.setObject(1, config.startDate, Types.DATE);
            statement.setObject(2, config.endDate, Types.DATE);
        }

        private static void rollbackQuietly(Connection connection) {
            try {
                connection.rollback();
            } catch (SQLException ignored) {
                // Keep the original exception as the visible failure.
            }
        }
    }

    private static final class DeleteConfig implements Serializable {
        private final DeleteType deleteType;
        private final String jdbcUrl;
        private final String username;
        private final String password;
        private final String schema;
        private final String tableName;
        private final String dateColumn;
        private final LocalDate startDate;
        private final LocalDate endDate;
        private final boolean dryRun;

        private DeleteConfig(
                DeleteType deleteType,
                String jdbcUrl,
                String username,
                String password,
                String schema,
                String tableName,
                String dateColumn,
                LocalDate startDate,
                LocalDate endDate,
                boolean dryRun) {
            this.deleteType = deleteType;
            this.jdbcUrl = jdbcUrl;
            this.username = username;
            this.password = password;
            this.schema = schema;
            this.tableName = tableName;
            this.dateColumn = dateColumn;
            this.startDate = startDate;
            this.endDate = endDate;
            this.dryRun = dryRun;
        }

        private static DeleteConfig from(ParameterTool params) {
            DeleteType deleteType = DeleteType.from(params.get("delete-type", "date-range"));
            String jdbcUrl = requiredAny(params, "jdbc-url", "pg-url");
            String username = requiredAny(params, "username", "pg-user");
            String password = requiredAny(params, "password", "pg-password");
            String schema = validateIdentifier(getIdentifier(params, "schema", deleteType), "schema");
            String tableName = validateIdentifier(getIdentifier(params, "table-name", deleteType), "table-name");
            String dateColumn = validateIdentifier(params.get("date-column", "dt"), "date-column");
            LocalDate startDate = parseDate(params, "start-date", deleteType);
            LocalDate endDate = parseDate(params, "end-date", deleteType);
            boolean dryRun = Boolean.parseBoolean(params.get("dry-run", "false").toLowerCase(Locale.ROOT));

            if (deleteType == DeleteType.DATE_RANGE && (!startDate.isBefore(endDate))) {
                throw new IllegalArgumentException("start-date must be before end-date");
            }

            return new DeleteConfig(
                    deleteType,
                    jdbcUrl,
                    username,
                    password,
                    schema,
                    tableName,
                    dateColumn,
                    startDate,
                    endDate,
                    dryRun);
        }

        private String qualifiedTableName() {
            return schema + "." + tableName;
        }

        private String jobName() {
            if (deleteType == DeleteType.DATE_RANGE) {
                return "delete-table-data-" + schema + "-" + tableName + "-" + startDate + "-" + endDate;
            }
            return "delete-table-data-" + deleteType.argumentValue;
        }

        private static String required(ParameterTool params, String key) {
            String value = params.get(key);
            if (value == null || value.trim().isEmpty()) {
                throw new IllegalArgumentException("Missing required parameter --" + key);
            }
            return value.trim();
        }

        private static String requiredAny(ParameterTool params, String primaryKey, String legacyKey) {
            String value = params.get(primaryKey);
            if (value != null && !value.trim().isEmpty()) {
                return value.trim();
            }

            value = params.get(legacyKey);
            if (value != null && !value.trim().isEmpty()) {
                return value.trim();
            }

            throw new IllegalArgumentException(
                    "Missing required parameter --" + primaryKey + " or --" + legacyKey);
        }

        private static String validateIdentifier(String value, String key) {
            if (!IDENTIFIER.matcher(value).matches()) {
                throw new IllegalArgumentException("--" + key + " is not a valid SQL identifier: " + value);
            }
            return value;
        }

        private static String getIdentifier(ParameterTool params, String key, DeleteType deleteType) {
            String value = params.get(key);
            if (value != null && !value.trim().isEmpty()) {
                return value.trim();
            }
            if ("schema".equals(key) && deleteType.defaultSchema != null) {
                return deleteType.defaultSchema;
            }
            if ("table-name".equals(key) && deleteType.defaultTableName != null) {
                return deleteType.defaultTableName;
            }
            return required(params, key);
        }

        private static LocalDate parseDate(ParameterTool params, String key, DeleteType deleteType) {
            String value = params.get(key);
            if (value == null || value.trim().isEmpty()) {
                if (deleteType == DeleteType.DATE_RANGE) {
                    return LocalDate.parse(required(params, key));
                }
                return LocalDate.now();
            }
            return LocalDate.parse(value.trim());
        }
    }

    private enum DeleteType {
        DATE_RANGE("date-range", null, null),
        BB_CHANNEL_FIXED_FEE_CDC(
                "bb-channel-fixed-fee-cdc",
                "dws",
                "dws_bb_card_finance_daily_v2_p");

        private final String argumentValue;
        private final String defaultSchema;
        private final String defaultTableName;

        DeleteType(String argumentValue, String defaultSchema, String defaultTableName) {
            this.argumentValue = argumentValue;
            this.defaultSchema = defaultSchema;
            this.defaultTableName = defaultTableName;
        }

        private static DeleteType from(String value) {
            for (DeleteType deleteType : values()) {
                if (deleteType.argumentValue.equals(value)) {
                    return deleteType;
                }
            }
            throw new IllegalArgumentException("Unsupported --delete-type: " + value);
        }
    }
}
