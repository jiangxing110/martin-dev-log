# OCDD batch review script

This folder contains a small Bash script for batch calling:

```graphql
mutation createOddAccountReview($data: CreateOddAccountReviewInput!) {
  createOddAccountReview(data: $data)
}
```

## Usage

```bash
cd /Users/martinjiang/martin-dev-log/ocdd
chmod +x batch_create_odd_account_review.sh
export OCDD_TOKEN='your bearer token'
./batch_create_odd_account_review.sh
```

The script reads account IDs from `account_ids.txt`.

Logs are written to:

- `logs/success.log`
- `logs/failed.log`
- `logs/responses.jsonl`

## Safer test run

Before running all IDs, keep only one or two IDs in `account_ids.txt`, then run the script once.

## Optional settings

```bash
export DELAY_SECONDS='0.5'
export FINGERPRINT='your fingerprint'
export API_URL='https://global.service.test.qbitnetwork.com/graphql'
export IDS_FILE='account_ids.txt'
```
