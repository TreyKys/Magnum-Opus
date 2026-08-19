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

# ── 4. Ownership / write check ──────────────────────────────────────────────
# "Failed to read or create install properties file" is sdkmanager's stock
# message for one specific cause: it can't write into the SDK tree, almost
# always because the SDK is owned by a different user than the one running
# this script (root vs. the workspace user is the common cloud-IDE case).
# Detecting this up front turns a cryptic mid-install failure into a clear
# one-line diagnosis.
say "Write access"
ME="$(id -un)"
OWNER="$(stat -c '%U' "$SDK" 2>/dev/null || stat -f '%Su' "$SDK" 2>/dev/null || echo unknown)"
if [ -w "$SDK" ] && { [ ! -d "$BT" ] || [ -w "$BT" ]; }; then
  ok "$SDK is writable by $ME"
else
  warn "$SDK is NOT writable by $ME (owned by: $OWNER)"
  warn "This is what produces 'Failed to read or create install properties file'."
  echo
  echo "  Fix ownership, then re-run this script:"
  echo "    sudo chown -R \"$ME\" \"$SDK\""
  echo
  echo "  If sudo isn't available, run the install itself as the owner instead:"
  echo "    sudo -u $OWNER bash tools/fix_android_sdk.sh"
  exit 1
fi

# ── 5. Reinstall ───────────────────────────────────────────────────────────
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
LOG="$(mktemp)"
# Capture the full log (--verbose) so a failure shows its real cause rather
# than sdkmanager's terse default output. PIPESTATUS[1] is checked, not the
# pipeline's own status, because the last stage is `tee` — with a three-stage
# pipe the final exit code belongs to tee, not to sdkmanager.
yes 2>/dev/null | "$SDKMAN" --verbose "build-tools;$TARGET" 2>&1 | tee "$LOG"
SDKMAN_STATUS="${PIPESTATUS[1]}"

if [ "$SDKMAN_STATUS" -ne 0 ]; then
  warn "sdkmanager exited $SDKMAN_STATUS installing build-tools;$TARGET"
  warn "Full log: $LOG"
  echo
  tail -15 "$LOG" | sed 's/^/    /'
  echo
  warn "Try another revision, e.g.: bash tools/fix_android_sdk.sh 34.0.0"
  exit 1
fi
rm -f "$LOG"

say "Result"
ls -1 "$BT" 2>/dev/null | sed 's/^/  /'
echo
ok "Done. Now run:  flutter clean && flutter pub get && flutter build apk --release"
