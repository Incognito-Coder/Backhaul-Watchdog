#!/usr/bin/env bash

set -e
echo "Script by @Incognito_Coder - Alireza Ahmand && Arash Ariaye"
echo "Installing Backhaul Watchdog..."

INSTALL_PATH="/usr/local/bin/backhaul-watchdog.sh"
SERVICE_PATH="/etc/systemd/system/backhaul-watchdog.service"

# Create watchdog script
cat > "$INSTALL_PATH" << 'EOF'
#!/usr/bin/env bash

CONFIG_DIR="/root/backhaul-core"
COOLDOWN=30

# Log coloring
RED="\033[0;31m"
YELLOW="\033[0;33m"
GREEN="\033[0;32m"
NC="\033[0m" # No Color

log_info() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[INFO]${NC} $1"
}
log_warn() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}[WARN]${NC} $1"
}
log_error() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[ERROR]${NC} $1"
}

monitor_service() {
    FULL_SERVICE="$1"
    SERVICE="${FULL_SERVICE%.service}"
    NAME="${SERVICE#backhaul-}"
    TOML_FILE="${CONFIG_DIR}/${NAME}.toml"
    LOG_LINE="$2"

    if [[ ! -f "$TOML_FILE" ]]; then
           log_error "[$SERVICE] Config not found: $TOML_FILE"
        return
    fi

    if [[ "$LOG_LINE" == *"Heartbeat timeout — Status: 🔴 Disconnected"* || \
          "$LOG_LINE" == *"invalid packet received: not IPv4 packet"* ]]; then

          log_warn "[$SERVICE] Problem detected in log → $LOG_LINE"

        CURRENT_PROFILE=$(grep -E '^profile\s*=' "$TOML_FILE" | awk -F'"' '{print $2}')

        if [[ "$CURRENT_PROFILE" == "tcp" ]]; then
            NEW_PROFILE="bip"
        elif [[ "$CURRENT_PROFILE" == "bip" ]]; then
            NEW_PROFILE="tcp"
        else
                log_error "[$SERVICE] Unknown profile: $CURRENT_PROFILE → skipping"
            return
        fi

        log_info "[$SERVICE] Switching profile: $CURRENT_PROFILE → $NEW_PROFILE"

        sed -i "s/^profile\s*=\s*\"$CURRENT_PROFILE\"/profile = \"$NEW_PROFILE\"/" "$TOML_FILE"

        systemctl restart "$SERVICE"
            log_info "[$SERVICE] Restarted"

        sleep "$COOLDOWN"
    fi
}

SERVICES=$(systemctl list-units --type=service --no-legend \
    | awk '{print $1}' \
    | grep '^backhaul-' \
    | grep -v '^backhaul-watchdog\.service$')

for SERVICE in $SERVICES; do
    log_info "[$SERVICE] Monitoring logs in real time..."
    journalctl -u "$SERVICE" -f -o cat | while read -r LOG_LINE; do
        monitor_service "$SERVICE" "$LOG_LINE"
    done &
done
wait
EOF

chmod +x "$INSTALL_PATH"

# Create systemd service
cat > "$SERVICE_PATH" << EOF
[Unit]
Description=Backhaul Auto Profile Watchdog
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_PATH
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

# Reload and enable
systemctl daemon-reload
systemctl enable backhaul-watchdog
systemctl restart backhaul-watchdog

clear
echo
echo "Installation completed!"
echo "The Backhaul Watchdog is now running and will automatically switch profiles if a disconnection is detected."
echo "You can check its status with: systemctl status backhaul-watchdog"
echo "To view logs: journalctl -u backhaul-watchdog -f"
echo
