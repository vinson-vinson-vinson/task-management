#!/usr/bin/env bash
set -euo pipefail

# One-shot setup: `tasks` on PATH + anny-ws:// URL handler.
# Idempotent — safe to rerun (e.g. after moving this directory). Rerunning
# rebuilds the handler app with a fresh ad-hoc signature, so macOS re-asks
# the Terminal-consent question once on the next create click.

cd "$(dirname "$0")"
DIR="$(pwd)"
BIN_DIR="$HOME/.local/bin"

# --- 1. config ---------------------------------------------------------------
if [[ ! -f "$DIR/config.json" ]]; then
  echo "⚠ no config.json yet — copy config.json.example and fill in your values."
fi

# --- 2. `tasks` on PATH ------------------------------------------------------
mkdir -p "$BIN_DIR"
chmod +x "$DIR/bin/tasks"
ln -sf "$DIR/bin/tasks" "$BIN_DIR/tasks"
echo "Linked $BIN_DIR/tasks -> $DIR/bin/tasks"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "⚠ $BIN_DIR is not on your PATH — add it in your shell profile." ;;
esac

# --- 3. anny-ws:// URL handler (create/open buttons in `tasks`) --------------
# Builds AnnyWsHandler.app (stays in this directory) and registers it with
# LaunchServices for the anny-ws:// scheme. The dispatcher path is baked in
# at compile time and the signature is machine-local, so every machine (and
# every move of this directory) needs a rebuild.
APP="$DIR/build/AnnyWsHandler.app"
DISPATCHER="$DIR/handler/ws-url-open"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

chmod +x "$DISPATCHER"

mkdir -p "$DIR/build"
rm -rf "$APP"
sed "s|@DISPATCHER@|$DISPATCHER|g" handler/handler.applescript.in | osacompile -o "$APP"

PLIST="$APP/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "co.anny.ws-url-handler" "$PLIST"
# Required for macOS to show the Automation consent prompt (controlling
# Terminal); without it the Apple Event is auto-denied with error -1743.
plutil -replace NSAppleEventsUsageDescription -string "Runs ws workspace commands in a Terminal window when you click an anny-ws:// link." "$PLIST"
/usr/libexec/PlistBuddy \
  -c 'Add :CFBundleURLTypes array' \
  -c 'Add :CFBundleURLTypes:0 dict' \
  -c 'Add :CFBundleURLTypes:0:CFBundleURLName string "anny workspace actions"' \
  -c 'Add :CFBundleURLTypes:0:CFBundleURLSchemes array' \
  -c 'Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string anny-ws' \
  "$PLIST"

# Re-sign: the plist edits above break the seal osacompile created, and TCC
# silently auto-denies Automation consent for apps with invalid signatures.
codesign --force -s - "$APP"

if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$APP"
else
  open -g "$APP"   # fallback: launching once also registers the scheme
fi

echo "Registered anny-ws:// handler: $APP"
echo "Test with:  open \"anny-ws://ping/hello\""
