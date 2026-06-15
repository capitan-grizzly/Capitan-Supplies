#!/bin/bash

# Read this before running the script; here's what you need to know:
# --- PROBLEM 1: SUID abuse in find ---
# --- PROBLEM 2: SUID abuse in base64 ---
# --- PROBLEM 3: Capabilities abuse in tar ---

# Run script: 
# 1. nano Linux_misconfigurationOne_lab.sh
# 2. chmod +x Linux_misconfigurationOne_lab.sh
# 3. sudo ./Linux_misconfigurationOne_lab.sh -s

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

function setup_lab() {
    echo -e "\n${blueColour}[*] Starting Privilege Escalation lab setup...${endColour}"

    mkdir -p /opt/lab_privesc
    chmod 755 /opt/lab_privesc

    echo -e "${yellowColour}[+] Deploying SUID binaries...${endColour}"
    # Using find
    cp /usr/bin/find /opt/lab_privesc/hidden_find
    chmod u+s /opt/lab_privesc/hidden_find
    # Using base64 (to read files)
    cp /usr/bin/base64 /tmp/.b64_encoded
    chmod u+s /tmp/.b64_encoded

    echo -e "${yellowColour}[+] Configuring SGID vectors...${endColour}"
    mkdir -p /opt/lab_privesc/shared_project
    chgrp shadow /opt/lab_privesc/shared_project
    chmod g+s /opt/lab_privesc/shared_project
    
    cp /usr/bin/nano /opt/lab_privesc/nano_edit
    chgrp shadow /opt/lab_privesc/nano_edit
    chmod g+s /opt/lab_privesc/nano_edit

    echo -e "${yellowColour}[+] Setting up Sticky Bit sandbox...${endColour}"
    mkdir -p /opt/lab_privesc/sticky_drop
    chmod 1777 /opt/lab_privesc/sticky_drop

    echo -e "${yellowColour}[+] Assigning dangerous capabilities...${endColour}"
    cp /usr/bin/tar /opt/lab_privesc/backup_tar
    # Granting capability to read ANY file on the system (like /etc/shadow)
    setcap cap_dac_read_search+ep /opt/lab_privesc/backup_tar 2>/dev/null

    echo -e "\n${greenColour}[✔] Lab configured. Your mission as an attacker:${endColour}"
    echo -e "  1. Find all SUID binaries on the system."
    echo -e "  2. Search for 'find' and 'base64' in GTFOBins and figure out how to abuse them."
    echo -e "  3. Identify binaries with custom capabilities and exploit them."
    echo -e "     (Hint: Try to read /etc/shadow without using sudo)"
}

function restore_lab() {
    echo -e "\n${blueColour}[*] Restoring environment and removing vulnerabilities...${endColour}"

    rm -rf /opt/lab_privesc 2>/dev/null
    rm -f /tmp/.b64_encoded 2>/dev/null

    echo -e "${greenColour}[+] Malicious SUID/SGID binaries removed.${endColour}"
    echo -e "${greenColour}[+] Capabilities wiped.${endColour}"
    echo -e "\n${greenColour}[✔] Environment fully secured.${endColour}"
}

if [ "$1" == "-s" ] || [ "$1" == "--setup" ]; then
    setup_lab
elif [ "$1" == "-r" ] || [ "$1" == "--restore" ]; then
    restore_lab
else
    echo -e "\n${yellowColour}Script usage:${endColour}"
    echo -e "  sudo $0 -s  | --setup    -> Deploys the vulnerable binaries"
    echo -e "  sudo $0 -r  | --restore  -> Cleans the system\n"
fi