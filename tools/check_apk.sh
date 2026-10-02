#!/usr/bin/env bash
# Sanity-checks an exported Android APK before it is published:
#   tools/check_apk.sh <path/to/app.apk>
#
# GitHub's raw step logs are not always reachable outside CI, so every failure
# also prints an ::error annotation that carries the APK's zip listing — that
# way a broken package is diagnosable straight from the checks API.
set -uo pipefail

apk="${1:?usage: tools/check_apk.sh <path/to/app.apk>}"

list_entries() {  # prints one zip entry per line; empty if no tool is around
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
print("\n".join(z.namelist()))' "$apk"
  elif command -v unzip >/dev/null 2>&1; then
    unzip -Z1 "$apk"
  fi
}

fail() {
  local msg="$1"
  echo "FAIL: $msg"
  if command -v python3 >/dev/null 2>&1 || command -v unzip >/dev/null 2>&1; then
    local sample
    sample="$(printf '%s\n' "$entries" | grep -Ev '/$' | head -25 | tr '\n' '|')"
    echo "::error title=apk::$msg。条目示例：${sample}"
  else
    echo "::error title=apk::$msg（容器里没有 python3 也没有 unzip，无法列出内容）"
  fi
  exit 1
}

[ -f "$apk" ] || fail "APK 不存在：$apk"
[ -s "$apk" ] || fail "APK 是空文件：$apk"

echo "== tools =="
printf 'python3=%s unzip=%s keytool=%s\n' \
  "$(command -v python3 || echo none)" \
  "$(command -v unzip || echo none)" \
  "$(command -v keytool || echo none)"

entries="$(list_entries)"
count="$(printf '%s\n' "$entries" | grep -c . || true)"
echo "== zip entries: $count =="
[ "$count" -gt 0 ] || fail "APK 不是有效的 zip（或容器里没有 python3 / unzip 可以列目录）"
printf '%s\n' "$entries" | grep -Ev '/$' | head -15

echo "== native libraries =="
printf '%s\n' "$entries" | grep -E '^lib/' | head -20

libs="$(printf '%s\n' "$entries" | grep -E '^lib/[^/]+/lib.*\.so$' || true)"
[ -n "$libs" ] || fail "APK 里没有任何 lib/<abi>/*.so，无法在手机上运行"

for abi in arm64-v8a armeabi-v7a; do
  if printf '%s\n' "$entries" | grep -q "^lib/$abi/"; then
    echo "  ✓ $abi: $(printf '%s\n' "$entries" | grep "^lib/$abi/" | tr '\n' ' ')"
  else
    fail "$abi 缺少原生库（导出预设里的 architectures/$abi 应为 true）"
  fi
done

printf '%s\n' "$libs" | grep -q 'libgodot' \
  || fail "lib/ 下找不到 libgodot*.so（引擎库没打进去）"

echo "== embedded game data =="
assets="$(printf '%s\n' "$entries" | grep -c '^assets/' || true)"
[ "$assets" -gt 0 ] || fail "APK 内没有 assets/ 数据，游戏跑起来会是空白"
echo "  assets/ 条目：$assets"
printf '%s\n' "$entries" | grep -E '^assets/[^/]*$' | head -10

echo "== signature =="
apksigner="$(command -v apksigner || true)"
for c in "${ANDROID_HOME:-/opt/android-sdk}"/build-tools/*/apksigner; do
  [ -x "$c" ] && apksigner="$c" && break
done
if [ -n "$apksigner" ] && [ -x "$apksigner" ]; then
  if "$apksigner" verify --print-certs "$apk"; then
    echo "  ✓ APK 签名有效（$apksigner）"
  else
    fail "apksigner 校验签名失败，这个 APK 装不上"
  fi
else
  echo "  (apksigner 不可用，退化为检查 META-INF)"
  printf '%s\n' "$entries" | grep -E '^META-INF/.*\.(RSA|SF|DSA|EC)$' \
    || echo "  (无 v1 签名条目，可能只用 v2/v3 签名块)"
fi

echo "== OK: $apk =="
