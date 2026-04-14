#!/bin/bash
# bhkey v1.0.1: Zero-Latency Keyboard Remapper for macOS External Keyboards
#
# Anti-Thesis Guards:
#   1. Detect macOS modifier key defaults conflicts
#   2. Prevent Karabiner/iCUE process conflicts
#   3. Protect Magic Keyboard / Built-In keyboard
#   4. Handle hidutil execution failure
#   5. Handle LaunchAgent plist creation/load errors
#   6. Verify mapping applied after hidutil --set (silent fail guard, macOS 14.2+)

set -eu

PLIST_NAME="com.bh.keymapping"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
BHKEY_VERSION="1.0.1"
NO_PROMPT=false

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[bhkey]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[bhkey WARN]${NC} $1"; }
log_error() { echo -e "${RED}[bhkey ERROR]${NC} $1" >&2; }

# =============================================================
# Anti-Thesis #1: Detect macOS system preferences modifier key conflicts
# =============================================================
check_macos_modifier_defaults() {
    # defaults does not support wildcards
    # read entire global domain and find modifiermapping keys with grep
    local all_modifier_keys
    all_modifier_keys=$(defaults -currentHost read -g 2>/dev/null \
        | /usr/bin/grep "com.apple.keyboard.modifiermapping" || true)

    if [[ -z "$all_modifier_keys" ]]; then
        return 0
    fi

    # If external keyboard detected, check only that device's modifier settings
    # Key format: com.apple.keyboard.modifiermapping.{VendorID_dec}-{ProductID_dec}-0
    local devices
    devices=$(detect_device)

    local conflicting_devices=()
    if [[ -n "$devices" ]]; then
        while IFS=' ' read -r vid pid; do
            local vid_dec pid_dec
            vid_dec=$((vid))
            pid_dec=$((pid))
            local key_name="com.apple.keyboard.modifiermapping.${vid_dec}-${pid_dec}-0"
            if echo "$all_modifier_keys" | /usr/bin/grep -q "${vid_dec}-${pid_dec}"; then
                # Even if key exists, Src==Dst (identity mapping) means no actual change
                # macOS sets Src=Dst instead of deleting key on "Restore Defaults"
                local has_real_mapping=false
                local mapping_data
                mapping_data=$(defaults -currentHost read -g "$key_name" 2>/dev/null || true)
                if [[ -n "$mapping_data" ]]; then
                    # Check if there is at least one mapping where Src != Dst
                    local srcs dsts
                    srcs=$(echo "$mapping_data" | /usr/bin/grep "MappingSrc" | /usr/bin/grep -o '[0-9]*')
                    dsts=$(echo "$mapping_data" | /usr/bin/grep "MappingDst" | /usr/bin/grep -o '[0-9]*')
                    { paste <(echo "$srcs") <(echo "$dsts") | while IFS=$'\t' read -r s d; do
                        if [[ "$s" != "$d" ]]; then
                            echo "CONFLICT"
                            break
                        fi
                    done | /usr/bin/grep -q "CONFLICT" && has_real_mapping=true; } || true
                fi

                if [[ "$has_real_mapping" == true ]]; then
                    local name
                    name=$(get_device_name "$vid" "$pid")
                    conflicting_devices+=("${name:-$vid/$pid} (${vid_dec}-${pid_dec})")
                fi
            fi
        done <<< "$devices"
    fi

    # Also check built-in keyboard modifier settings
    local builtin_keys
    builtin_keys=$(echo "$all_modifier_keys" | /usr/bin/grep -v "$(
        if [[ -n "$devices" ]]; then
            while IFS=' ' read -r vid pid; do
                echo -n "\\|$((vid))-$((pid))"
            done <<< "$devices"
        fi
    )" || true)

    if [[ ${#conflicting_devices[@]} -gt 0 ]]; then
        log_warn "The following devices have modifier key changes in macOS System Settings:"
        for dev in "${conflicting_devices[@]}"; do
            log_warn "  - $dev"
        done
        log_warn ""
        log_warn "Double-mapping conflict with bhkey will occur."
        log_warn "Go to System Settings > Keyboard > Keyboard Shortcuts > Modifier Keys, select the device and click 'Restore Defaults', then try again."
        echo ""
        if [[ "$NO_PROMPT" == true ]]; then
            log_warn "Non-interactive mode: proceeding automatically"
        else
            read -rp "Proceed anyway? (y/N): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                log_info "Aborted. Restore System Settings first."
                exit 1
            fi
        fi
        log_warn "Proceeding with user confirmation."
    elif [[ -n "$builtin_keys" ]]; then
        log_info "Built-in keyboard modifier settings detected, but unrelated to external keyboard. Continuing."
    fi
}

# =============================================================
# Anti-Thesis #2: Prevent Karabiner / iCUE process conflicts
# =============================================================
check_conflicting_processes() {
    local conflicts=()

    if pgrep -q "karabiner" 2>/dev/null; then
        conflicts+=("Karabiner-Elements")
    fi
    if pgrep -qi "icue" 2>/dev/null; then
        conflicts+=("Corsair iCUE")
    fi

    if [[ ${#conflicts[@]} -gt 0 ]]; then
        log_error "Conflicting processes found: ${conflicts[*]}"
        log_error "These programs may conflict with bhkey if they perform key remapping."
        echo ""
        if [[ "$NO_PROMPT" == true ]]; then
            log_warn "Non-interactive mode: proceeding automatically"
        else
            read -rp "Ignore these processes and proceed? (y/N): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                log_info "Aborted. Quit the conflicting processes and try again."
                exit 1
            fi
        fi
        log_warn "Proceeding with user confirmation."
    fi
}

# =============================================================
# Anti-Thesis #3: Detect external keyboard (protect Built-In keyboard)
# =============================================================
detect_device() {
    # hidutil list column structure:
    #   VendorID ProductID LocationID UsagePage Usage RegistryID Transport Class Product UserClass Built-In
    # Conditions:
    #   - rows containing "Keyboard" (in Product name)
    #   - Built-In = 0 (last field, external devices only)
    #   - VendorID != 0x0 (real devices only)
    # Output: "VendorID ProductID" (per line, unique pairs)

    local result
    result=$(hidutil list 2>/dev/null | awk '
        NR > 2 && /[Kk]eyboard/ && $NF == "0" && $1 != "0x0" {
            key = $1 SUBSEP $2
            if (!seen[key]++) print $1, $2
        }
    ')

    echo "$result"
}

get_device_name() {
    # Extract Product name from hidutil list by VendorID, ProductID
    # Dynamically calculate header "Product" column position for reliable extraction
    local vid="$1" pid="$2"
    hidutil list 2>/dev/null | awk -v vid="$vid" -v pid="$pid" '
        NR == 2 {
            # Extract Product/UserClass column start position from header
            # "Product" appears twice — the last one is the Product name column
            p = 0
            while ((i = index(substr($0, p+1), "Product")) > 0) p += i
            prod_start = p
            user_start = index($0, "UserClass")
        }
        NR > 2 && $1 == vid && $2 == pid && /[Kk]eyboard/ && $NF == "0" {
            name = substr($0, prod_start, user_start - prod_start)
            gsub(/^[ ]+|[ ]+$/, "", name)
            print name
            exit
        }
    '
}

# =============================================================
# Key Mapping Definition
# =============================================================
# Left Option <-> Left Command (Alt/Win swap for Windows keyboards)
# Right Alt -> Right Command
# Right Win -> F19 (voice input trigger)
# Han/Eng Key (0x90) -> F18 (input source switch)
build_mapping_json() {
    cat <<'MAPPING'
{"UserKeyMapping":[
    {"HIDKeyboardModifierMappingSrc":0x7000000e2,"HIDKeyboardModifierMappingDst":0x7000000e3},
    {"HIDKeyboardModifierMappingSrc":0x7000000e3,"HIDKeyboardModifierMappingDst":0x7000000e2},
    {"HIDKeyboardModifierMappingSrc":0x7000000e6,"HIDKeyboardModifierMappingDst":0x7000000e7},
    {"HIDKeyboardModifierMappingSrc":0x7000000e7,"HIDKeyboardModifierMappingDst":0x70000006e},
    {"HIDKeyboardModifierMappingSrc":0x700000090,"HIDKeyboardModifierMappingDst":0x70000006d},
    {"HIDKeyboardModifierMappingSrc":0x700000091,"HIDKeyboardModifierMappingDst":0x70000006e}
]}
MAPPING
}

# =============================================================
# Apply
# =============================================================
apply() {
    # Idempotency guard: skip if already mapped in non-interactive mode
    if [[ "$NO_PROMPT" == true ]]; then
        local guard_devices
        guard_devices=$(detect_device)
        if [[ -n "$guard_devices" ]]; then
            local already_mapped=true
            while IFS=' ' read -r vid pid; do
                local check
                check=$(hidutil property --matching "{\"VendorID\":$vid,\"ProductID\":$pid}" --get UserKeyMapping 2>/dev/null || true)
                if ! echo "$check" | /usr/bin/grep -q "MappingSrc"; then
                    already_mapped=false
                    break
                fi
            done <<< "$guard_devices"
            if [[ "$already_mapped" == true ]]; then
                exit 0  # Already applied, exit silently
            fi
        fi
    fi

    log_info "bhkey v${BHKEY_VERSION} — Starting pre-flight checks..."
    echo ""

    # Anti-Thesis #1: Check macOS modifier conflicts
    check_macos_modifier_defaults

    # Anti-Thesis #2: Check conflicting processes
    check_conflicting_processes

    # Anti-Thesis #3: Detect external keyboard
    local devices
    devices=$(detect_device)

    if [[ -z "$devices" ]]; then
        log_warn "No external keyboard detected."
        log_warn "Applying mapping to built-in keyboard will change the default macOS layout."
        echo ""
        if [[ "$NO_PROMPT" == true ]]; then
            log_warn "Non-interactive mode: proceeding automatically"
        else
            read -rp "Proceed with global mapping (all keyboards)? (y/N): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                log_info "Aborted. Connect an external keyboard and try again."
                exit 1
            fi
        fi
        log_warn "Proceeding with global mapping (applies to all keyboards)."
    else
        log_info "Detected external keyboard(s):"
        while IFS=' ' read -r vid pid; do
            local name
            name=$(get_device_name "$vid" "$pid")
            echo -e "  ${CYAN}${name:-Unknown Keyboard}${NC} (VendorID: $vid, ProductID: $pid)"
        done <<< "$devices"
        echo ""
    fi

    local mapping
    mapping=$(build_mapping_json)

    # If external keyboards exist, target all devices via --matching
    if [[ -n "$devices" ]]; then
        while IFS=' ' read -r vid pid; do
            local name
            name=$(get_device_name "$vid" "$pid")
            log_info "Applying mapping... ${name:-$vid/$pid}"
            if ! hidutil property --matching "{\"VendorID\":$vid,\"ProductID\":$pid}" \
                --set "$mapping" >/dev/null 2>&1; then
                log_warn "Failed to apply mapping: ${name:-$vid/$pid}"
                if [[ $EUID -ne 0 ]]; then
                    log_warn "sudo may be required on macOS 14.2+: sudo bhkey apply"
                fi
            fi
            # Anti-Thesis #6: Verify mapping was actually applied (hidutil silent fail guard)
            local actual
            actual=$(hidutil property --matching "{\"VendorID\":$vid,\"ProductID\":$pid}" \
                --get UserKeyMapping 2>/dev/null || true)
            if ! echo "$actual" | /usr/bin/grep -q "MappingSrc"; then
                log_warn "Mapping not confirmed for ${name:-$vid/$pid}. Retrying..."
                sleep 1
                hidutil property --matching "{\"VendorID\":$vid,\"ProductID\":$pid}" \
                    --set "$mapping" >/dev/null 2>&1 || true
                actual=$(hidutil property --matching "{\"VendorID\":$vid,\"ProductID\":$pid}" \
                    --get UserKeyMapping 2>/dev/null || true)
                if ! echo "$actual" | /usr/bin/grep -q "MappingSrc"; then
                    log_error "Mapping verification failed after retry: ${name:-$vid/$pid}"
                    if [[ $EUID -ne 0 ]]; then
                        log_error "Try: sudo bhkey apply"
                    fi
                fi
            fi
        done <<< "$devices"
    else
        log_info "Applying global mapping..."
        if ! hidutil property --set "$mapping" >/dev/null 2>&1; then
            log_error "hidutil mapping failed."
            if [[ $EUID -ne 0 ]]; then
                log_error "sudo may be required on macOS 14.2+: sudo bhkey apply"
            fi
            exit 1
        fi
        # Anti-Thesis #6: Verify global mapping was actually applied
        local actual_global
        actual_global=$(hidutil property --get UserKeyMapping 2>/dev/null || true)
        if ! echo "$actual_global" | /usr/bin/grep -q "MappingSrc"; then
            log_warn "Global mapping not confirmed. Retrying..."
            sleep 1
            hidutil property --set "$mapping" >/dev/null 2>&1 || true
            actual_global=$(hidutil property --get UserKeyMapping 2>/dev/null || true)
            if ! echo "$actual_global" | /usr/bin/grep -q "MappingSrc"; then
                log_error "Global mapping verification failed after retry."
                if [[ $EUID -ne 0 ]]; then
                    log_error "Try: sudo bhkey apply"
                fi
            fi
        fi
    fi

    # Anti-Thesis #5: Create LaunchAgent plist
    local launch_agents_dir="$HOME/Library/LaunchAgents"
    if [[ ! -d "$launch_agents_dir" ]]; then
        mkdir -p "$launch_agents_dir" || {
            log_error "Failed to create LaunchAgents directory: $launch_agents_dir"
            exit 1
        }
    fi

    # Unload existing plist first
    if [[ -f "$PLIST_PATH" ]]; then
        launchctl bootout "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true
    fi

    # Record absolute path of bhkey.sh in plist (self-invocation)
    local bhkey_path
    bhkey_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

    local plist_args
    plist_args=$(cat <<PARGS
    <array>
        <string>/bin/bash</string>
        <string>$bhkey_path</string>
        <string>apply</string>
        <string>--no-prompt</string>
    </array>
PARGS
)

    cat <<PLIST > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
$plist_args
    <key>RunAtLoad</key>
    <true/>
    <key>LaunchEvents</key>
    <dict>
        <key>com.apple.iokit.matching</key>
        <dict>
            <key>hid-keyboard-attach</key>
            <dict>
                <key>IOProviderClass</key>
                <string>IOHIDDevice</string>
                <key>PrimaryUsagePage</key>
                <integer>1</integer>
                <key>PrimaryUsage</key>
                <integer>6</integer>
            </dict>
        </dict>
    </dict>
</dict>
</plist>
PLIST

    # plist syntax validation
    if ! plutil -lint "$PLIST_PATH" >/dev/null 2>&1; then
        log_error "plist syntax error. Check the file: $PLIST_PATH"
        rm -f "$PLIST_PATH"
        exit 1
    fi

    # Register LaunchAgent (bootout/bootstrap — load/unload is deprecated)
    if ! launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null; then
        # If already registered, restart with kickstart
        launchctl kickstart -k "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true
    fi

    echo ""
    log_info "bhkey v${BHKEY_VERSION} applied successfully!"
    log_info "Will auto-apply after reboot. (LaunchAgent: $PLIST_NAME)"
}

# =============================================================
# Reset
# =============================================================
reset() {
    log_info "Resetting bhkey..."

    # Unload LaunchAgent
    launchctl bootout "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true
    rm -f "$PLIST_PATH"

    # Reset per-device mapping for all detected external keyboards
    local devices
    devices=$(detect_device)
    if [[ -n "$devices" ]]; then
        while IFS=' ' read -r vid pid; do
            hidutil property --matching "{\"VendorID\":$vid,\"ProductID\":$pid}" \
                --set '{"UserKeyMapping":[]}' >/dev/null 2>&1 || true
        done <<< "$devices"
    fi

    # Also reset global mapping
    hidutil property --set '{"UserKeyMapping":[]}' >/dev/null 2>&1

    echo ""
    log_info "All key mappings have been reset."
}

# =============================================================
# Status
# =============================================================
status() {
    echo -e "${CYAN}=== bhkey v${BHKEY_VERSION} Status ===${NC}"
    echo ""

    # Detect external keyboards first (needed for mapping status display)
    echo -e "${GREEN}[External Keyboard]${NC}"
    local devices
    devices=$(detect_device)
    if [[ -z "$devices" ]]; then
        echo "  No external keyboard detected"
    else
        while IFS=' ' read -r vid pid; do
            local name
            name=$(get_device_name "$vid" "$pid")
            echo "  ${name:-Unknown Keyboard} (VendorID: $vid, ProductID: $pid)"
        done <<< "$devices"
    fi
    echo ""

    # Current mapping status — check both per-device and global mappings
    echo -e "${GREEN}[Current Mapping]${NC}"
    local has_mapping=false

    # Check per-device mapping (applied via --matching)
    if [[ -n "$devices" ]]; then
        while IFS=' ' read -r vid pid; do
            local per_device
            per_device=$(hidutil property --matching "{\"VendorID\":$vid,\"ProductID\":$pid}" --get UserKeyMapping 2>/dev/null || true)
            if [[ -n "$per_device" ]] && echo "$per_device" | /usr/bin/grep -q "MappingSrc"; then
                local name
                name=$(get_device_name "$vid" "$pid")
                local count
                count=$(echo "$per_device" | /usr/bin/grep -c "MappingSrc" || true)
                echo "  ${name:-$vid/$pid}: ${count} key mapping(s) active"
                has_mapping=true
            fi
        done <<< "$devices"
    fi

    # Check global mapping
    local global_mapping
    global_mapping=$(hidutil property --get UserKeyMapping 2>/dev/null)
    if [[ "$global_mapping" != "(null)" && -n "$global_mapping" ]] && echo "$global_mapping" | /usr/bin/grep -q "MappingSrc"; then
        local count
        count=$(echo "$global_mapping" | /usr/bin/grep -c "MappingSrc" || true)
        echo "  Global: ${count} key mapping(s) active"
        has_mapping=true
    fi

    if [[ "$has_mapping" == false ]]; then
        echo "  No mapping (default state)"
    fi
    echo ""

    # LaunchAgent status
    echo -e "${GREEN}[LaunchAgent]${NC}"
    if [[ -f "$PLIST_PATH" ]]; then
        echo "  plist: $PLIST_PATH (exists)"
        if launchctl print "gui/$(id -u)/$PLIST_NAME" >/dev/null 2>&1; then
            echo "  status: registered (auto-applies on reboot)"
        else
            echo "  status: plist exists but not registered"
        fi
    else
        echo "  plist: none"
    fi
    echo ""

    # Conflicting processes
    echo -e "${GREEN}[Conflicting Processes]${NC}"
    local has_conflict=false
    if pgrep -q "karabiner" 2>/dev/null; then
        echo "  Karabiner-Elements: running (may conflict)"
        has_conflict=true
    fi
    if pgrep -qi "icue" 2>/dev/null; then
        echo "  Corsair iCUE: running (may conflict)"
        has_conflict=true
    fi
    if [[ "$has_conflict" == false ]]; then
        echo "  No conflicting processes"
    fi
}

# =============================================================
# Main
# =============================================================
case "${1:-}" in
    apply)
        [[ "${2:-}" == "--no-prompt" ]] && NO_PROMPT=true
        apply
        ;;
    reset)  reset ;;
    status) status ;;
    version) echo "bhkey v${BHKEY_VERSION}" ;;
    *)
        echo "bhkey v${BHKEY_VERSION} — Zero-Latency Keyboard Bridge"
        echo ""
        echo "Usage: bhkey {apply|reset|status|version}"
        echo ""
        echo "  apply   — Apply key mapping (with anti-thesis checks)"
        echo "  reset   — Reset all mappings"
        echo "  status  — Show current status"
        echo "  version — Print version"
        ;;
esac
