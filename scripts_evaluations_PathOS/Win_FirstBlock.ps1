<#
# Read this before running the script; here's what you need to know:
# --- PROBLEM 1: Broken inheritance with "Everyone" granted Full Control on a sensitive root folder. ---
# --- PROBLEM 2: Illogical permissions in Program Files (SYSTEM account denied, standard Users granted Modify). ---
# --- PROBLEM 3: Standard Users granted explicit Write access to a subfolder inside C:\Windows\System32. ---
# --- PROBLEM 4: Executable script in the Public folder modified to allow Everyone to append/write data. ---
# --- PROBLEM 5: Secure backup folder where Administrators are explicitly denied access, but a standard user is allowed. ---

# Run script: 
# 1. Open PowerShell as Administrator.
# 2. Set-ExecutionPolicy Bypass -Scope Process -Force
# 3. .\Win_FirstBlock.ps1 -s

# Capitan note: Just read the challenges before you can't solve anything. The Red Team mindset requires you to understand normal Windows architecture to spot what looks out of place.
#>

param (
    [switch]$s,
    [switch]$r
)

# Enforce Administrator Privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Please run PowerShell as Administrator."
    exit
}

function Invoke-LabSetup {
    Write-Host "[*] Deploying First Block: Broken Access Controls..."

    # Problem 1: C:\Confidential_Data
    # Breaks inheritance and gives Everyone full control.
    New-Item -Path "C:\Confidential_Data" -ItemType Directory -Force | Out-Null
    Set-Content -Path "C:\Confidential_Data\financials.txt" -Value "Q1 Revenue: $1.2M"
    icacls "C:\Confidential_Data" /inheritance:r /grant "Everyone:(OI)(CI)F" /T /C /Q | Out-Null

    # Problem 2: C:\Program Files\LegacyApp
    # Breaks inheritance, denies SYSTEM (critical for services), gives Users modify rights.
    New-Item -Path "C:\Program Files\LegacyApp" -ItemType Directory -Force | Out-Null
    icacls "C:\Program Files\LegacyApp" /inheritance:r /grant "Users:(OI)(CI)M" /deny "SYSTEM:(OI)(CI)F" /T /C /Q | Out-Null

    # Problem 3: C:\Windows\System32\Tasks\CustomTasks
    # Dangerous write access in a system folder (simulating a persistence vector).
    New-Item -Path "C:\Windows\System32\Tasks\CustomTasks" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    icacls "C:\Windows\System32\Tasks\CustomTasks" /grant "Users:(OI)(CI)W" /C /Q | Out-Null

    # Problem 4: C:\Users\Public\AdminScripts
    # World-writable script.
    New-Item -Path "C:\Users\Public\AdminScripts" -ItemType Directory -Force | Out-Null
    Set-Content -Path "C:\Users\Public\AdminScripts\maintenance.bat" -Value "echo Running system maintenance..."
    icacls "C:\Users\Public\AdminScripts\maintenance.bat" /grant "Everyone:M" /C /Q | Out-Null

    # Problem 5: C:\SecureBackups and standard user creation
    # Create a local user to simulate an insider or compromised account.
    net user "Trainee" "Grizzly_2026!" /add /y | Out-Null
    New-Item -Path "C:\SecureBackups" -ItemType Directory -Force | Out-Null
    Set-Content -Path "C:\SecureBackups\master_key.txt" -Value "NTLM: 8846f7eaee8fb117ad06bdd830b7586c"
    icacls "C:\SecureBackups" /inheritance:r /grant "Trainee:(OI)(CI)F" /deny "Administrators:(OI)(CI)F" /T /C /Q | Out-Null

    Write-Host "[+] Laboratory deployed successfully. Your evaluation begins now."
}

function Restore-Lab {
    Write-Host "[*] Cleaning up the environment..."

    # Remove directories
    Remove-Item -Path "C:\Confidential_Data" -Recurse -Force -ErrorAction SilentlyContinue
    
    # Must reset permissions on SecureBackups before deleting because Admin is denied
    takeown /f "C:\SecureBackups" /r /d y | Out-Null
    icacls "C:\SecureBackups" /reset /T /C /Q | Out-Null
    Remove-Item -Path "C:\SecureBackups" -Recurse -Force -ErrorAction SilentlyContinue

    Remove-Item -Path "C:\Program Files\LegacyApp" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\System32\Tasks\CustomTasks" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Users\Public\AdminScripts" -Recurse -Force -ErrorAction SilentlyContinue

    # Remove user
    net user "Trainee" /delete /y 2>$null

    Write-Host "[+] Environment completely restored to normal."
}

if ($s) {
    Setup-Lab
}
elseif ($r) {
    Restore-Lab
}
else {
    Write-Host "Usage:"
    Write-Host "  .\Win_FirstBlock.ps1 -s  (Setup vulnerable environment)"
    Write-Host "  .\Win_FirstBlock.ps1 -r  (Restore environment)"
}