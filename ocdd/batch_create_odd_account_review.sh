#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-https://global.service.test.qbitnetwork.com/graphql}"
IDS_FILE="${IDS_FILE:-account_ids.txt}"
DELAY_SECONDS="${DELAY_SECONDS:-0.2}"
FINGERPRINT="${FINGERPRINT:-901aaab3ea524de187e73c7c1ed9d966}"

if [[ -z "${OCDD_TOKEN:-}" ]]; then
  echo "Missing OCDD_TOKEN. Example:"
  echo "  export OCDD_TOKEN='your bearer token'"
  exit 1
fi

if [[ ! -f "$IDS_FILE" ]]; then
  echo "IDs file not found: $IDS_FILE"
  exit 1
fi

mkdir -p logs
SUCCESS_LOG="logs/success.log"
FAILED_LOG="logs/failed.log"
RESPONSE_LOG="logs/responses.jsonl"

: > "$SUCCESS_LOG"
: > "$FAILED_LOG"
: > "$RESPONSE_LOG"

QUERY='mutation createOddAccountReview($data: CreateOddAccountReviewInput!) { createOddAccountReview(data: $data) }'

total=0
success=0
failed=0

while IFS= read -r account_id || [[ -n "$account_id" ]]; do
  account_id="$(printf '%s' "$account_id" | tr -d '[:space:]')"

  if [[ -z "$account_id" || "$account_id" == \#* ]]; then
    continue
  fi

  total=$((total + 1))
  payload="$(printf '{"query":"%s","variables":{"data":{"accountId":"%s"}}}' "$QUERY" "$account_id")"

  tmp_body="$(mktemp)"
  http_code="$(
    curl --silent --show-error --location "$API_URL" \
      --header 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
      --header 'Origin: https://test-admin-v3.qbitnetwork.com' \
      --header 'Referer: https://test-admin-v3.qbitnetwork.com/' \
      --header 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36' \
      --header 'accept: */*' \
      --header "authorization: Bearer $OCDD_TOKEN" \
      --header 'content-type: application/json' \
      --header "fingerprint: $FINGERPRINT" \
      --data "$payload" \
      --output "$tmp_body" \
      --write-out '%{http_code}'
  )"

  response="$(cat "$tmp_body")"
  rm -f "$tmp_body"
  printf '{"accountId":"%s","httpCode":"%s","response":%s}\n' "$account_id" "$http_code" "$response" >> "$RESPONSE_LOG"

  if [[ "$http_code" == "200" ]] && ! printf '%s' "$response" | grep -q '"errors"'; then
    success=$((success + 1))
    echo "$account_id" >> "$SUCCESS_LOG"
    printf '[OK]   %s\n' "$account_id"
  else
    failed=$((failed + 1))
    printf '%s\t%s\t%s\n' "$account_id" "$http_code" "$response" >> "$FAILED_LOG"
    printf '[FAIL] %s http=%s\n' "$account_id" "$http_code"
  fi

  sleep "$DELAY_SECONDS"
done < "$IDS_FILE"

echo
echo "Done. total=$total success=$success failed=$failed"
echo "Success log: $SUCCESS_LOG"
echo "Failed log:  $FAILED_LOG"
echo "Responses:   $RESPONSE_LOG"
