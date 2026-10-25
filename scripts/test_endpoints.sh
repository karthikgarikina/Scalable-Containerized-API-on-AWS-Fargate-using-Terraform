#!/usr/bin/env bash
set -e

BASE_URL="${1:-http://localhost:8000}"

echo "=========================================================="
echo " Testing Containerized RESTful API on $BASE_URL"
echo "=========================================================="

# 1. Test Health Check
echo -n "[TEST 1] GET /health (HTTP 200 & {'status': 'healthy'})... "
HEALTH_RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/health")
HEALTH_CODE=$(echo "$HEALTH_RESP" | tail -n1)
HEALTH_BODY=$(echo "$HEALTH_RESP" | sed '$d')

if [ "$HEALTH_CODE" -ne 200 ] || [[ ! "$HEALTH_BODY" =~ "healthy" ]]; then
    echo "[FAIL] (HTTP $HEALTH_CODE - $HEALTH_BODY)"
    exit 1
fi
echo "[PASS]"

# 2. Test Create Item
echo -n "[TEST 2] POST /items (HTTP 201 & Valid Item Object)... "
RAND_STR=$RANDOM
CREATE_RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/items" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"Bash Item $RAND_STR\", \"description\": \"Created via test_endpoints.sh\"}")
CREATE_CODE=$(echo "$CREATE_RESP" | tail -n1)
CREATE_BODY=$(echo "$CREATE_RESP" | sed '$d')

if [ "$CREATE_CODE" -ne 201 ]; then
    echo "[FAIL] (HTTP $CREATE_CODE - $CREATE_BODY)"
    exit 1
fi
echo "[PASS]"

# 3. Test List Items
echo -n "[TEST 3] GET /items (HTTP 200 & Array containing items)... "
LIST_RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/items")
LIST_CODE=$(echo "$LIST_RESP" | tail -n1)
LIST_BODY=$(echo "$LIST_RESP" | sed '$d')

if [ "$LIST_CODE" -ne 200 ] || [[ ! "$LIST_BODY" =~ "Bash Item $RAND_STR" ]]; then
    echo "[FAIL] (HTTP $LIST_CODE - $LIST_BODY)"
    exit 1
fi
echo "[PASS]"

# 4. Test Validation Error
echo -n "[TEST 4] POST /items validation (HTTP 422 on invalid payload)... "
VAL_RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/items" \
    -H "Content-Type: application/json" \
    -d '{"description": "No name provided"}')
VAL_CODE=$(echo "$VAL_RESP" | tail -n1)

if [ "$VAL_CODE" -ne 422 ]; then
    echo "[FAIL] Expected 422 but got $VAL_CODE"
    exit 1
fi
echo "[PASS]"

echo "=========================================================="
echo " All tests passed successfully!"
echo "=========================================================="
