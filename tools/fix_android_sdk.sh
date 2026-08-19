#!/usr/bin/env bash
# Repairs a corrupted Android SDK build-tools install.
#
# Symptom this fixes:
#   > Installed Build Tools revision <X> is corrupted.
#     Remove and install again using the SDK Manager.
#
# Usually caused by a download that ran out of disk mid-extract, leaving the
# versioned build-tools directory present but missing binaries. Any task
# needing d8/aapt2 then fails, so the reported failing task moves around
# (minifyReleaseWithR8, compileReleaseJavaWithJavac, ...) while the cause
# stays the same.
#
# Usage:  bash tools/fix_android_sdk.sh
# Safe to re-run.

set -uo pipefail

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
warn() { printf '  ! %s\n' "$*"; }
ok() { printf '  ✓ %s\n' "$*"; }

# ── 1. Locate the SDK Flutter actually uses ────────────────────────────────
# local.properties is authoritative: it is what Gradle reads. Env vars are
# often unset in cloud workspaces, which is why ANDROID_HOME lookups miss.
SDK=""
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$REPO_ROOT/android/local.properties" ]; then
  SDK="$(sed -n 's/^sdk\.dir=//p' "$REPO_ROOT/android/local.properties" | head -1)"
fi
[ -z "$SDK" ] && SDK="${ANDROID_SDK_ROOT:-}"
[ -z "$SDK" ] && SDK="${ANDROID_HOME:-}"
if [ -z "$SDK" ] && command -v flutter >/dev/null 2>&1; then
  SDK="$(flutter doctor -v 2>/dev/null | sed -n 's/.*Android SDK at \(.*\)/\1/p' | head -1)"
fi
for guess in "$HOME/Android/Sdk" "$HOME/androidsdk" "$HOME/android-sdk" /opt/android-sdk; do
  [ -z "$SDK" ] && [ -d "$guess" ] && SDK="$guess"
done

say "Android SDK"
if [ -z "$SDK" ] || [ ! -d "$SDK" ]; then
  warn "Could not locate the SDK."
  warn "Checked android/local.properties, ANDROID_SDK_ROOT, ANDROID_HOME,"
  warn "flutter doctor, and the usual paths."
  warn "Run 'flutter doctor -v' and look for the 'Android SDK at ...' line."
  exit 1
fi
ok "$SDK"

BT="$SDK/build-tools"
say "Installed build-tools"
if [ ! -d "$BT" ]; then
  warn "No build-tools directory at all — nothing installed."
else
  ls -1 "$BT" 2>/dev/null | sed 's/^/  /' || warn "(empty)"
fi

# ── 2. Flag versions missing their core binaries ───────────────────────────
# A healthy install has aapt2 and d8. Either being absent is the corruption.
say "Integrity check"
CORRUPT=()
if [ -d "$BT" ]; then
  for dir in "$BT"/*/; do
    [ -d "$dir" ] || continue
    v="$(basename "$dir")"
    if [ -x "$dir/aapt2" ] && { [ -f "$dir/lib/d8.jar" ] || [ -x "$dir/d8" ]; }; then
      ok "$v looks intact"
    else
      warn "$v is INCOMPLETE (missing aapt2 and/or d8)"
      CORRUPT+=("$v")
    fi
  done
fi

say "Disk"
df -h "$HOME" | tail -1 | sed 's/^/  /'
AVAIL_K=$(df -Pk "$HOME" | tail -1 | awk '{print $4}')
if [ "${AVAIL_K:-0}" -lt 2000000 ]; then
  warn "Under ~2GB free. A build-tools download may corrupt again."
  warn "Free space first:  flutter clean && rm -rf ~/.gradle/caches/transforms-*"
fi

# ── 3. Remove the broken ones ──────────────────────────────────────────────
if [ ${#CORRUPT[@]} -gt 0 ]; then
  say "Removing corrupted versions"
  for v in "${CORRUPT[@]}"; do
    # Guard: never let an empty variable turn this into rm -rf /
    if [ -n "$SDK" ] && [ -n "$v" ] && [ -d "$BT/$v" ]; then
      rm -rf "${BT:?}/${v:?}" && ok "removed $v"
    fi
  done
else
  say "Nothing corrupted was detected"
  echo "  If the build still fails on build-tools, the SDK may be damaged"
  echo "  in a way this check does not cover. Reinstalling anyway is safe."
fi

# ── 4. Reinstall ───────────────────────────────────────────────────────────
say "Reinstalling build-tools"
SDKMAN="$(find "$SDK" -name sdkmanager -type f 2>/dev/null | head -1)"
if [ -z "$SDKMAN" ]; then
  warn "sdkmanager not found under $SDK"
  warn "Install cmdline-tools, or let Gradle re-fetch by simply rebuilding:"
  warn "  flutter build apk --release"
  exit 1
fi
ok "using $SDKMAN"
chmod +x "$SDKMAN" 2>/dev/null

TARGET="${1:-35.0.0}"
yes 2>/dev/null | "$SDKMAN" "build-tools;$TARGET" || {
  warn "sdkmanager failed for build-tools;$TARGET"
  warn "Try another revision, e.g.: bash tools/fix_android_sdk.sh 34.0.0"
  exit 1
}

say "Result"
ls -1 "$BT" 2>/dev/null | sed 's/^/  /'
echo
ok "Done. Now run:  flutter clean && flutter pub get && flutter build apk --release"
