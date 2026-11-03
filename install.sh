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

# Google Chrome by its bundle id, wherever it is (the CLI looks the same way, atibcli/browser.py): "Google
# Chrome.app" in the folders given first, then another Chrome there ("Google Chrome 2.app", Beta...), then
# anywhere Spotlight knows of it (left in Downloads, renamed). Prints the app, "image:<app>" when the only one is
# still on the disk image it came on (it goes away when that is ejected), or nothing.
find_chrome() {
    local ids=" com.google.Chrome com.google.Chrome.beta com.google.Chrome.dev com.google.Chrome.canary "
    local folder app id exe image="" query="" volumes="${ATIB_VOLUMES_ROOT:-/Volumes}"   # (tests: elsewhere)
    is_chrome() {
        id="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$1/Contents/Info.plist" 2>/dev/null)" || return 1
        case "$ids" in *" $id "*) ;; *) return 1 ;; esac
        exe="$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$1/Contents/Info.plist" 2>/dev/null)" || return 1
        [ -x "$1/Contents/MacOS/$exe" ]
    }
    for folder in "$@"; do
        for app in "$folder/Google Chrome.app" "$folder"/Google\ Chrome*.app; do
            if [ -d "$app" ] && is_chrome "$app"; then printf '%s\n' "$app"; return 0; fi
        done
    done
    for id in $ids; do query="${query:+$query || }kMDItemCFBundleIdentifier == \"$id\""; done
    while IFS= read -r app; do
        if [ -z "$app" ] || [ ! -d "$app" ] || ! is_chrome "$app"; then continue; fi
        case "$app" in
            "$volumes"/*) [ -n "$image" ] || image="$app" ;;
            *) printf '%s\n' "$app"; return 0 ;;
        esac
    done < <(mdfind "$query" 2>/dev/null || true)
    if [ -n "$image" ]; then printf 'image:%s\n' "$image"; fi
    return 0
}

chrome="$(find_chrome "/Applications" "$HOME/Applications")"
case "$chrome" in
    "")
        say "ATIB CLI drives your own Google Chrome, in the background, and could not find it."
        say "Installed already? Drag Google Chrome into Applications (Finder), then run this again."
        say "Not yet? Install it from https://www.google.com/chrome/ and run this again."
        open "https://www.google.com/chrome/" 2>/dev/null || true
        exit 1 ;;
    image:*)
        say "Google Chrome is still on the disk image it came on (${chrome#image:})."
        say "Drag it into Applications (Finder), eject the image, then run this again."
        open /Applications 2>/dev/null || true
        exit 1 ;;
    /Applications/*|"$HOME"/Applications/*) ok "Google Chrome" ;;
    *) ok "Google Chrome ($chrome)" ;;
esac

# --- uv (and through it, Python) ------------------------------------------------------------------------
before="$PATH"                               # the PATH new Terminal windows get, as it is before this script
export PATH="$HOME/.local/bin:$PATH"
if ! command -v uv >/dev/null 2>&1; then
    say "Installing uv (it brings its own Python)..."
    curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh >/dev/null 2>&1 \
        || fail "uv did not install. Check the internet connection and run this again."
fi
command -v uv >/dev/null 2>&1 || fail "uv is not on PATH after installing it."
ok "uv $(uv --version | awk '{print $2}')"

# --- the `atib` command on your PATH, for new Terminal windows ------------------------------------------------
add_to_path() {
    case ":$before:" in *":$HOME/.local/bin:"*) return 0 ;; esac          # new windows have it already
    case "${SHELL:-/bin/zsh}" in */bash) rc="$HOME/.bash_profile" ;; *) rc="$HOME/.zshrc" ;; esac
    grep -qs '\.local/bin' "$rc" && return 0                              # written before
    printf '\n# ATIB CLI: the atib and uv commands are in ~/.local/bin\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
}
[ -n "${ATIB_NO_PATH:-}" ] || add_to_path || say "Add ~/.local/bin to your PATH to use atib in new windows."

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
# what can take long on a slow connection is shown as it goes: Python first, then the packages
say "Getting Python 3.13 (about 20 MB)..."
uv python install 3.13 || fail "Python did not download. Check the internet connection and run this again."
ok "Python 3.13"
say "Getting ATIB CLI $version and what it needs (about 60 MB: a few minutes on a slow connection)..."
uv tool install --force --python 3.13 --constraints "$work/constraints.txt" \
    "$work/atib_cli-$version-py3-none-any.whl" \
    || fail "ATIB CLI did not install. Run this again: what was downloaded is kept, so it goes faster."
ok "ATIB CLI $version"

printf '\n'
say "Done. Open a new Terminal window and type:  atib"
say "(or, in this one:  export PATH=\"\$HOME/.local/bin:\$PATH\" && atib)"
say "Updates later:  atib update"
printf '\n'
