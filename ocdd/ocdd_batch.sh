#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-https://global.service.test.qbitnetwork.com/graphql}"
DELAY_SECONDS="${DELAY_SECONDS:-0.2}"
FINGERPRINT="${FINGERPRINT:-901aaab3ea524de187e73c7c1ed9d966}"

if [[ -z "${OCDD_TOKEN:-}" ]]; then
  echo "Missing OCDD_TOKEN. Example:"
  echo "  export OCDD_TOKEN='your bearer token'"
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
done <<'ACCOUNT_IDS'
4bcd38ec-8e5f-448d-8450-226930d09167
75fd1dc0-da4b-4184-96ec-a550c0bdc5c4
408d0f80-bdfb-4547-bd4d-0c6919d0809d
2e588f0f-1e4d-42d7-babd-9463fc83fa2c
566e0fa8-e756-4b35-a8cf-8cd4a0a86a3b
a2f83c84-8f8e-44db-830f-4bd50af9ab4a
72b2afe1-9455-4141-a86f-7260df3c9a2b
8a7d3ff1-c30d-49a1-98c2-371f06287102
b7b96818-9799-41c4-a277-6bb72af1d8da
9fd733f7-ee74-4e16-9f83-225b7cbf8878
27b770ec-37a5-44ce-9810-6d6a40ef69d9
9ad9adc3-7e81-4bbc-acc8-fdc2eb616285
d51b0a83-dc28-47b6-990d-62afeb2f572e
7add4e20-4e47-4fab-965f-d8da48b99684
a9f80eea-0d45-4c86-9f04-5c19592804c0
538f0457-b8b7-4926-b149-b1644c16e4d1
60dac923-cc24-4a52-a8ea-90d04e5e3a99
746322df-38c8-49dd-a44b-59ceb4791b47
fc5dba20-a3e2-452e-909f-1dbbe86c9e12
f327d27e-71aa-4496-b037-98018f1cf40c
6408d002-df29-4d04-a929-1695a4712f2f
ffc17066-d9a9-406c-adb8-f09bac6a8156
fa4a82fe-5d02-4b95-b353-560a87dc110d
a69a6f8b-fb6c-4311-bd8e-3335bbe6cd90
88227e9e-741d-4fdc-92dc-5a6b956d4670
89a6b099-4968-4feb-b48b-8c58b18ff244
6ec7cc5b-3f3c-4573-b987-3e82669be31b
0cff9a11-d8ad-47e5-900e-1b23cb5a50e0
5de14004-58b6-4eff-94dd-8013e434dd16
f775d844-2d33-4add-9da9-1764450ebf9d
5d9ce095-71a5-43e8-a8f6-ec73362da542
71ec5f03-0fdc-4ca9-9f2f-4a743924a7cd
c870a5c0-5bdd-4710-b086-68dd9c0cb7a7
96239881-bdab-44fc-9658-ca0efeb6dc85
0c6fdfbd-81e4-4786-9419-5228cdceed45
1ec26af2-6a78-40da-9b9f-9001fa26529b
478a6e94-f5d6-4d84-8429-efb2111e5099
fde7d48e-ebef-49e5-9bcb-fea2b102e3ff
9941d52a-6f4b-478e-9fc1-193a15d8aeb9
0b799412-d327-4120-a228-9d94370a183e
66bedcdb-596e-4d45-8174-41eccc8c9023
cfb1a649-f6c8-4845-8a2b-3a02a4eaa6a4
7a5b93fc-cce4-46a0-b1b2-f20265255142
9f08db5e-92a0-4ede-b63d-75b398c5b7c5
8e9b5f73-f7de-48fa-9bd9-51ceeeed9157
0e8b39ca-4275-4cf6-86f0-70942d598431
4a4849e7-88e4-44ff-8db3-769d95c181dd
bb113364-99d0-4abd-bdfd-b01eae78af04
221b2bc8-b06b-4ba0-b783-c79f116faa64
ea0608b1-4c93-4627-a8e2-f1be5ec831e4
59985f92-6016-4388-8e00-e2de36d22b11
4c7292e5-8c0d-463a-8241-e520613db19a
a41f17e5-f212-4380-8d18-2e0b570a59fa
b98bb025-bc74-4928-9bfb-1af1faa4c7e8
96ff9032-9509-465c-bd3f-e01e17ed1cae
4984bc20-cffd-4c70-bb6c-9d0eeded6908
e9824dcf-b4d2-4c45-94c5-e039f97c077b
b8302a54-f6b2-4661-81c5-6cbb01d25a32
54d9f09f-7345-469f-bc49-2e8a61813419
f5ba02f4-a493-4bf3-912b-43e6ce6833d0
63e9b8ad-965e-45a5-bc18-147f5d850bd2
a1f34310-1873-44ef-abea-7d461ec07f99
4a3fc350-b6fa-4c21-93e5-7eb4f608815b
a81d1c83-1ffc-4344-a4b5-a702fcda3620
346254cb-3db1-4abf-a4f3-3a18ec55d511
21599222-54a6-4448-86f2-0a35491decf8
aa6c4c3b-7bb9-4c4d-94df-c7075606d832
e18482ab-447f-4beb-be85-174529a4dd60
81643455-230f-40c4-a4f0-ac8579d5be97
5f87c6a3-36ba-4b92-9d69-9f7346fa36df
7afed534-80aa-4473-b5d5-d80487655d89
933cda9d-6a00-4350-a65b-ff679225ca7f
154e83ed-f280-4781-bea8-97a863fc9c7f
e856b212-af21-426e-a822-eebc1b36c7dc
bf66c137-d233-4ec5-bcfa-f1a5306c27ed
21d33f6f-0191-4df1-b003-1f9a00ea3c0f
3aec10b1-2dcf-48c8-bac9-91fa28ff6876
ff2b6e7a-43d3-4a9f-b49f-14a5a1569cb3
7892f088-1404-42d0-b3f6-040afbeda124
1dbe8026-920d-4cbd-8bf5-e005af952b0e
4d8c3c55-3736-4f18-9b81-807872c99671
79c67aba-2bc3-4131-9178-109a95afc437
ef00060b-7fdc-4901-bdb7-5980d0a438f0
fb8b6744-e6d1-4c34-978f-4d668aa5166d
991f88a3-7be1-4026-8b8f-506587895216
e6ef840c-0227-420a-b059-45d215011df3
9778fc8b-099b-47bf-8c24-5073549fc65d
911b2f3c-af1b-4107-9404-9a123c01a043
ef1fa30e-6d99-4986-873f-030169463889
e7599247-122c-43b1-868f-4a85c9f5a66c
e1b37c82-401f-47ea-9b54-a1fbc3fbb4ea
e303b0f4-9169-47d5-8ecb-d1260b960e12
e8c6afd0-c37f-460e-a770-88c48e99bb1c
741404d3-bcf3-4d42-984a-2397e5ab5b8c
be6ada9a-4e42-4345-b330-3a356104021d
aabd8246-8ace-4eb6-a6e2-e86b142c71c9
ACCOUNT_IDS

echo
echo "Done. total=$total success=$success failed=$failed"
echo "Success log: $SUCCESS_LOG"
echo "Failed log:  $FAILED_LOG"
echo "Responses:   $RESPONSE_LOG"
