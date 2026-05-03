#!/usr/bin/env bash
# backup.sh — ha --backup / ha --restore implementation
# Sourced by ha.sh after lib.sh is loaded.

# ── Constants ──
BACKUP_DIR="$PROJECT_DIR/backup"
BACKUP_SCHEMA_VERSION=1

# ── Helpers ──

# ISO-8601-ish timestamp safe for filenames (colons replaced with dashes)
_backup_timestamp() {
    date -u +"%Y-%m-%dT%H-%M-%S.000Z"
}

# Detect which platform owns a backup by inspecting its manifest.json.
_detect_backup_platform() {
    local archive="$1"

    local manifest
    manifest=$(gzip -dc "$archive" 2>/dev/null \
        | tar -xf - --wildcards "*/manifest.json" -O 2>/dev/null \
        | head -c 65536)

    if [ -z "$manifest" ]; then
        echo ""
        return 1
    fi

    if echo "$manifest" | grep -q '"hermes-agent"'; then
        echo "hermes-agent"
        return 0
    fi
    if echo "$manifest" | grep -q '\.hermes'; then
        echo "hermes-agent"
        return 0
    fi

    echo ""
    return 1
}

# ── cmd_backup ──────────────────────────────────────────────────────────────

cmd_backup() {
    if ! command -v gzip &>/dev/null; then
        echo "  Installing gzip..."
        pkg install -y gzip 2>/dev/null \
            || { echo -e "${RED}[FAIL]${NC} gzip not found and could not be installed"; exit 1; }
    fi

    local output_dir="${1:-$BACKUP_DIR}"

    echo ""
    echo -e "${BOLD}Hermes on Android — Backup${NC}"
    echo -e "────────────────────────────────────────"

    local platform
    platform=$(detect_platform 2>/dev/null) || platform=""

    if [ -z "$platform" ]; then
        echo -e "${RED}[FAIL]${NC} Could not detect installed platform."
        exit 1
    fi

    load_platform_config "$platform" "$PROJECT_DIR" 2>/dev/null || {
        echo -e "${RED}[FAIL]${NC} Could not load platform config for: $platform"
        exit 1
    }

    local data_dir="$PLATFORM_DATA_DIR"

    if [ ! -d "$data_dir" ]; then
        echo -e "${RED}[FAIL]${NC} Platform data directory not found: $data_dir"
        echo "       Run 'hermes setup' first to create it."
        exit 1
    fi

    echo "  Platform:    $platform"
    echo "  Source:      $data_dir"
    echo "  Destination: $output_dir"
    echo ""

    mkdir -p "$output_dir"

    local ts
    ts=$(_backup_timestamp)
    local basename="${ts}-hermes-backup"
    local archive_filename="${basename}.tar.gz"
    local archive_path="$output_dir/$archive_filename"

    local tmpdir
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/ha-backup.XXXXXX")
    trap 'rm -rf "'"$tmpdir"'"' EXIT

    local staging="$tmpdir/$basename"
    local payload_dir="$staging/payload"
    mkdir -p "$payload_dir"

    echo "Collecting files..."
    # Copy entire ~/.hermes/ tree — config, memory, skills, sessions, gateway state.
    cp -a "$data_dir/." "$payload_dir/"

    # Generate manifest.json
    local hermes_version
    hermes_version=$(hermes --version 2>/dev/null || echo "unknown")

    cat > "$staging/manifest.json" <<MANIFEST_EOF
{
  "schemaVersion": $BACKUP_SCHEMA_VERSION,
  "createdAt": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")",
  "archiveRoot": "$basename",
  "platform": "hermes-agent",
  "platformVersion": "$hermes_version",
  "sourcePath": "$data_dir"
}
MANIFEST_EOF

    echo "Packing archive..."
    if ! tar -cf - -C "$tmpdir" "$basename" | gzip > "$archive_path"; then
        echo -e "${RED}[FAIL]${NC} Failed to create archive: $archive_path"
        exit 1
    fi

    echo -e "${GREEN}[OK]${NC}   Archive created: $archive_path"
    echo ""

    echo "Verifying integrity..."
    local file_count
    file_count=$(gzip -dc "$archive_path" 2>/dev/null | tar -tf - 2>/dev/null | wc -l)
    if [ "$file_count" -gt 0 ]; then
        echo -e "${GREEN}[OK]${NC}   Integrity check passed ($file_count entries)"
    else
        echo -e "${RED}[FAIL]${NC} Integrity check failed — archive may be corrupt"
        exit 1
    fi

    echo ""
    echo -e "${GREEN}Backup complete.${NC}"
    echo "  File: $archive_path"
    echo "  Size: $(du -sh "$archive_path" | cut -f1)"
    echo ""
}

# ── cmd_restore ─────────────────────────────────────────────────────────────

cmd_restore() {
    if ! command -v gzip &>/dev/null; then
        echo "  Installing gzip..."
        pkg install -y gzip 2>/dev/null \
            || { echo -e "${RED}[FAIL]${NC} gzip not found and could not be installed"; exit 1; }
    fi

    echo ""
    echo -e "${BOLD}Hermes on Android — Restore${NC}"
    echo -e "────────────────────────────────────────"

    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${RED}[FAIL]${NC} Backup directory not found: $BACKUP_DIR"
        echo -e "       Run ${BOLD}ha --backup${NC} first."
        exit 1
    fi

    local -a backups=()
    while IFS= read -r f; do
        backups+=("$f")
    done < <(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null)

    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}[FAIL]${NC} No backup files found in $BACKUP_DIR"
        echo -e "       Run ${BOLD}ha --backup${NC} first."
        exit 1
    fi

    echo "Available backups:"
    echo ""
    local idx=1
    for f in "${backups[@]}"; do
        local fname size
        fname=$(basename "$f")
        size=$(du -sh "$f" 2>/dev/null | cut -f1)
        printf "  ${BOLD}[%d]${NC} %s  ${YELLOW}(%s)${NC}\n" "$idx" "$fname" "$size"
        idx=$((idx + 1))
    done

    echo ""
    local choice
    if (echo -n "" > /dev/tty) 2>/dev/null; then
        read -rp "Select backup to restore [1-${#backups[@]}]: " choice < /dev/tty
    else
        read -rp "Select backup to restore [1-${#backups[@]}]: " choice
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#backups[@]}" ]; then
        echo -e "${RED}[FAIL]${NC} Invalid selection: $choice"
        exit 1
    fi

    local selected="${backups[$((choice - 1))]}"
    echo ""
    echo -e "  Selected: ${BOLD}$(basename "$selected")${NC}"

    echo "  Detecting platform..."
    local platform
    platform=$(_detect_backup_platform "$selected")

    if [ -z "$platform" ]; then
        echo -e "${YELLOW}[WARN]${NC} Could not determine backup platform — assuming hermes-agent"
        platform="hermes-agent"
    fi

    local restore_root="$HOME/.hermes"
    echo "  Platform:    $platform"
    echo "  Restore to:  $restore_root"
    echo ""

    echo -e "${YELLOW}WARNING: This will overwrite your current configuration in $restore_root${NC}"
    echo ""

    if ! ask_yn "Continue with restore?"; then
        echo "Restore cancelled."
        exit 0
    fi

    echo ""
    echo "Restoring..."

    local archive_root
    archive_root=$(gzip -dc "$selected" 2>/dev/null \
        | tar -xf - --wildcards "*/manifest.json" -O 2>/dev/null \
        | grep '"archiveRoot"' \
        | sed 's/.*"archiveRoot"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

    if [ -z "$archive_root" ]; then
        echo -e "${RED}[FAIL]${NC} Could not read archiveRoot from manifest."
        exit 1
    fi

    mkdir -p "$restore_root"

    if ! gzip -dc "$selected" 2>/dev/null | tar -xf - \
        --strip-components=2 \
        --exclude="${archive_root}/manifest.json" \
        -C "$restore_root" \
        "${archive_root}/payload/" 2>/dev/null; then
        echo -e "${RED}[FAIL]${NC} Extraction failed."
        exit 1
    fi

    echo -e "${GREEN}[OK]${NC}   Restore complete."
    echo ""
    echo "  Restored to: $restore_root"
    echo ""
    echo -e "${YELLOW}[NOTE]${NC} Restart any running 'hermes gateway' for changes to take effect."
    echo ""
}
