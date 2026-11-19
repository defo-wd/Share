#!/usr/bin/env bash
#
# disable_http2_openresty.sh
#
# CVE-2026-123007 / CVE-2026-123633 (NGINX2Shell) interim mitigation.
# Disables HTTP/2 by removing the `http2` token from `listen` directives
# (and commenting any `http2 on;`) so an affected but un-upgradable nginx/
# OpenResty stops being exploitable. Clients fall back to HTTP/1.1.
#
# This is a STOPGAP. The real fix is upgrading to a patched build.
#
# Default mode is DRY-RUN: it shows the diff and changes nothing.
# Use --apply to actually edit, --reload to reload after applying.
#
# Usage:
#   ./disable_http2_openresty.sh                 # dry-run, auto-detect conf dir
#   ./disable_http2_openresty.sh --conf-dir DIR  # point at a conf dir
#   ./disable_http2_openresty.sh --apply         # make a backup and edit
#   ./disable_http2_openresty.sh --apply --reload
#   ./disable_http2_openresty.sh --rollback      # restore newest backups
#   ./disable_http2_openresty.sh --verify HOST   # curl --http2 check only
#
set -euo pipefail

NGINX_BIN="${NGINX_BIN:-/usr/local/openresty/nginx/sbin/nginx}"
CONF_DIR="${CONF_DIR:-/usr/local/openresty/nginx/conf}"
STAMP="$(date +%Y%m%d-%H%M%S)"
APPLY=0
RELOAD=0
DO_ROLLBACK=0
VERIFY_HOST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --apply)     APPLY=1 ;;
    --reload)    RELOAD=1 ;;
    --rollback)  DO_ROLLBACK=1 ;;
    --conf-dir)  CONF_DIR="$2"; shift ;;
    --nginx)     NGINX_BIN="$2"; shift ;;
    --verify)    VERIFY_HOST="$2"; shift ;;
    -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

say() { printf '%s\n' "$*"; }

# --- verify-only mode -------------------------------------------------------
if [ -n "$VERIFY_HOST" ]; then
  say "== verify HTTP/2 state on $VERIFY_HOST =="
  if curl -sI --http2 "https://$VERIFY_HOST" -o /dev/null -w '%{http_version}\n' 2>/dev/null \
      | grep -q '^2'; then
    say "RESULT: HTTP/2 still negotiated -> mitigation NOT in effect"
    exit 1
  else
    say "RESULT: not HTTP/2 (HTTP/1.1 fallback) -> mitigation in effect"
    exit 0
  fi
fi

# --- rollback mode ----------------------------------------------------------
if [ "$DO_ROLLBACK" -eq 1 ]; then
  say "== rollback: restoring newest .pre-http2-mitigation backups =="
  found=0
  while IFS= read -r bak; do
    orig="${bak%.pre-http2-mitigation.*}"
    cp -p "$bak" "$orig"
    say "restored $orig  <-  $(basename "$bak")"
    found=1
  done < <(find "$CONF_DIR" -type f -name '*.pre-http2-mitigation.*' \
             | sort | awk -F'.pre-http2-mitigation.' '{print $0" "$1}' \
             | sort -k2,2 -k1,1r | awk '!seen[$2]++{print $1}')
  [ "$found" -eq 1 ] || { say "no backups found under $CONF_DIR"; exit 1; }
  say "run: $NGINX_BIN -t && $NGINX_BIN -s reload"
  exit 0
fi

# --- discover affected files ------------------------------------------------
say "== scan: $CONF_DIR =="
[ -d "$CONF_DIR" ] || { say "conf dir not found: $CONF_DIR"; exit 2; }

# Files with `http2` on a listen line, OR a standalone `http2 on;` directive.
mapfile -t FILES < <(
  grep -rlE '(^|[[:space:]])listen[^;]*[[:space:]]http2([[:space:]]|;)|^[[:space:]]*http2[[:space:]]+on[[:space:]]*;' \
    "$CONF_DIR" 2>/dev/null || true
)

if [ "${#FILES[@]}" -eq 0 ]; then
  say "No HTTP/2 enabled in listen directives. Nothing to change."
  exit 0
fi

say "Files referencing HTTP/2:"
printf '  %s\n' "${FILES[@]}"
say ""

# sed program:
#  1) on listen lines, drop a standalone `http2` token (keeps http2_* intact)
#  2) comment out `http2 on;`
SED_PROG='/listen/ s/[[:space:]]http2([[:space:]]|;)/\1/g; s/^([[:space:]]*)(http2[[:space:]]+on[[:space:]]*;)/\1# \2  (disabled: CVE-2026-123007)/'

changed_any=0
for f in "${FILES[@]}"; do
  say "---- $f ----"
  if diff -u "$f" <(sed -E "$SED_PROG" "$f") > /tmp/.http2diff.$$ 2>/dev/null; then
    say "(no textual change)"
  else
    sed -n 's/^/  /p' /tmp/.http2diff.$$
    changed_any=1
    if [ "$APPLY" -eq 1 ]; then
      cp -p "$f" "$f.pre-http2-mitigation.$STAMP"
      sed -E -i "$SED_PROG" "$f"
      say "  APPLIED (backup: $f.pre-http2-mitigation.$STAMP)"
    fi
  fi
  rm -f /tmp/.http2diff.$$
done
say ""

if [ "$APPLY" -eq 0 ]; then
  say "DRY-RUN only. Re-run with --apply to write changes."
  exit 0
fi

[ "$changed_any" -eq 1 ] || { say "nothing applied"; exit 0; }

# --- syntax check (always) --------------------------------------------------
say "== $NGINX_BIN -t =="
if ! "$NGINX_BIN" -t; then
  say "SYNTAX CHECK FAILED -- not reloading. Rollback with: $0 --rollback"
  exit 1
fi

# --- reload (opt-in) --------------------------------------------------------
if [ "$RELOAD" -eq 1 ]; then
  say "== reloading =="
  "$NGINX_BIN" -s reload
  say "reloaded. Check old workers are gone:"
  say "  ps aux | grep '[n]ginx'"
  say "Then verify:  $0 --verify <your-host>"
else
  say "Applied + syntax OK. Reload when ready:"
  say "  $NGINX_BIN -s reload"
fi
