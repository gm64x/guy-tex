#!/usr/bin/env bash
set -euo pipefail

# Debug mode: set DEBUG=true to print commands and full tool output
DEBUG="${DEBUG:-false}"

# Inputs
DIAGRAMS_DIR="${1:-imagens/diagrams}"
CHANGED_FILES_LIST="${2:-.changed_files_list}"

mkdir -p "$DIAGRAMS_DIR"
DIAGRAMS_DIR_ABS="$(cd "$DIAGRAMS_DIR" && pwd -P)"

# Create a puppeteer config to bypass sandbox issues in Linux CI
PUPPETEER_CONFIG="/tmp/puppeteer-config.json"
printf '%s' '{"args": ["--no-sandbox", "--disable-setuid-sandbox"]}' > "$PUPPETEER_CONFIG"

PLANTUML_JAR="${PLANTUML_JAR:-/tmp/plantuml.jar}"
PLANTUML_JAR_URL="${PLANTUML_JAR_URL:-https://github.com/plantuml/plantuml/releases/latest/download/plantuml.jar}"

echo "::group::Diagram Rendering"
echo "Working directory: $(pwd)"
echo "Rendering diagrams to: $DIAGRAMS_DIR"
if [ "$DEBUG" = "true" ]; then
  echo "DEBUG mode ON"
  echo "DIAGRAMS_DIR=$DIAGRAMS_DIR"
  echo "DIAGRAMS_DIR_ABS=$DIAGRAMS_DIR_ABS"
  echo "CHANGED_FILES_LIST=$CHANGED_FILES_LIST"
  echo "PLANTUML_JAR=$PLANTUML_JAR"
  echo "PLANTUML_JAR_URL=$PLANTUML_JAR_URL"
  echo "Java: $(java -version 2>&1 || true)"
  echo "Node: $(node --version 2>&1 || true)"
  echo "npx: $(npx --version 2>&1 || true)"
fi

render_mermaid() {
  local f="$1"
  # sanitize CRLF
  f="${f//$'\r'/}"
  local base_noext
  base_noext=$(basename "$f")
  local base
  base="${base_noext%.*}"
  local out="$DIAGRAMS_DIR/${base}.png"

  echo "Mermaid: '$f' -> '$out'"
  local version="${MERMAID_CLI_VERSION:-9}"
  # Build command as array to avoid word-splitting issues
  local cmd=(npx -y "@mermaid-js/mermaid-cli@$version" -i "$f" -o "$out" -p "$PUPPETEER_CONFIG")

  if [ "$DEBUG" = "true" ]; then
    echo "Running: ${cmd[*]}"
    if ! "${cmd[@]}"; then
      echo "::warning file=$f::Mermaid render failed"
    fi
  else
    if ! "${cmd[@]}" >/dev/null 2>&1; then
      echo "::warning file=$f::Failed to render Mermaid diagram. Skipping."
      return 0
    fi
  fi
}

ensure_plantuml_jar() {
  if [ ! -f "$PLANTUML_JAR" ]; then
    mkdir -p "$(dirname "$PLANTUML_JAR")" || true
    echo "Downloading PlantUML jar to $PLANTUML_JAR..."
    if ! curl -sSL -o "$PLANTUML_JAR" "$PLANTUML_JAR_URL"; then
      echo "::warning::Failed to download PlantUML jar from $PLANTUML_JAR_URL"
      return 1
    fi
  fi
  return 0
}

render_plantuml() {
  local f="$1"
  # sanitize CRLF
  f="${f//$'\r'/}"
  local base_noext
  base_noext=$(basename "$f")
  local base
  base="${base_noext%.*}"
  local dir
  dir=$(dirname "$f")
  local out
  out="$DIAGRAMS_DIR/${base}.png"

  echo "PlantUML: '$f' -> '$out'"

  if ! ensure_plantuml_jar; then
    echo "::warning file=$f::PlantUML jar download failed. Skipping."
    return 0
  fi

  # PlantUML resolves relative -o paths from the input file directory, so use
  # an absolute output directory to avoid nested imagens/diagrams paths in CI.
  local cmd=(java -jar "$PLANTUML_JAR" -tpng -charset UTF-8 -o "$DIAGRAMS_DIR_ABS" "$f")
  if [ "$DEBUG" = "true" ]; then
    echo "Running: ${cmd[*]}"
    local output
    if ! output="$("${cmd[@]}" 2>&1)"; then
      echo "::warning file=$f::PlantUML render failed. Output:"
      echo "$output"
      return 0
    fi
    echo "$output"
  else
    if ! "${cmd[@]}" >/dev/null 2>&1; then
      echo "::warning file=$f::Failed to render PlantUML diagram. Skipping."
      # fallback: if plantuml emitted file next to source, try to move it
      local fallback="$dir/${base}.png"
      if [ -f "$fallback" ]; then
        mv "$fallback" "$out" || true
      fi
      return 0
    fi
  fi

  # Verify output exists; plantuml sometimes writes near the source
  if [ ! -f "$out" ]; then
    local candidate
    candidate="$(find "$dir" -maxdepth 1 -type f -name "${base}.png" -print -quit || true)"
    if [ -n "$candidate" ]; then
      mv "$candidate" "$out" || true
      echo "Moved generated file $candidate -> $out"
    else
      echo "::warning file=$f::PlantUML rendering reported success but output not found at $out"
    fi
  fi
}

# Helper to check for any PlantUML variant with same base name
has_plantuml_variant() {
  local dir="$1"
  local base="$2"
  [ -f "$dir/${base}.plantuml" ] && return 0
  [ -f "$dir/${base}.puml" ] && return 0
  [ -f "$dir/${base}.uml" ] && return 0
  return 1
}

if [ -s "$CHANGED_FILES_LIST" ]; then
  echo "Using detected changed files list: $CHANGED_FILES_LIST"
  while IFS= read -r f || [ -n "$f" ]; do
    # strip CRLF
    f="${f//$'\r'/}"
    [ -z "$f" ] && continue
    echo "Considering: '$f'"
    case "$f" in
      *.mmd)
        dir=$(dirname "$f")
        base=$(basename "$f" .mmd)
        if has_plantuml_variant "$dir" "$base"; then
          echo "::debug::Skipping '$f' because a PlantUML variant exists (prefer PlantUML)"
          continue
        fi
        if [ -f "$f" ]; then
          render_mermaid "$f"
        else
          echo "::debug::Skipping missing file: $f"
        fi
        ;;
      *.plantuml|*.puml|*.uml)
        if [ -f "$f" ]; then
          render_plantuml "$f"
        else
          echo "::debug::Skipping missing file: $f"
        fi
        ;;
      *)
        echo "::debug::Ignoring non-diagram file: $f"
        ;;
    esac
  done < "$CHANGED_FILES_LIST"
else
  echo "No changed file list; scanning repository for .mmd and PlantUML files..."
  find . -maxdepth 6 \( -name "*.mmd" -o -name "*.plantuml" -o -name "*.puml" -o -name "*.uml" \) -print0 | while IFS= read -r -d '' f; do
    case "$f" in
      *.mmd)
        dir=$(dirname "$f")
        base=$(basename "$f" .mmd)
        if has_plantuml_variant "$dir" "$base"; then
          echo "::debug::Skipping '$f' because a PlantUML variant exists (prefer PlantUML)"
          continue
        fi
        render_mermaid "$f"
        ;;
      *.plantuml|*.puml|*.uml)
        render_plantuml "$f"
        ;;
    esac
  done
fi

echo "Done. Rendered files in: $DIAGRAMS_DIR"
ls -la "$DIAGRAMS_DIR" || true
echo "::endgroup::"
rm -f "$PUPPETEER_CONFIG"
