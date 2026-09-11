#!/usr/bin/env bash
set -eu

base_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ddl="$base_dir/table-scripts/dim_account_analysis.sql"
cdc="$base_dir/cdc/dim_online_account_analysis-cdc-sql.sql"
batch="$base_dir/batch/dim_online_account_analysis-batch-sql.sql"

grep -q '"display_id" varchar' "$ddl"
grep -q '"display_id" IS' "$ddl"
grep -q '`displayId`.*STRING' "$cdc"
grep -q 'a.`displayId` AS display_id' "$cdc"
grep -q 'display_id[[:space:]]*STRING' "$cdc"
grep -q 'display_id[[:space:]]*STRING' "$batch"
grep -q 'display_id' "$batch"
test -f "$base_dir/table-scripts/alter_dim_account_analysis_add_display_id.sql"
grep -q 'ADD COLUMN IF NOT EXISTS.*display_id' "$base_dir/table-scripts/alter_dim_account_analysis_add_display_id.sql"
test -f "$base_dir/table-scripts/backfill_dim_account_analysis_api_fields.sql"
grep -q 'IS DISTINCT FROM' "$base_dir/table-scripts/backfill_dim_account_analysis_api_fields.sql"
grep -q 'caas_open_api_extend' "$base_dir/table-scripts/backfill_dim_account_analysis_api_fields.sql"
test -f "$base_dir/table-scripts/backfill_dim_account_analysis_display_id.sql"
grep -q 'a\.\"displayId\"' "$base_dir/table-scripts/backfill_dim_account_analysis_display_id.sql"
grep -q 'IS DISTINCT FROM' "$base_dir/table-scripts/backfill_dim_account_analysis_display_id.sql"
