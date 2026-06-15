#!/bin/bash

# Read this before running the script; here's what you need to know:
# --- PROBLEM 1: Custom SUID (/opt/sys_backup) ---
# --- PROBLEM 2: Path Hijacking (/opt/monitoring/check_logs.sh) ---
# --- PROBLEM 3: Bad Sudoers Rule (/usr/bin/node) ---
# --- PROBLEM 4: Hidden Credential (/var/www/capitan_grizzly_api/.env) ---
# --- PROBLEM 5: Exposed SSH Private Key (/opt/.hidden_keys/root_key) ---

# Run script: 
# 1. nano Linux_thirdblock_lab.sh
# 2. chmod +x Linux_thirdblock_lab.sh
# 3. sudo ./Linux_thirdblock_lab.sh -s

# Capitan note: Just read the challenges before you can't solve anything

trap ctrl_c INT

function ctrl_c(){
    echo -e "\n${redColour}[!] Exiting execution...${endColour}\n"
    exit 1
}

if [ "$EUID" -ne 0 ]; then
    echo -e "${redColour}[!] Please run this script as root (sudo).${endColour}"
    exit 1
fi

REAL_USER=$SUDO_USER
if [ -z "$REAL_USER" ]; then
    REAL_USER=$(whoami)
fi

function setup_lab() {
    echo -e "\n${blueColour}[*] Deploying The Ultimate PrivEsc Laboratory...${endColour}"

    # 1. Custom SUID Binary (GTFOBins)
    echo -e "${yellowColour}[+] Deploying Custom SUID...${endColour}"
    cp /usr/bin/cp /opt/sys_backup
    chmod u+s /opt/sys_backup

    # 2. Path Hijacking Vulnerability
    echo -e "${yellowColour}[+] Deploying Path Hijacking vector...${endColour}"
    mkdir -p /opt/monitoring
    echo '#!/bin/bash -p' > /opt/monitoring/check_logs.sh
    echo 'tail -n 5 /var/log/syslog' >> /opt/monitoring/check_logs.sh
    chown root:root /opt/monitoring/check_logs.sh
    chmod +x /opt/monitoring/check_logs.sh
    chmod u+s /opt/monitoring/check_logs.sh

    # 3. Bad Sudoers Rule (Node.js)
    echo -e "${yellowColour}[+] Configuring insecure sudoers rule...${endColour}"
    echo "$REAL_USER ALL=(root) NOPASSWD: /usr/bin/node" > /etc/sudoers.d/node_priv
    chmod 0440 /etc/sudoers.d/node_priv

    # 4. Hidden Credential (Environment Variables)
    echo -e "${yellowColour}[+] Hiding credentials...${endColour}"
    mkdir -p /var/www/capitan_grizzly_api
    echo "DB_HOST=127.0.0.1" > /var/www/capitan_grizzly_api/.env
    echo "DB_USER=root" >> /var/www/capitan_grizzly_api/.env
    echo "DB_PASS=Ethical_Hacking_No_Limits_2026" >> /var/www/capitan_grizzly_api/.env
    chmod 644 /var/www/capitan_grizzly_api/.env

    # 5. Exposed SSH Private Key
    echo -e "${yellowColour}[+] Generating exposed SSH keys...${endColour}"
    mkdir -p /opt/.hidden_keys
    ssh-keygen -t rsa -b 2048 -f /opt/.hidden_keys/root_key -N "" -q
    mkdir -p /root/.ssh
    cat /opt/.hidden_keys/root_key.pub >> /root/.ssh/authorized_keys
    chmod 644 /opt/.hidden_keys/root_key

    echo -e "\n${greenColour}[✔] Environment compromised. Your mission:${endColour}"
    echo -e "  Find the 5 vectors, exploit them to get root, and write the report."
}

function restore_lab() {
    echo -e "\n${blueColour}[*] Cleaning environment...${endColour}"

    rm -f /opt/sys_backup
    rm -rf /opt/monitoring 2>/dev/null
    rm -f /etc/sudoers.d/node_priv
    rm -rf /var/www/capitan_grizzly_api 2>/dev/null
    
    if [ -f /opt/.hidden_keys/root_key.pub ]; then
        grep -v -f /opt/.hidden_keys/root_key.pub /root/.ssh/authorized_keys > /tmp/auth_keys_temp
        mv /tmp/auth_keys_temp /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
    fi
    rm -rf /opt/.hidden_keys 2>/dev/null

    echo -e "${greenColour}[✔] System secured.${endColour}"
}

if [ "$1" == "-s" ] || [ "$1" == "--setup" ]; then
    setup_lab
elif [ "$1" == "-r" ] || [ "$1" == "--restore" ]; then
    restore_lab
else
    echo -e "\n${yellowColour}Usage:${endColour}"
    echo -e "  sudo $0 -s  | --setup"
    echo -e "  sudo $0 -r  | --restore\n"
fi