#!/usr/bin/env bash
set -euo pipefail

# Debug mode: set DEBUG=true to print commands and full tool output
DEBUG="${DEBUG:-false}"

# Inputs
DIAGRAMS_DIR="${1:-fontes/imagens/diagramas}"
HASH_MANIFEST="${2:-/tmp/diagram-cache/hashes.tsv}"
FORCE_ALL="${3:-false}"

mkdir -p "$DIAGRAMS_DIR" "$(dirname "$HASH_MANIFEST")"
DIAGRAMS_DIR_ABS="$(cd "$DIAGRAMS_DIR" && pwd -P)"
NEW_HASH_MANIFEST="${HASH_MANIFEST}.new"
: > "$NEW_HASH_MANIFEST"

# Create a puppeteer config to bypass sandbox issues in Linux CI.
# If the workflow provides PUPPETEER_EXECUTABLE_PATH, use it explicitly.
PUPPETEER_CONFIG="/tmp/puppeteer-config.json"
if [ -n "${PUPPETEER_EXECUTABLE_PATH:-}" ]; then
  cat > "$PUPPETEER_CONFIG" <<EOF
{
  "executablePath": "${PUPPETEER_EXECUTABLE_PATH}",
  "args": ["--no-sandbox", "--disable-setuid-sandbox"]
}
EOF
else
  cat > "$PUPPETEER_CONFIG" <<'EOF'
{
  "args": ["--no-sandbox", "--disable-setuid-sandbox"]
}
EOF
fi

PLANTUML_JAR="${PLANTUML_JAR:-/tmp/plantuml.jar}"
PLANTUML_JAR_URL="${PLANTUML_JAR_URL:-https://github.com/plantuml/plantuml/releases/latest/download/plantuml.jar}"
PLANTUML_JAR_SHA256="${PLANTUML_JAR_SHA256:-}"

echo "::group::Diagram Rendering"
echo "Working directory: $(pwd)"
echo "Rendering diagrams to: $DIAGRAMS_DIR"

if [ "$DEBUG" = "true" ]; then
  echo "DEBUG mode ON"
  echo "DIAGRAMS_DIR=$DIAGRAMS_DIR"
  echo "DIAGRAMS_DIR_ABS=$DIAGRAMS_DIR_ABS"
  echo "HASH_MANIFEST=$HASH_MANIFEST"
  echo "FORCE_ALL=$FORCE_ALL"
  echo "PLANTUML_JAR=$PLANTUML_JAR"
  echo "PLANTUML_JAR_URL=$PLANTUML_JAR_URL"
  echo "PUPPETEER_EXECUTABLE_PATH=${PUPPETEER_EXECUTABLE_PATH:-}"
  echo "Java: $(java -version 2>&1 || true)"
  echo "Node: $(node --version 2>&1 || true)"
  echo "npm: $(npm --version 2>&1 || true)"
  echo "npx: $(npx --version 2>&1 || true)"
fi

render_mermaid() {
  local f="$1"
  f="${f//$'\r'/}"

  local base_noext
  base_noext=$(basename "$f")

  local base
  base="${base_noext%.*}"

  local out="$DIAGRAMS_DIR/${base}.png"

  echo "Mermaid: '$f' -> '$out'"

  local version="${MERMAID_CLI_VERSION:-11}"

  local cmd=(
    npx
    -y
    -p
    "@mermaid-js/mermaid-cli@$version"
    mmdc
    -i "$f"
    -o "$out"
    -p "$PUPPETEER_CONFIG"
  )

  if [ "$DEBUG" = "true" ]; then
    echo "Mermaid CLI version:"
    npx -y -p "@mermaid-js/mermaid-cli@$version" mmdc --version || true

    echo "Running command:"
    printf ' %q' "${cmd[@]}"
    echo
  fi

  local output
  local rc=0

  output="$("${cmd[@]}" 2>&1)" || rc=$?

  if [ "$rc" -ne 0 ]; then
    echo "::error file=$f::Mermaid render failed (exit code $rc)"
    echo "----- Mermaid Output Begin -----"
    echo "$output"
    echo "----- Mermaid Output End -----"
    return 1
  fi

  if [ ! -f "$out" ]; then
    echo "::error file=$f::Mermaid finished successfully but output file not found."
    echo "Expected file:"
    echo "  $out"
    echo "Directory contents:"
    ls -la "$DIAGRAMS_DIR" || true
    return 1
  fi

  if [ "$DEBUG" = "true" ]; then
    echo "$output"
    echo "Generated: $out"
    ls -lh "$out"
  fi
}

ensure_plantuml_jar() {
  if [ -f "$PLANTUML_JAR" ] && [ -n "$PLANTUML_JAR_SHA256" ]; then
    echo "$PLANTUML_JAR_SHA256  $PLANTUML_JAR" | sha256sum --check --status || rm -f "$PLANTUML_JAR"
  fi

  if [ ! -f "$PLANTUML_JAR" ]; then
    mkdir -p "$(dirname "$PLANTUML_JAR")" || true
    echo "Downloading PlantUML jar to $PLANTUML_JAR..."
    if ! curl -fsSL -o "$PLANTUML_JAR" "$PLANTUML_JAR_URL"; then
      echo "::warning::Failed to download PlantUML jar from $PLANTUML_JAR_URL"
      return 1
    fi
  fi

  if [ -n "$PLANTUML_JAR_SHA256" ] && \
     ! echo "$PLANTUML_JAR_SHA256  $PLANTUML_JAR" | sha256sum --check --status; then
    echo "::error::PlantUML jar checksum does not match"
    rm -f "$PLANTUML_JAR"
    return 1
  fi
  return 0
}

render_plantuml() {
  local f="$1"
  f="${f//$'\r'/}"

  local base_noext
  base_noext=$(basename "$f")

  local base
  base="${base_noext%.*}"

  local dir
  dir=$(dirname "$f")

  local out="$DIAGRAMS_DIR/${base}.png"

  echo "PlantUML: '$f' -> '$out'"

  if ! ensure_plantuml_jar; then
    echo "::error file=$f::PlantUML jar download failed."
    return 1
  fi

  local cmd=(
    java
    -jar
    "$PLANTUML_JAR"
    -tpng
    -charset
    UTF-8
    -o
    "$DIAGRAMS_DIR_ABS"
    "$f"
  )

  if [ "$DEBUG" = "true" ]; then
    echo "Running command:"
    printf ' %q' "${cmd[@]}"
    echo
  fi

  local output
  local rc=0

  output="$("${cmd[@]}" 2>&1)" || rc=$?

  if [ "$rc" -ne 0 ]; then
    echo "::error file=$f::PlantUML render failed (exit code $rc)"
    echo "----- PlantUML Output Begin -----"
    echo "$output"
    echo "----- PlantUML Output End -----"

    local fallback="$dir/${base}.png"
    if [ -f "$fallback" ]; then
      mv "$fallback" "$out" || true
      return 0
    fi

    return 1
  fi

  if [ ! -f "$out" ]; then
    local candidate
    candidate="$(find "$dir" -maxdepth 1 -type f -name "${base}.png" -print -quit || true)"

    if [ -n "$candidate" ]; then
      mv "$candidate" "$out" || true
      echo "Moved generated file $candidate -> $out"
    else
      echo "::error file=$f::PlantUML rendering reported success but output not found at $out"
      return 1
    fi
  fi

  if [ "$DEBUG" = "true" ]; then
    echo "$output"
  fi
}

has_plantuml_variant() {
  local dir="$1"
  local base="$2"

  [ -f "$dir/${base}.plantuml" ] && return 0
  [ -f "$dir/${base}.puml" ] && return 0
  [ -f "$dir/${base}.uml" ] && return 0
  return 1
}

output_for_source() {
  local source="$1"
  local filename
  filename=$(basename "$source")
  printf '%s/%s.png\n' "$DIAGRAMS_DIR" "${filename%.*}"
}

hash_diagram() {
  local source="$1"
  local renderer_version

  case "$source" in
    *.mmd) renderer_version="mermaid:${MERMAID_CLI_VERSION:-11}" ;;
    *) renderer_version="plantuml:${PLANTUML_JAR_SHA256:-${PLANTUML_JAR_URL}}:$("${GRAPHVIZ_DOT:-dot}" -V 2>&1)" ;;
  esac

  {
    printf '%s\n' "$renderer_version"
    sha256sum "$0" | cut -d ' ' -f 1
    cat "$source"
  } | sha256sum | cut -d ' ' -f 1
}

previous_hash_for() {
  local source="$1"
  [ -f "$HASH_MANIFEST" ] || return 0
  awk -F '\t' -v source="$source" '$2 == source { print $1; exit }' "$HASH_MANIFEST"
}

record_hash() {
  printf '%s\t%s\n' "$2" "$1" >> "$NEW_HASH_MANIFEST"
}

render_if_changed() {
  local source="$1"
  local current_hash previous_hash output
  current_hash=$(hash_diagram "$source")
  previous_hash=$(previous_hash_for "$source")
  output=$(output_for_source "$source")

  if [ "$FORCE_ALL" != "true" ] && [ "$current_hash" = "$previous_hash" ] && [ -s "$output" ]; then
    echo "Unchanged: '$source'"
    record_hash "$source" "$current_hash"
    return 0
  fi

  case "$source" in
    *.mmd) render_mermaid "$source" ;;
    *.plantuml|*.puml|*.uml) render_plantuml "$source" ;;
  esac
  record_hash "$source" "$current_hash"
}

remove_orphaned_outputs() {
  [ -f "$HASH_MANIFEST" ] || return 0

  while IFS=$'\t' read -r _ source || [ -n "${source:-}" ]; do
    [ -n "${source:-}" ] || continue
    [ -f "$source" ] && continue

    local filename base output replacement
    filename=$(basename "$source")
    base="${filename%.*}"
    output="$DIAGRAMS_DIR/${base}.png"
    replacement=$(git ls-files -- "*${base}.mmd" "*${base}.plantuml" "*${base}.puml" "*${base}.uml" | sed -n '1p')
    if [ -z "$replacement" ] && [ -f "$output" ]; then
      echo "Removing output whose source was deleted: '$output'"
      rm -f "$output"
    fi
  done < "$HASH_MANIFEST"
}

render_diagrams() {
  echo "Scanning repository and comparing diagram hashes..."
  git ls-files -z -- '*.mmd' '*.plantuml' '*.puml' '*.uml' |
    sort -z |
    while IFS= read -r -d '' source; do
      case "$source" in
        *.mmd)
          dir=$(dirname "$source")
          base=$(basename "$source" .mmd)
          if has_plantuml_variant "$dir" "$base"; then
            echo "::debug::Skipping '$source' because a PlantUML variant exists (prefer PlantUML)"
            continue
          fi
          ;;
      esac
      render_if_changed "$source"
    done
}

render_diagrams
remove_orphaned_outputs
mv "$NEW_HASH_MANIFEST" "$HASH_MANIFEST"

echo "Done. Rendered files in: $DIAGRAMS_DIR"
ls -la "$DIAGRAMS_DIR" || true
echo "::endgroup::"

rm -f "$PUPPETEER_CONFIG"
