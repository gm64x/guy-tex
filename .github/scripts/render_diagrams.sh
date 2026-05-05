#!/bin/bash
set -euo pipefail

# Inputs
DIAGRAMS_DIR="${1:-imagens/diagrams}"
CHANGED_FILES_LIST="${2:-.changed_files_list}"

mkdir -p "$DIAGRAMS_DIR"

# Create a puppeteer config to bypass sandbox issues in Linux CI
PUPPETEER_CONFIG="/tmp/puppeteer-config.json"
echo '{"args": ["--no-sandbox", "--disable-setuid-sandbox"]}' > "$PUPPETEER_CONFIG"

PLANTUML_JAR="${PLANTUML_JAR:-/tmp/plantuml.jar}"
PLANTUML_JAR_URL="${PLANTUML_JAR_URL:-https://github.com/plantuml/plantuml/releases/latest/download/plantuml.jar}"

echo "::group::Diagram Rendering"
echo "Rendering diagrams to: $DIAGRAMS_DIR"

render_mermaid() {
  local f="$1"
  local base
  base=$(basename "$f" .mmd)
  local out="$DIAGRAMS_DIR/${base}.png"

  echo "Process: '$f' -> '$out'"
  # Use the version from env or default to 9
  local version="${MERMAID_CLI_VERSION:-9}"
  if ! npx -y "@mermaid-js/mermaid-cli@$version" -i "$f" -o "$out" --quiet -p "$PUPPETEER_CONFIG"; then
    echo "::warning file=$f::Failed to render Mermaid diagram. Skipping."
    return 0
  fi
}

render_plantuml() {
  local f="$1"
  local base
  base=$(basename "$f" .plantuml)
  local out="$DIAGRAMS_DIR/${base}.png"

  echo "Process: '$f' -> '$out'"

  if [ ! -f "$PLANTUML_JAR" ]; then
    echo "Downloading PlantUML jar to $PLANTUML_JAR..."
    if ! curl -sSL -o "$PLANTUML_JAR" "$PLANTUML_JAR_URL"; then
      echo "::warning file=$f::Failed to download PlantUML. Skipping."
      return 0
    fi
  fi

  if ! java -jar "$PLANTUML_JAR" -tpng -charset UTF-8 -o "$DIAGRAMS_DIR" "$f" >/dev/null 2>&1; then
    echo "::warning file=$f::Failed to render PlantUML diagram. Skipping."
    return 0
  fi
}

if [ -s "$CHANGED_FILES_LIST" ]; then
  echo "Using detected changed files list..."
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue

    case "$f" in
      *.mmd)
        # If a PlantUML file with the same base exists, prefer it and skip the .mmd
        base=$(basename "$f" .mmd)
        dir=$(dirname "$f")
        if [ -f "$dir/${base}.plantuml" ]; then
          echo "::debug::Skipping '$f' because '$dir/${base}.plantuml' exists (prefer PlantUML)"
          continue
        fi
        if [[ -f "$f" ]]; then
          render_mermaid "$f"
        else
          echo "::debug::Skipping deleted or missing file: $f"
        fi
        ;;
      *.plantuml)
        if [[ -f "$f" ]]; then
          render_plantuml "$f"
        else
          echo "::debug::Skipping deleted or missing file: $f"
        fi
        ;;
      *)
        ;;
    esac
  done < "$CHANGED_FILES_LIST"
else
  echo "No changed file list available; scanning for all .mmd and .plantuml files..."
  find . -maxdepth 4 \( -name "*.mmd" -o -name "*.plantuml" \) -print0 | while IFS= read -r -d '' f; do
    case "$f" in
      *.mmd)
        base=$(basename "$f" .mmd)
        dir=$(dirname "$f")
        if [ -f "$dir/${base}.plantuml" ]; then
          echo "::debug::Skipping '$f' because '$dir/${base}.plantuml' exists (prefer PlantUML)"
          continue
        fi
        render_mermaid "$f"
        ;;
      *.plantuml)
        render_plantuml "$f"
        ;;
    esac
  done
fi

echo "::endgroup::"
rm -f "$PUPPETEER_CONFIG"
