#!/bin/sh
# Verification gate 1 for a MoneyMoney extension repository.
# Checks every .lua file at the repository root. Exits non-zero on any failure.
#
# Usage: ./check.sh

set -u

fail=0
tab=$(printf '\t')

note()     { printf '  %-8s %s\n' "$1" "$2"; }
evidence() { sed 's/^/           /'; }

for f in *.lua; do
  [ -e "$f" ] || { echo "No .lua file found at repository root."; exit 1; }
  echo "$f"
  bad=0
  err() { note "FAIL" "$1"; bad=1; fail=1; }

  # Syntax. luac -p only parses, it never writes output.
  if command -v luac >/dev/null 2>&1; then
    luac -p "$f" 2>/dev/null || err "does not parse (luac -p)"
  else
    note "skip" "luac not installed - syntax not checked"
  fi

  # Tabs corrupt signed builds: the signing process expands them to 8 spaces.
  if grep -q "^[ ]*$tab" "$f"; then
    err "tab indentation found (breaks signed builds)"
    grep -n "^[ ]*$tab" "$f" | head -5 | evidence
  fi

  # MoneyMoney requires UTF-8.
  iconv -f UTF-8 -t UTF-8 "$f" >/dev/null 2>&1 || err "not valid UTF-8"

  if grep -q '[ '"$tab"']$' "$f"; then
    err "trailing whitespace"
    grep -n '[ '"$tab"']$' "$f" | head -5 | evidence
  fi

  [ -n "$(tail -c 1 "$f")" ] && err "no newline at end of file"

  grep -q 'WebBanking[[:space:]]*{' "$f" || err "no WebBanking{} declaration"
  grep -qE 'version[[:space:]]*=[[:space:]]*[0-9]' "$f" || err "no version in WebBanking{}"

  # Credentials must never be logged.
  if grep -qE '(print|MM\.printStatus)[^)]*(apiSecret|apiKey|password|secret)' "$f"; then
    err "credential possibly written to log output"
    grep -nE '(print|MM\.printStatus)[^)]*(apiSecret|apiKey|password|secret)' "$f" | head -5 | evidence
  fi

  # Long literal that looks like a committed key.
  if grep -qE '=[[:space:]]*"[A-Za-z0-9+/=_-]{32,}"' "$f"; then
    err "long literal string - committed credential?"
    grep -nE '=[[:space:]]*"[A-Za-z0-9+/=_-]{32,}"' "$f" | head -5 | evidence
  fi

  [ "$bad" -eq 0 ] && note "ok" "all checks passed"
done

exit "$fail"
