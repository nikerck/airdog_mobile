#!/usr/bin/env bash
# 小窝 API 冒烟测试 —— 后端按《接口约定 v1.0》实现后，跑这个应为全绿。
#
# 用法：
#   BASE=http://127.0.0.1:8080 USER_NAME=zyy PASS=123456 IMG=./test.jpg bash smoke.sh
#
# 依赖：curl。可选：MOMO_USER / MOMO_PASS（测权限时必须给）。

set -u

BASE="${BASE:-http://127.0.0.1:8080}"
USER_NAME="${USER_NAME:-zyy}"
PASS="${PASS:-123456}"
MOMO_USER="${MOMO_USER:-}"
MOMO_PASS="${MOMO_PASS:-}"
IMG="${IMG:-}"

PASSED=0
FAILED=0

ok() { PASSED=$((PASSED + 1)); echo "  [ok]   $1"; }
bad() { FAILED=$((FAILED + 1)); echo "  [FAIL] $1"; }

# req <method> <path> [body] [token] -> 输出 "HTTP_CODE\nBODY"
req() {
  local method="$1" path="$2" body="${3:-}" token="${4:-}"
  local args=(-s -o /tmp/smoke_body.txt -w '%{http_code}' -X "$method" "$BASE$path")
  [ -n "$body" ] && args+=(-H 'Content-Type: application/json' -d "$body")
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  local code
  code=$(curl "${args[@]}")
  echo "$code"
  cat /tmp/smoke_body.txt
}

expect_code() { # <desc> <expected_code> <json_body>
  local desc="$1" expect="$2" body="$3"
  if printf '%s' "$body" | grep -q "\"code\":[[:space:]]*$expect"; then
    ok "$desc"
  else
    bad "$desc（期望 code=$expect，实际：$(printf '%s' "$body" | head -c 180)）"
  fi
}

expect_http() { # <desc> <expected_http> <http_code>
  local desc="$1" expect="$2" got="$3"
  if [ "$got" = "$expect" ]; then ok "$desc"; else bad "$desc（期望 HTTP $expect，实际 $got）"; fi
}

echo "== 1. 认证 =="
OUT=$(req POST /api/auth/login "{\"username\":\"$USER_NAME\",\"password\":\"$PASS\"}")
HTTP=$(echo "$OUT" | head -1)
BODY=$(echo "$OUT" | tail -n +2)
expect_http "登录成功返回 200" 200 "$HTTP"
expect_code "登录返回 code=0" 0 "$BODY"
TOKEN=$(printf '%s' "$BODY" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$TOKEN" ] && ok "拿到 token" || bad "没有 token"

OUT=$(req POST /api/auth/login "{\"username\":\"$USER_NAME\",\"password\":\"wrong-pass\"}")
HTTP=$(echo "$OUT" | head -1); BODY=$(echo "$OUT" | tail -n +2)
expect_http "错误密码返回 401" 401 "$HTTP"
expect_code "错误密码 code=1001" 1001 "$BODY"

OUT=$(req GET "/api/todos?spaceId=sp_shared")
HTTP=$(echo "$OUT" | head -1); BODY=$(echo "$OUT" | tail -n +2)
expect_http "无 token 返回 401" 401 "$HTTP"
expect_code "无 token code=1003" 1003 "$BODY"

echo "== 2. 空间 =="
OUT=$(req GET /api/spaces "" "$TOKEN")
BODY=$(echo "$OUT" | tail -n +2)
printf '%s' "$BODY" | grep -q 'sp_personal' && ok "有 sp_personal" || bad "缺少 sp_personal"
printf '%s' "$BODY" | grep -q 'sp_shared' && ok "有 sp_shared" || bad "缺少 sp_shared"
printf '%s' "$BODY" | grep -q 'u_momo' && ok "有 u_momo" || bad "缺少 u_momo"

echo "== 3. 文件 =="
FILE_ID=""
if [ -n "$IMG" ] && [ -f "$IMG" ]; then
  OUT=$(curl -s -o /tmp/smoke_file.txt -w '%{http_code}' -X POST \
    -H "Authorization: Bearer $TOKEN" -F "file=@$IMG" "$BASE/api/files")
  BODY=$(cat /tmp/smoke_file.txt)
  expect_http "上传图片返回 200" 200 "$OUT"
  FILE_ID=$(printf '%s' "$BODY" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  [ -n "$FILE_ID" ] && ok "拿到 fileId" || bad "没有 fileId"

  # 重复上传应返回同一个 id
  BODY2=$(curl -s -X POST -H "Authorization: Bearer $TOKEN" -F "file=@$IMG" "$BASE/api/files")
  ID2=$(printf '%s' "$BODY2" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  [ "$FILE_ID" = "$ID2" ] && ok "重复上传命中同一 id（按 sha256 去重）" || bad "重复上传产生了新 id：$ID2"
else
  echo "  [skip] 未提供 IMG，跳过上传测试"
fi

echo "== 4. 待办 =="
if [ -n "$FILE_ID" ]; then IMAGES="[\"$FILE_ID\"]"; else IMAGES="[]"; fi
OUT=$(req POST /api/todos "{\"spaceId\":\"sp_shared\",\"title\":\"smoke 待办\",\"content\":\"正文测试\",\"images\":$IMAGES,\"dueAt\":null}" "$TOKEN")
BODY=$(echo "$OUT" | tail -n +2)
expect_code "创建待办 code=0" 0 "$BODY"
TODO_ID=$(printf '%s' "$BODY" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\(todo_[^"]*\)".*/\1/p')
REV=$(printf '%s' "$BODY" | sed -n 's/.*"rev"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')
[ -n "$TODO_ID" ] && ok "拿到待办 id" || bad "没有待办 id"

OUT=$(req PATCH "/api/todos/$TODO_ID" "{\"title\":\"smoke 改过\",\"rev\":$REV}" "$TOKEN")
BODY=$(echo "$OUT" | tail -n +2)
expect_code "用正确 rev 修改 code=0" 0 "$BODY"

OUT=$(req PATCH "/api/todos/$TODO_ID" "{\"title\":\"再改\",\"rev\":$REV}" "$TOKEN")
HTTP=$(echo "$OUT" | head -1); BODY=$(echo "$OUT" | tail -n +2)
expect_http "旧 rev 修改返回 409" 409 "$HTTP"
expect_code "旧 rev code=2003" 2003 "$BODY"

if [ -n "$MOMO_USER" ] && [ -n "$MOMO_PASS" ]; then
  MO=$(curl -s -X POST -H 'Content-Type: application/json' \
    -d "{\"username\":\"$MOMO_USER\",\"password\":\"$MOMO_PASS\"}" "$BASE/api/auth/login")
  MTOKEN=$(printf '%s' "$MO" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  OUT=$(req PATCH "/api/todos/$TODO_ID" '{"title":"Momo 想改","rev":99}' "$MTOKEN")
  HTTP=$(echo "$OUT" | head -1); BODY=$(echo "$OUT" | tail -n +2)
  expect_http "非创建人改内容返回 403" 403 "$HTTP"
  expect_code "非创建人 code=2002" 2002 "$BODY"
else
  echo "  [skip] 未提供 MOMO_USER/PASS，跳过非创建人权限测试"
fi

OUT=$(req DELETE "/api/todos/$TODO_ID" "" "$TOKEN")
expect_code "删除待办 code=0" 0 "$(echo "$OUT" | tail -n +2)"

OUT=$(req GET "/api/todos?spaceId=sp_shared" "" "$TOKEN")
printf '%s' "$(echo "$OUT" | tail -n +2)" | grep -q "$TODO_ID" \
  && bad "删除后列表仍包含该待办" || ok "删除后列表不含该待办"

echo "== 5. 生理期 =="
OUT=$(req POST /api/period/logs "{\"spaceId\":\"sp_shared\",\"startedOn\":$(date +%s)000,\"flow\":2}" "$TOKEN")
HTTP=$(echo "$OUT" | head -1); BODY=$(echo "$OUT" | tail -n +2)
expect_http "写入共享空间返回 403" 403 "$HTTP"
expect_code "写入共享空间 code=3003" 3003 "$BODY"

echo "== 6. 同步 =="
OUT=$(req GET "/api/sync/changes?since=0" "" "$TOKEN")
BODY=$(echo "$OUT" | tail -n +2)
expect_code "同步接口 code=0" 0 "$BODY"
printf '%s' "$BODY" | grep -q 'serverTime' && ok "返回 serverTime" || bad "缺少 serverTime"
printf '%s' "$BODY" | grep -q "$TODO_ID" && ok "同步含已删除待办的墓碑行" || bad "同步缺少墓碑行"

echo
echo "通过 $PASSED 项，失败 $FAILED 项"
[ "$FAILED" -eq 0 ] || exit 1
