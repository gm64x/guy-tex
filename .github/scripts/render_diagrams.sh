#!/bin/bash
set -euo pipefail

# Inputs
DIAGRAMS_DIR="${1:-imagens/diagrams}"
CHANGED_FILES_LIST="${2:-.changed_files_list}"

mkdir -p "$DIAGRAMS_DIR"

# Create a puppeteer config to bypass sandbox issues in Linux CI
PUPPETEER_CONFIG="/tmp/puppeteer-config.json"
echo '{"args": ["--no-sandbox", "--disable-setuid-sandbox"]}' > "$PUPPETEER_CONFIG"

echo "::group::Mermaid Rendering"
echo "Rendering Mermaid files to: $DIAGRAMS_DIR"

render_file() {
  local f="$1"
  local base
  base=$(basename "$f" .mmd)
  local out="$DIAGRAMS_DIR/${base}.png"

  echo "Process: '$f' -> '$out'"
  # Use the puppeteer config file with the -p flag
  if ! npx -y @mermaid-js/mermaid-cli@9 -i "$f" -o "$out" --quiet -p "$PUPPETEER_CONFIG"; then
    echo "::warning file=$f::Failed to render Mermaid diagram. Skipping."
    return 0
  fi
}

if [ -s "$CHANGED_FILES_LIST" ]; then
  echo "Using detected changed files list..."
  while IFS= read -r f; do
    [[ -z "$f" || ! "$f" == *.mmd ]] && continue
    if [[ -f "$f" ]]; then
      render_file "$f"
    else
      echo "::debug::Skipping deleted or missing file: $f"
    fi
  done < "$CHANGED_FILES_LIST"
else
  echo "No changed file list available; scanning for all .mmd files..."
  find . -maxdepth 4 -name "*.mmd" -print0 | while IFS= read -r -d '' f; do
    render_file "$f"
  done
fi

echo "::endgroup::"
rm -f "$PUPPETEER_CONFIG"
