#!/bin/bash

# Exit on error, treat unset variables as error
set -euo pipefail

# --- Configuration ---
MARKER_FILE="$HOME/.config/dlint_run_once.marker"
LOG_FILE="$HOME/.dlc_script_log"

# Ensure config directory exists
mkdir -p "$(dirname "$MARKER_FILE")"

# Check for previous execution marker
if [ -f "$MARKER_FILE" ]; then
    echo "⚠️  Script has already been/is being run by this user. Exiting."
    exit 0
fi

# --- Functions ---

check_sudo() {
    if ! sudo -v &>/dev/null; then
        echo "❌ Error: This script requires sudo privileges."
        exit 1
    fi
}

check_internet() {
    local host="8.8.8.8"
    echo -n "Checking internet connectivity...used to verify GPG Keys. Not required, but recommended atleast during the first boot after installation."
    
    # 1. Initial Check
    if ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
        echo " ✅ Connected."
        return 0
    fi

    # 2. If first check fails, ask if user wants to wait
    echo -e "\n❌ Internet connection not available"
    read -rp "Do you want to wait for the internet? (y/n): " wait_choice

    if [[ "$wait_choice" == [Yy]* ]]; then
        echo "⏳ Waiting 30 seconds to retry..."
        sleep 30
        
        # 3. Second Check after waiting
        if ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
            echo " ✅ Connected after waiting."
            return 0
        else
            echo "❌ Still no internet connection after waiting."
        fi
    fi

    # 4. Final Decision: If they didn't want to wait, OR if the retry failed
    read -rp "Continue without internet? (y/n): " choice
    case "$choice" in
        [Yy]* ) 
            echo "⚠️  Proceeding offline. Note: GPG and package updates may fail."
            return 0 
            ;;
        * )
            echo "❌ Exiting setup per user request."
            exit 0 
            ;;
    esac
}


is_installed() {
    # Returns true if it's an installed system, false if Live ISO
    [ -f "/etc/pacman.conf" ] && [ ! -d "/run/miso/sfs/livefs" ]
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
                 :##:           -#+.    
                -##:           -#*.     
             ..:++.        .:=*#+.     
   :===========+=--======++**+=:        
   :---------:::.::------::.. 
EOF

echo
echo "Welcome to DeLinuxCo setup!" | tee "$LOG_FILE"
sleep 1

check_sudo
check_internet

echo -e "\nDeLinuxCO Automated Setup Script"
echo -e "This script requires internet access for GPG verification.\n"

# Determine system type
if is_installed; then
    echo "✅ System appears to be an installed Arch-based Linux"
else
    echo "⚠️  This script was run on a Live/non-standard environment"
fi

echo -e "\nPerforming essential system configurations..."

# --- GPG Key Verification ---
echo "🔐 Verifying GPG keys..."

# 1. DeLinuxCo Key Integration
echo "🔐 Importing DeLinuxCO keys..."
KEY_FILE="delinuxco.asc"
if curl -s -O https://delinuxco.nyc3.cdn.digitaloceanspaces.com/x86_64/delinuxco.asc; then
    sudo pacman-key --add "$KEY_FILE"
    sudo pacman-key --finger 9478dd4f27ea6a82
    sudo pacman-key --lsign-key 9478dd4f27ea6a82
    rm -f "$KEY_FILE"
else
    echo "⚠️  Could not download DeLinuxCo GPG key. Skipping..."
fi

# 2. XLibre Manjaro Key Integration 
echo "🔐 Importing XLibre Manjaro keys..."
KEY_FILE="xlibre-manjarolinux.asc"
if curl -s -O https://xlibre-manjaro.github.io/xlibre-manjarolinux.asc; then
    sudo pacman-key --add "$KEY_FILE"
    sudo pacman-key --finger D1445F51BC0A8969
    sudo pacman-key --lsign-key D1445F51BC0A8969
    rm -f "$KEY_FILE"
else
    echo "⚠️  Could not download XLibre Manjaro GPG key. Skipping..."
fi

# User Groups & Services
sudo usermod -aG i2c "$USER" || true
echo "🚀 Configuring Syncthing integration for $USER"
systemctl enable --now "syncthing@$USER.service" 2>/dev/null || true 

if ! getent group hardinfo2 >/dev/null; then
    sudo groupadd hardinfo2
fi
sudo usermod -aG hardinfo2 "$USER"
echo "✅ Successfully configured Hardinfo2"

# Firejail setup
if command -v apparmor_parser >/dev/null; then
    sudo apparmor_parser -r /etc/apparmor.d/firejail-default 2>/dev/null || true
    echo "✅ firejail apparmor integration complete"
fi

# Create native-messaging-hosts links
SRC_JSON="$HOME/.config/mozilla/native-messaging-hosts/org.keepassxc.keepassxc_browser.json"
if [ -f "$SRC_JSON" ]; then
    mkdir -p "$HOME/.mozilla/native-messaging-hosts/"
    mkdir -p "$HOME/.zen/native-messaging-hosts/"
    
    ln -sf "$SRC_JSON" "$HOME/.mozilla/native-messaging-hosts/org.keepassxc.keepassxc_browser.json"
    ln -sf "$SRC_JSON" "$HOME/.zen/native-messaging-hosts/org.keepassxc.keepassxc_browser.json"
    echo "✅ Support for native-messaging-hosts for Firefox and Zen browsers is installed."
else
    echo "⚠️  KeePassXC browser JSON not found; skipping symlink creation."
fi

# --- Post-Setup Logic (Installed Systems Only) ---
if [[ "$OSTYPE" == linux-gnu* ]]; then
    if is_installed; then
        # remove virtualbox-guest-utils from installed system
        #sudo pacman -Rns --noconfirm virtualbox-guest-utils

        echo ""
        read -rp "If you will be running Virtual Machines (VM's), It is recommended to install Virt-Manager, and it can be a bit tricky to configure correctly, but we can take care of all of the installation and configuration. Would you like to install Virt-Manager now? Requires restart. [y/n]: " install_choice
        
        case "$install_choice" in 
            [Yy]* )
                echo "Running custom installation routine..."
                # Ensure the command exists before calling it
                if command -v install-virt-manager >/dev/null; then
                    install-virt-manager
                else
                    echo "❌ Error: 'install-virt-manager' command not found."
                fi
                
                echo ""
                read -rp "Do you want to reboot now? [y/N]: " restart_option

                if [[ "$restart_option" =~ ^[Yy]$ ]]; then
                    echo "Cleaning up and rebooting..."
                    touch "$MARKER_FILE"
                    rm -f "$HOME/.config/autostart/UserConfig.desktop"
                    rm -f "$HOME/.user_init.sh"
                    sync
                    sudo shutdown -r now
                    exit 0
                else
                    echo "Reboot deferred."
                fi
                ;;
            * )
                echo "Skipping Virt-Manager installation, if you wish to install later, open a terminal window and run: install-virt-manager"
                ;;
        esac
    fi
fi

# --- Final Cleanup ---
echo "------------------------------------------"
echo "Cleaning up startup files..."
rm -f "$HOME/.config/autostart/UserConfig.desktop"
rm -f "$HOME/.user_init.sh"
touch "$MARKER_FILE"
echo "Cleanup complete."

# --- Final User Decision ---
if is_installed; then
    read -rp "Setup Complete! Would you like to reboot now? [y/N]: " final_reboot_choice
    if [[ "$final_reboot_choice" =~ ^[Yy]$ ]]; then
        echo "Rebooting system..."
        sync
        rm -f "$HOME/.config/autostart/UserConfig.desktop"
        rm -f "$HOME/.user_init.sh"
        touch "$MARKER_FILE"
        sudo shutdown -r now
    else
        echo "Closing terminal..."
        rm -f "$HOME/.config/autostart/UserConfig.desktop"
        rm -f "$HOME/.user_init.sh"
        touch "$MARKER_FILE"        
        pkill mate-terminal
        exit 0
    fi
else
    echo "Live environment detected. Exiting."
    pkill mate-terminal
    exit 0
fi

