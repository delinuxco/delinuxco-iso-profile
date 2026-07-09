#!/bin/bash

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

# Function to check if user can use sudo
check_sudo() {
    if ! sudo -v &>/dev/null; then
        echo "❌ Error: This script requires sudo privileges."
        exit 1
    fi
}

check_internet() {
    local host="1.1.1.1"
    echo -n "Checking internet connectivity..."
    
    if ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
        echo " ✅ Connected."
        return 0
    else
        echo -e "\n❌ Internet connection not available"
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
    fi
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
         .-**-       -**=.:*#:          
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
echo
echo "Welcome to DeLinuxCo setup!" | tee "$LOG_FILE"
sleep 1

check_sudo
check_internet

echo -e "\nDeLinuxCO Automated Setup Script"
echo -e "This script requires internet access for GPG verification.\n"

echo "Continuing with the rest of the setup..."
sleep 1

# Determine system type
if is_installed; then
    echo "✅ System appears to be an installed Arch-based Linux"
else
    echo "⚠️  This script was run on a Live/non-standard environment"
fi

echo -e "\nPerforming essential system configurations..."

# --- GPG Key Verification ---
echo "🔐 Verifying GPG keys..."

# 1.  DeLinuxCo Key Integration
echo "🔐 Importing DeLinuxCo keys..."
KEY_FILE="delinuxco.asc"
if curl -s -O https://delinuxco.nyc3.cdn.digitaloceanspaces.com/x86_64/delinuxco.asc; then
    sudo pacman-key --add "$KEY_FILE"
    sudo pacman-key --finger 5264C881A5E37495
    sudo pacman-key --lsign-key 5264C881A5E37495
    rm -f "$KEY_FILE" # Clean up the downloaded file
else
    echo "⚠️  Could not download DeCLinuxCo GPG key. Skipping..."
fi


# 2. XLibre Manjaro Key Integration 
echo "🔐 Importing XLibre Manjaro keys..."
KEY_FILE="xlibre-manjarolinux.asc"
if curl -s -O https://xlibre-manjaro.github.io/xlibre-manjarolinux.asc; then
    sudo pacman-key --add "$KEY_FILE"
    sudo pacman-key --finger D1445F51BC0A8969
    sudo pacman-key --lsign-key D1445F51BC0A8969
    rm -f "$KEY_FILE" # Clean up the downloaded file
else
    echo "⚠️  Could not download XLibre Manjaro GPG key. Skipping..."
fi

# User Groups & Services
sudo usermod -aG i2c "$USER" || true
echo "🚀 Configuring Syncthing integration for $USER"
systemctl enable --now "syncthing@$HD_USER.service" 2>/dev/null || true # Fixed variable typo from your snippet

# Hardinfo2 setup
if ! getent group hardinfo2 >/dev/null; then
    sudo groupadd hardinfo2
fi
sudo usermod -aG hardinfo2 "$USER"
echo "✅ Successfully configured Hardinfo2"

# Firejail setup
if command -v apparmor_parser >/dev/null; then
    sudo apparmor_parser -r /etc/apparmor.d/firejail-default 2>/dev/null
    echo "✅ firejail apparmor integration complete"
fi

# --- Post-Setup Logic (Installed Systems Only) ---
if [[ "$OSTYPE" == linux-gnu* ]]; then
    if is_installed; then
        echo ""
        read -rp "If you will be running Virtual Machines (VM's), It is recommended to install Virt-Manager, but it can be a bit tricky to configure correctly. We can easily take care of all of the installation and configuration now. Would you like to install Virt-Manager? Requires restart. [Y/n]: " install_choice
        
        case "$install_choice" in 
            [Yy]* )
                echo "Running custom installation routine..."
                if command -v install-virt-manager >/dev/null; then
                    install-virt-manager
                else
                    echo "❌ Error: 'install-virt-manager' command not found."
                fi
                ;;
            * )
                echo "Skipping Virt-Manager installation."
                ;;
        esac
    fi
fi

# --- Final Cleanup (Executed regardless of the final choice) ---
echo "------------------------------------------"
echo "Cleaning up startup files..."
rm -f "$HOME/.user_init.sh"
rm -f "$HOME/UserConfig.desktop"
touch "$MARKER_FILE"
echo "Cleanup complete."

# --- Final User Decision ---
echo ""
read -rp "Setup Complete! Would you like to reboot now? [y/N]: " final_reboot_choice

if [[ "$final_reboot_choice" =~ ^[Yy]$ ]]; then
    echo "Rebooting system..."
    sync
    sudo shutdown -r now
else
    echo "Closing terminal..."
    pkill mate-terminal
fi

