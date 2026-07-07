#!/bin/bash
MARKER_FILE="$HOME/.config/dlc_run_once.marker"

echo
sleep 1
    echo
    echo " Welcome to DeLinuxCo!"
    echo
sleep 1
echo "                                                        
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
             ..:++.        .:=*#+.  .   
   :===========+=--======++**+=:        
   :---------:::.::------::..  "  
echo
echo
echo
sleep 2

# Check if the marker file exists
    if [ -f "$MARKER_FILE" ]; then
        echo "Script has already been run by this user. Exiting."
    exit 0
    fi
#State reason for internet connectivity
echo "Internet access is needed for certain parts of this script, like verifying GPG keys etc"

check_internet() {
    local host="1.1.1.1"   # reliable target (Cloudflare DNS)
    local interval=2

    while true; do
        echo "Checking internet connectivity..."

        if ping -c 1 -W 2 "$host" > /dev/null 2>&1; then
            echo "Internet connection is available."
            return 0
        fi

        echo "Internet not reachable."

        # Prompt user
        read -rp "Would you like to try again? (y/n): " answer
        case "$answer" in
            [Yy]* )
                echo "Retrying..."
                sleep "$interval"
                ;;
            [Nn]* )
                echo "Exiting script."
                return 1
                ;;
            * )
                echo "Invalid input. Please enter y or n."
                ;;
        esac
    done
}

# ---- main script ----
check_internet || exit 1

    echo "Continuing with the rest of the setup..."

sleep 2
    echo

# Your one-time commands for the user go here
#echo "Running the script for the first time for user $(whoami)..." > "$HOME/first_run_output.txt"
# Example command: touch a welcome file
#touch "$HOME/welcome_message.txt"


sleep 3
    echo "We need to finish setting up your user account...you may need to enter your user password."
    echo
sleep 2

#verify DeLinuxCo keys are installed.
    echo "verifying DeLinuxCo gpg keys are installed...."
sudo pacman-key --recv-keys 5264C881A5E37495

    echo
    echo

sleep 2
    echo "Next we need to add you to the i2c Group"
sudo usermod -aG i2c $USER
    
sleep 1
    echo
    echo "$USER has been added to group i2c"
sleep 2
    echo "...enabling syncthing for $USER ..."
    sudo systemctl enable --now syncthing@$USER
    echo "...Syncthing is now enabled for $USER"
sleep 2
    echo "Adding $USER to hardinfo2 group"
echo
    sleep 2
    sudo groupadd hardinfo2
    sudo usermod -a -G hardinfo2 $USER
    sudo systemctl enable --now hardinfo2
    sleep 2
echo
    echo "...$USER has been added to hardinfo2 group"
echo
echo
    echo "Integrate firejail into apparmor"
    sudo apparmor_parser -r /etc/apparmor.d/firejail-default
    echo "firejail apparmor integration complete"
sleep 2
    echo 
    echo "User configureation completed successfully, this window will close automatically."

 
    echo "Enjoy your new Linux experience on DeLinuxCo"



### Function to check for Live ISO environment
check_arch_live_environment() {
    # 1. Check for the archiso runtime directory.
    # This is the most definitive way to identify an archiso-based live system.
    if [ -d "/run/miso/sfs/livefs" ]; then
        return 0 # Found: It IS a Live ISO
    fi

    # If no indicators were found, assume it is a standard installation.
    return 1 # Not Found: It is an installed system
}

# --- Main Execution Logic ---

echo "[*] Performing environment safety check..."

if check_arch_live_environment; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Live ISO detected!"
    echo "Script completed Live ISO configuration."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    sleep 5
    echo closing in...
    echo "5"
sleep 1
    echo "4"
sleep 1
    echo "3"
sleep 1
    echo "2"
sleep 1
    echo "1"
pkill mate-terminal

else
    echo "[+] Success: Installed system detected. Proceeding..."
fi

#Ask to install virt-manager
    yn() {
    printf " Reply [y/n]: "
    read yn
    [[ "$yn" != y ]] && [[ "$yn" != n ]] && yn
    }
# question
    printf "If you plan to use Virtual Machines (VM's), we can install virt-manager now. Although Virt-Manager is uses a graphical interface, setting it up can be a bit   tricky. Shall we install it for you?"
    yn
    [[ "$yn" = y ]] && install-virt-manager

echo
echo
echo

#Ask user if they would like to reboot now?
    yn() {
    printf " Reply [y/n]: "
    read yn
    [[ "$yn" != y ]] && [[ "$yn" != n ]] && yn
    }
# warning
    printf "Reboot your system now?"
    yn
    [[ "$yn" = n ]] && rm /home/$USER/.config/autostart/UserConfig.desktop && rm /home/$USER/.config/autostart/vboxclient.desktop && rm /home/$USER/.user_init.sh && pkill mate-terminal && exit 0 

sleep 5
    echo closing in...
    echo "5"
sleep 1
    echo "4"
sleep 1
    echo "3"
sleep 1
    echo "2"
sleep 1
    echo "1"


# Create the marker file to prevent future execution for this user
touch "$MARKER_FILE"
#    echo "Marker file created for user $(whoami)."
        #sed -i -E 's|X-GNOME-Autostart-enabled=true|X-GNOME-Autostart-enabled=false|g' "/home/$USER/.config/autostart/UserConfig.desktop"
rm /home/$USER/.user_init.sh
rm /home/$USER/.config/autostart/UserConfig.desktop
sudo shutdown -r now

#close terminal
pkill mate-terminal

exit 0

## [Desktop Entry]
## Type=Application
## Name=User Initial Setup
## Exec=/home/your_username/.user_init.sh
## Terminal=false
## X-GNOME-Autostart-enabled=true
