#!/bin/bash

# Read this before running the script; here's what you need to know:
# --- PROBLEM 1: Knowing what the lazy administrator allowed you to do.---
# --- PROBLEM 2: Administrators often leave password-protected .conf, .php, and .bak files in locations like /var, /opt, or /etc. ---
# --- PROBLEM 3: If you find a script that runs periodically as root but you have permissions to modify it, you can inject malicious code. ---
# --- PROBLEM 4: In /opt/maintenance/run_backup.sh, the command `tar -cf backup.tar *` uses a wildcard (*). `tar` is vulnerable to this because it mistakes filenames for configuration parameters if they begin with `--`. ---

# Run script: 
# 1. nano Linux_misconfigurationTwo_lab.sh
# 2. chmod +x Linux_misconfigurationTwo_lab.sh
# 3. sudo ./Linux_misconfigurationTwo_lab.sh -s

# Capitan note: Just read the challenges before you can't solve anything

trap ctrl_c INT

function ctrl_c(){
    echo -e "\n${redColour}[!] Exiting...${endColour}\n"
    exit 1
}

if [ "$EUID" -ne 0 ]; then
    echo -e "${redColour}[!] Please run this script as root (sudo).${endColour}"
    exit 1
fi

# Get the actual user who executed sudo
REAL_USER=$SUDO_USER
if [ -z "$REAL_USER" ]; then
    REAL_USER=$(whoami)
fi

function setup_lab() {
    echo -e "\n${blueColour}[*] Starting Misconfigurations & Passwords lab...${endColour}"

    # 1. Misconfigured Sudoers (GTFOBins)
    echo -e "${yellowColour}[+] Configuring vulnerable sudoers rules...${endColour}"
    echo "$REAL_USER ALL=(ALL) NOPASSWD: /usr/bin/awk, /usr/bin/less" > /etc/sudoers.d/lab_misconfig
    chmod 0440 /etc/sudoers.d/lab_misconfig

    # 2. Scripts with excessive permissions (World-Writable)
    echo -e "${yellowColour}[+] Creating vulnerable maintenance script...${endColour}"
    mkdir -p /opt/maintenance
    echo -e "#!/bin/bash\n# Scheduled task by root to clean up logs\necho 'Cleaning system...'" > /opt/maintenance/cleanup.sh
    # 777 Perms: Anyone can modify this script
    chmod 777 /opt/maintenance/cleanup.sh

    # 3. Dangerous Wildcards (Tar Wildcard Injection)
    echo -e "${yellowColour}[+] Setting up Wildcard Injection environment...${endColour}"
    mkdir -p /opt/backup_service
    chmod 777 /opt/backup_service
    echo "Important app data" > /opt/backup_service/data.txt
    # Simulating a script an admin would run with cron using a wildcard (*)
    echo -e "#!/bin/bash\ncd /opt/backup_service\ntar -cf backup.tar *" > /opt/maintenance/run_backup.sh
    chmod 755 /opt/maintenance/run_backup.sh

    # 4. Cleartext Passwords / Exposed Credentials
    echo -e "${yellowColour}[+] Hiding plaintext credentials...${endColour}"
    mkdir -p /var/backups/legacy_app
    mkdir -p /var/www/html/config
    
    echo "db_user=admin" > /var/backups/legacy_app/settings.conf
    echo "db_password=Grizzly_Hacking_2026!" >> /var/backups/legacy_app/settings.conf
    
    echo "<?php" > /var/www/html/config/db_connect.php
    echo "// TODO: Remove hardcoded credentials before production" >> /var/www/html/config/db_connect.php
    echo "\$conn = new mysqli('localhost', 'root', 'SuperSecretAdmin123');" >> /var/www/html/config/db_connect.php

    echo -e "\n${greenColour}[✔] Lab configured. Your objectives as an attacker:${endColour}"
    echo -e "  1. Identify which commands you can run as root (Use 'sudo -l')."
    echo -e "  2. Use GTFOBins to escalate privileges using 'awk' and 'less'."
    echo -e "  3. Find exposed passwords using 'grep' recursively."
    echo -e "  4. Hijack the /opt/maintenance/cleanup.sh script."
    echo -e "  5. Perform a Wildcard Injection in /opt/backup_service/ using tar."
}

function restore_lab() {
    echo -e "\n${blueColour}[*] Cleaning up lab and restoring security...${endColour}"

    rm -f /etc/sudoers.d/lab_misconfig
    rm -rf /opt/maintenance 2>/dev/null
    rm -rf /opt/backup_service 2>/dev/null
    rm -rf /var/backups/legacy_app 2>/dev/null
    rm -rf /var/www/html/config 2>/dev/null

    echo -e "${greenColour}[✔] Environment completely clean.${endColour}"
}

if [ "$1" == "-s" ] || [ "$1" == "--setup" ]; then
    setup_lab
elif [ "$1" == "-r" ] || [ "$1" == "--restore" ]; then
    restore_lab
else
    echo -e "\n${yellowColour}Script usage:${endColour}"
    echo -e "  sudo $0 -s  | --setup    -> Sets up the vulnerable environment"
    echo -e "  sudo $0 -r  | --restore  -> Cleans up the system\n"
fi
