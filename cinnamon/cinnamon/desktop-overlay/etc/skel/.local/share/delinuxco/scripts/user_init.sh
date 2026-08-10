#!/bin/bash

# Exit on error, treat unset variables as error, fail on pipe errors
set -euo pipefail

# --- Configuration ---
MARKER_FILE="$HOME/.config/dlint_run_once.marker"
LOG_FILE="$HOME/.dlc_script_log"
SCRIPT_NAME="DeLinuxCo Setup Script"
AUTOSTART_FILE="$HOME/.config/autostart/UserConfig.desktop"
INIT_SCRIPT="$HOME/.user_init.sh"

# 🔑 UPDATE THESE WITH THE ACTUAL SHA256 HASHES OF YOUR GPG KEYS
DELINUXCO_KEY_SHA256="0000825e2ccc20c03c7073a8cb6bb6ec9a0f7ad5b62021844e1c13225e6386aa"
XLIBRE_KEY_SHA256="5611462e9ed938575d3b58427d96810697ed222acb13a18999956b7aded29594"

# Ensure config directory exists
mkdir -p "$(dirname "$MARKER_FILE")"

# Check for previous execution marker
if [ -f "$MARKER_FILE" ]; then
    echo "⚠️  Script has already been/is being run by this user. Exiting."
    exit 0
fi

# --- Functions ---

log_msg() {
    local msg="$1"
    printf '%b\n' "$msg" | tee -a "$LOG_FILE"
}

cleanup_and_exit() {
    local exit_code="${1:-0}"
    local reboot="${2:-false}"

    # 1. Create marker file to prevent re-execution
    touch "$MARKER_FILE"
    log_msg "✅ Setup completed. Marker file created."

    # 2. Remove the autostart file so it doesn't run on next boot
    if [ -f "$AUTOSTART_FILE" ]; then
        rm -f "$AUTOSTART_FILE"
        log_msg "🗑️  Autostart entry removed."
    fi

    # 3. Remove the setup script itself
    if [ -f "$INIT_SCRIPT" ]; then
        rm -f "$INIT_SCRIPT"
        log_msg "🗑️  Setup script ($INIT_SCRIPT) removed."
    fi

    if [ "$reboot" = true ]; then
        log_msg "🔄 Rebooting system now..."
        sync
        sudo shutdown -r now
    else
        # 4. Close the terminal window if not rebooting
        log_msg "👋 Closing terminal..."
        pkill mate-terminal || true
    fi

    exit "$exit_code"
}

check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log_msg "🔐 Sudo privileges required. Please enter your password:"
        sudo -v || { log_msg "❌ Error: Sudo authentication failed."; exit 1; }
    fi
}

check_internet() {
    local host="8.8.8.8"
    if ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
        log_msg "✅ Connected."
        return 0
    fi

    log_msg "\n❌ Internet connection not available (needed for GPG key verification)"
    read -rp "Do you want to wait 30 seconds and retry? (y/n): " wait_choice || true
    
    if [[ "$wait_choice" == [Yy]* ]]; then
        log_msg "⏳ Waiting 30 seconds and retrying..."
        sleep 30
        if ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
            log_msg "✅ Connected after waiting."
            return 0
        else
            log_msg "❌ Still no internet connection after waiting."
        fi
    fi

    read -rp "Continue without internet? (GPG verification will be skipped) [y/n]: " choice || true
    case "$choice" in
        [Yy]* ) 
            log_msg "⚠️  Proceeding offline. GPG and package updates may fail."
            return 0 
            ;;
        * )
            log_msg "❌ Exiting setup per user request."
            exit 1 
            ;;
    esac
}

is_installed() {
    [ -f "/etc/pacman.conf" ] && [ ! -d "/run/miso/sfs/livefs" ]
}

fetch_and_verify() {
    local url="$1"
    local filename="$2"
    local expected_hash="$3"
    log_msg "📥 Downloading $filename..."
    if curl -sL --fail -o "$filename" "$url"; then
        if [ -s "$filename" ]; then
            local actual_hash
            actual_hash=$(sha256sum "$filename" | awk '{print $1}')
            if [[ "$actual_hash" == "$expected_hash" ]]; then
                log_msg "✅ Downloaded & verified: $filename ($(wc -c < "$filename") bytes)"
                return 0
            else
                log_msg "❌ Hash mismatch for $filename!"
                rm -f "$filename"
                return 1
            fi
        else
            log_msg "⚠️  Downloaded file is empty. Skipping..."
            rm -f "$filename"
            return 1
        fi
    else
        log_msg "⚠️  Could not download $filename. Skipping..."
        return 1
    fi
}

download_with_verification() {
    local url="$1"
    local filename="$2"
    if [[ "$url" == *"delinuxco"* ]]; then
        fetch_and_verify "$url" "$filename" "$DELINUXCO_KEY_SHA256"
    elif [[ "$url" == *"xlibre"* ]]; then
        fetch_and_verify "$url" "$filename" "$XLIBRE_KEY_SHA256"
    else
        log_msg "⚠️  Unknown key source: $url"
        return 1
    fi
}

# --- Execution Start ---

clear
cat << "EOF"
                                                                        
        .:----:.                        
       .-#+=-==+*+:                     
       .:*-     :+#*-                   
        .-*-       -**-    .:           
         .-**-       -int*.:*#:         
           .=#*-.      -*#*+-           
             .=#+:.     :=#+:           
               ...    .=*=**=.          
                      .=%+  -**-        
                      =%+.   .=*=.      
                     -%+.      :*=.     
                    -#*.        -*-.    
                   -#*.         .++:    
                  :#*:          .**:    
                 :##:            -#+.   
                -##:            -#*.    
             ..:++.        .:=*#+.      
   :===========+=--======++**+=:        
   :---------:::.::------::.            
EOF

echo
echo "Welcome to DeLinuxCo setup!" | tee "$LOG_FILE"
sleep 1

check_sudo
check_internet

echo -e "\nDeLinuxCO Automated Setup Script"
echo -e "This script requires internet access for GPG verification.\n"

if is_installed; then
    echo "✅ System appears to be an installed Arch-based Linux"
else
    echo "⚠️  This script was run on a Live/non-standard environment"
fi

# --- GPG Key Verification ---
echo "🔐 Verifying GPG keys..."
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# 1. DeLinuxCo Key Integration
KEY_FILE="$TEMP_DIR/delinuxco.gpg"
if download_with_verification "/usr/share/delinuxco/delinuxco-keyring/trusted/delinuxco.gpg" "$KEY_FILE"; then
    sudo pacman-key --add "$KEY_FILE" || echo "⚠️  Failed to add DeLinuxCo key."
    if sudo pacman-key --finger 9478dd4f27ea6a82 >/dev/null 2>&1; then
        sudo pacman-key --lsign-key 9478dd4f27ea6a82 || echo "⚠️  Could not sign DeLinuxCo key."
    fi
fi

# 2. XLibre Manjaro Key Integration 
KEY_FILE="$TEMP_DIR/xlibre-manjarolinux.asc"
if download_with_verification "https://xlibre-manjaro.github.io/xlibre-manjarolinux.asc" "$KEY_FILE"; then
    sudo pacman-key --add "$KEY_FILE" || echo "⚠️  Failed to add XLibre key."
    if sudo pacman-key --finger D1445F51BC0A8969 >/dev/null 2>&1; then
        sudo pacman-key --lsign-key D1445F51BC0A8969 || echo "⚠️  Could not sign XLibre key."
    fi
fi

# --- Hardinfo2 Setup ---
echo "🔧 Configuring Hardinfo2 for $USER..."
if ! getent group hardinfo2 >/dev/null; then
    sudo groupadd hardinfo2 || echo "⚠️  Could not create hardinfo2 group."
fi
sudo usermod -aG hardinfo2 "$USER" || echo "⚠️  Could not add $USER to hardinfo2 group."

if [ -f "/usr/lib/systemd/system/hardinfo2.service" ]; then
    sudo systemctl enable --now hardinfo2 2>/dev/null && echo "✅ Hardinfo2 service enabled." || echo "⚠️  Could not enable hardinfo2."
fi

# --- User Groups & Services ---
echo "🔧 Configuring user groups and services..."
if ! id -nG "$USER" | grep -qw i2c; then
    sudo usermod -aG i2c "$USER" || echo "⚠️  Could not add $USER to i2c group."
fi

echo "🚀 Configuring Syncthing integration for $USER"
sudo systemctl enable --now "syncthing@$USER.service" 2>/dev/null && echo "✅ Syncthing configured." || echo "⚠️  Syncthing config skipped."

if command -v apparmor_parser >/dev/null; then
    sudo apparmor_parser -r /etc/apparmor.d/firejail-default 2>/dev/null && echo "✅ firejail AppArmor integration complete" || echo "⚠️  Could not reload firejail."
fi

# Native Messaging Links
SRC_JSON="$HOME/.config/mozilla/native-messaging-hosts/org.keepassxc.keepassxc_browser.json"
if [ -f "$SRC_JSON" ]; then
    mkdir -p "$HOME/.mozilla/native-messaging-hosts/" "$HOME/.zen/native-messaging-hosts/" 2>/dev/null || true
    ln -sf "$SRC_JSON" "$HOME/.mozilla/native-messaging-hosts/org.keepassxc.keepassxc_browser.json" 2>/dev/null || true
    ln -sf "$SRC_JSON" "$HOME/.zen/native-messaging-hosts/org.keepassxc.keepassxc_browser.json" 2>/dev/null || true
    echo "✅ Native messaging hosts configured."
fi

# --- Post-Setup Logic (Installed Systems Only) ---
if is_installed; then
    echo ""
    read -rp "Would you like to install Virt-Manager now? (Requires restart) [y/n]: " install_choice
    case "$install_choice" in 
        [Yy]* )
            if command -v install-virt-manager >/dev/null; then
                install-virt-manager || echo "❌ Error: 'install-virt-manager' failed."
            else
                echo "❌ Error: 'install-virt-manager' not found."
            fi
            read -rp "Do you want to reboot now? [y/N]: " restart_option
            if [[ "$restart_option" =~ ^[Yy]$ ]]; then
                cleanup_and_exit 0 true
            else
                echo "Reboot deferred."
            fi
            ;;
        * ) echo "Skipping Virt-Manager installation.";;
    esac
fi

# --- Final Cleanup and Exit ---
echo "------------------------------------------"
echo "Setup complete!"

if is_installed; then
    read -rp "Would you like to reboot now? [y/N]: " final_reboot_choice
    if [[ "$final_reboot_choice" =~ ^[Yy]$ ]]; then
        cleanup_and_exit 0 true
    else
        echo "Setup completed. You may close this terminal."
        cleanup_and_exit 0 false
    fi
else
    echo "Live environment detected. Setup complete."
    cleanup_and_exit 0 false
fi
