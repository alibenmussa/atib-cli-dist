#!/bin/bash
# ATIB CLI installer. Paste into Terminal:
#
#   curl -fsSL https://raw.githubusercontent.com/alibenmussa/atib-cli-dist/main/install.sh | bash
#
# It checks macOS and Google Chrome, installs uv if it is missing (uv brings its own Python: nothing else is
# needed, and no administrator password), then installs the newest ATIB CLI with the exact versions of what it
# needs, and puts the `atib` command on your PATH. Run it again to repair an install. Nothing is sent anywhere;
# your bank sign-in is asked for later, by `atib` itself, and kept in your Mac's Keychain.
#
# ATIB_VERSION=0.2.0 installs that version instead of the newest.

set -euo pipefail

REPO="alibenmussa/atib-cli-dist"
BASE="${ATIB_DIST_BASE:-https://github.com/$REPO/releases}"     # (tests point this at a local folder)

say()  { printf '  %s\n' "$*"; }
ok()   { printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
fail() { printf '  \033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

printf '\n  \033[1;37;41m ATIB \033[0m  CLI installer\n\n'

# --- this Mac -----------------------------------------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || fail "ATIB CLI runs on macOS only."
macos="$(sw_vers -productVersion)"
[ "${macos%%.*}" -ge 12 ] || fail "macOS 12 or later is needed (this Mac has $macos)."
ok "macOS $macos ($(uname -m))"

chrome=""
for app in "/Applications/Google Chrome.app" "$HOME/Applications/Google Chrome.app"; do
    [ -d "$app" ] && chrome="$app" && break
done
if [ -z "$chrome" ]; then
    say "ATIB CLI drives your own Google Chrome, in the background. Install it, then run this again:"
    say "https://www.google.com/chrome/"
    open "https://www.google.com/chrome/" 2>/dev/null || true
    exit 1
fi
ok "Google Chrome"

# --- uv (and through it, Python) ------------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"
if ! command -v uv >/dev/null 2>&1; then
    say "Installing uv (it brings its own Python)..."
    curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh >/dev/null 2>&1 \
        || fail "uv did not install. Check the internet connection and run this again."
fi
command -v uv >/dev/null 2>&1 || fail "uv is not on PATH after installing it."
ok "uv $(uv --version | awk '{print $2}')"

# --- ATIB CLI -------------------------------------------------------------------------------------------
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
if [ -n "${ATIB_VERSION:-}" ]; then
    version="${ATIB_VERSION#v}"
    files="$BASE/download/v$version"
else
    curl -fsSL "$BASE/latest/download/latest.json" -o "$work/latest.json" \
        || fail "Could not reach GitHub for the newest version. Check the internet connection."
    version="$(plutil -extract version raw -o - "$work/latest.json")"
    files="$BASE/download/v$version"
fi
curl -fsSL "$files/constraints.txt" -o "$work/constraints.txt" || fail "Version $version is not published."
curl -fsSL "$files/atib_cli-$version-py3-none-any.whl" -o "$work/atib_cli-$version-py3-none-any.whl" \
    || fail "Version $version is not published."
say "Installing ATIB CLI $version..."
uv tool install --force --quiet --python 3.13 --constraints "$work/constraints.txt" \
    "$work/atib_cli-$version-py3-none-any.whl" || fail "ATIB CLI did not install."
ok "ATIB CLI $version"

# --- the command on your PATH, for new Terminal windows ---------------------------------------------------
[ -n "${ATIB_NO_PATH:-}" ] || uv tool update-shell >/dev/null 2>&1 || true      # (tests leave your shell alone)
printf '\n'
say "Done. Open a new Terminal window and type:  atib"
say "(or, in this one:  export PATH=\"\$HOME/.local/bin:\$PATH\" && atib)"
say "Updates later:  atib update"
printf '\n'
