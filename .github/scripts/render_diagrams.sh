#!/usr/bin/env bash
set -euo pipefail

DEBUG="${DEBUG:-false}"

DIAGRAMS_DIR="${1:-imagens/diagrams}"
CHANGED_FILES_LIST="${2:-.changed_files_list}"

mkdir -p "$DIAGRAMS_DIR"
DIAGRAMS_DIR_ABS="$(cd "$DIAGRAMS_DIR" && pwd -P)"

PUPPETEER_CONFIG="/tmp/puppeteer-config.json"
printf '%s' '{"args":["--no-sandbox","--disable-setuid-sandbox"]}' > "$PUPPETEER_CONFIG"

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

    command -v node >/dev/null && echo "Node: $(node --version)"
    command -v npm >/dev/null && echo "NPM: $(npm --version)"
    command -v npx >/dev/null && echo "NPX: $(npx --version)"
    command -v java >/dev/null && java -version
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
    if [ ! -f "$PLANTUML_JAR" ]; then
        mkdir -p "$(dirname "$PLANTUML_JAR")"

        echo "Downloading PlantUML jar to $PLANTUML_JAR..."

        curl -fsSL \
            -o "$PLANTUML_JAR" \
            "$PLANTUML_JAR_URL"
    fi
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

    ensure_plantuml_jar

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

    local output
    local rc=0

    output="$("${cmd[@]}" 2>&1)" || rc=$?

    if [ "$rc" -ne 0 ]; then
        echo "::error file=$f::PlantUML render failed"

        echo "$output"

        local fallback="$dir/${base}.png"

        if [ -f "$fallback" ]; then
            mv "$fallback" "$out"
            return 0
        fi

        return 1
    fi

    if [ ! -f "$out" ]; then
        local candidate

        candidate="$(find "$dir" -maxdepth 1 -type f -name "${base}.png" -print -quit || true)"

        if [ -n "$candidate" ]; then
            mv "$candidate" "$out"
        else
            echo "::error file=$f::Output PNG not found after PlantUML execution"
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

render_all_diagrams() {
    echo "Scanning repository for diagrams..."

    find . -maxdepth 6 \
        \( \
        -name "*.mmd" \
        -o -name "*.plantuml" \
        -o -name "*.puml" \
        -o -name "*.uml" \
        \) \
        -print0 |
        while IFS= read -r -d '' f; do
            case "$f" in
            *.mmd)
                dir=$(dirname "$f")
                base=$(basename "$f" .mmd)

                if has_plantuml_variant "$dir" "$base"; then
                    echo "Skipping Mermaid '$f' because PlantUML variant exists."
                    continue
                fi

                render_mermaid "$f"
                ;;
            *.plantuml | *.puml | *.uml)
                render_plantuml "$f"
                ;;
            esac
        done
}

if [ -s "$CHANGED_FILES_LIST" ] &&
    grep -Eq '\.(mmd|plantuml|puml|uml)$' "$CHANGED_FILES_LIST"; then

    echo "Using changed files list: $CHANGED_FILES_LIST"

    while IFS= read -r f || [ -n "$f" ]; do

        f="${f//$'\r'/}"

        [ -z "$f" ] && continue

        case "$f" in
        *.mmd)
            dir=$(dirname "$f")
            base=$(basename "$f" .mmd)

            if has_plantuml_variant "$dir" "$base"; then
                continue
            fi

            [ -f "$f" ] && render_mermaid "$f"
            ;;
        *.plantuml | *.puml | *.uml)
            [ -f "$f" ] && render_plantuml "$f"
            ;;
        esac

    done <"$CHANGED_FILES_LIST"

else
    echo "No diagram files in changed list; rendering all diagrams."
    render_all_diagrams
fi

echo
echo "Generated files:"
ls -la "$DIAGRAMS_DIR" || true

echo "::endgroup::"

rm -f "$PUPPETEER_CONFIG"
