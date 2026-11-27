#!/usr/bin/env bash
# apply_release_settings.sh
#
# Patches project.godot to enforce production-safe settings before a release
# build. Run this script from the repository root before invoking
# `godot --export-release`. An optional second argument sets the game
# version (without the tag's leading v).
#
# Idempotent: safe to run multiple times.

set -euo pipefail

PROJECT_FILE="${1:-project.godot}"
BUILD_VERSION="${2:-}"

if [[ ! -f "$PROJECT_FILE" ]]; then
	echo "ERROR: project file not found: $PROJECT_FILE" >&2
	exit 1
fi

echo "Applying release settings to $PROJECT_FILE ..."

# Godot can omit the version setting when it is empty. Insert it even if
# there is no existing key, escaping for both the Godot string and sed.
if [[ -n "$BUILD_VERSION" ]]; then
	escaped_version="$(printf '%s' "$BUILD_VERSION" | sed 's/["\\]/\\&/g; s/[\\&|]/\\&/g')"
	sed -i -e '/^config\/version=/d' \
		-e "/^\[application\]$/s|$|\nconfig/version=\"$escaped_version\"|" \
		"$PROJECT_FILE"
fi

# ── [zom_nom_defense] debug flags ────────────────────────────────────────────
sed -i \
	's|^debug/show_debug_panel=.*|debug/show_debug_panel=false|' \
	"$PROJECT_FILE"

sed -i \
	's|^debug/bypass_tech_requirements=.*|debug/bypass_tech_requirements=false|' \
	"$PROJECT_FILE"

sed -i \
	's|^debug/unlock_all_scenarios=.*|debug/unlock_all_scenarios=false|' \
	"$PROJECT_FILE"

sed -i \
	's|^debug/enable_tools=.*|debug/enable_tools=false|' \
	"$PROJECT_FILE"

# ── [twitcher] log levels ─────────────────────────────────────────────────────
# Lower all twitcher log channels from "debug" to "warn" for release.
for key in TwitchAuth TwitchAPI TwitchService; do
	sed -i \
		"s|^logs/${key}=\"debug\"|logs/${key}=\"warn\"|" \
		"$PROJECT_FILE"
done

# Http log level: "info" → "warn"
sed -i \
	's|^logs/Http="info"|logs/Http="warn"|' \
	"$PROJECT_FILE"

echo "Done. Release settings applied."
