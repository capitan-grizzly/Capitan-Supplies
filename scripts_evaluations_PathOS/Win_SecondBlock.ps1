<#
# Read this before running the script; here's what you need to know:
# --- PROBLEM 1: Vulnerable Service with world-writable binary executable ---
# --- PROBLEM 2: Hidden Local Administrator Account (stealth persistence) ---
# --- PROBLEM 3: Malicious Autorun Registry Key pointing to a fake payload ---

# Run script: 
# 1. Open PowerShell as Administrator.
# 2. Set-ExecutionPolicy Bypass -Scope Process -Force
# 3. .\Win_SecondBlock.ps1 -s

# Capitan note: Just read the challenges before you can't solve anything
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
    Write-Host "[*] Deploying Second Block: Services, Users & Autoruns..."

    # Problem 1: Vulnerable Service
    # Creates a directory, gives Everyone modify permissions, and links a service to it.
    New-Item -Path "C:\VulnerableServices\SysMonitor" -ItemType Directory -Force | Out-Null
    Set-Content -Path "C:\VulnerableServices\SysMonitor\monitor.bat" -Value "@echo Running system diagnostics..."
    icacls "C:\VulnerableServices\SysMonitor" /grant "Everyone:(OI)(CI)M" /T /C /Q | Out-Null
    New-Service -Name "VulnMonitor" -BinaryPathName "C:\VulnerableServices\SysMonitor\monitor.bat" -DisplayName "System Vulnerability Monitor" -Description "Monitors system health. Runs as LocalSystem." -StartupType Automatic | Out-Null
    Start-Service -Name "VulnMonitor" -ErrorAction SilentlyContinue

    # Problem 2: Hidden Local Administrator
    # Creates a user, adds to Admins, and hides it from the Windows login screen via Registry.
    net user "SysUpdater" "Grizzly_2026!" /add /y | Out-Null
    net localgroup Administrators "SysUpdater" /add | Out-Null
    
    $SpecialAccountsPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList"
    if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts" -Force | Out-Null
    }
    if (-not (Test-Path $SpecialAccountsPath)) {
        New-Item -Path $SpecialAccountsPath -Force | Out-Null
    }
    New-ItemProperty -Path $SpecialAccountsPath -Name "SysUpdater" -Value 0 -PropertyType DWord -Force | Out-Null

    # Problem 3: Malicious Autorun Key
    # Creates a dummy payload and sets it to run automatically on user login.
    Set-Content -Path "C:\Users\Public\telemetry_updater.bat" -Value "@echo Beeping home to C2 server..."
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsTelemetryUpdater" -Value "C:\Users\Public\telemetry_updater.bat" -Force | Out-Null

    Write-Host "[+] Laboratory deployed successfully. Time to hunt."
}

function Invoke-LabRestore {
    Write-Host "[*] Cleaning up the environment..."

    # 1. Clean Service
    Stop-Service -Name "VulnMonitor" -ErrorAction SilentlyContinue
    # WMI is used here because Remove-Service is only available in PS Core / 6+
    (Get-WmiObject win32_service -Filter "name='VulnMonitor'").delete() | Out-Null
    Remove-Item -Path "C:\VulnerableServices" -Recurse -Force -ErrorAction SilentlyContinue

    # 2. Clean User and Unhide
    net user "SysUpdater" /delete /y 2>$null
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" -Name "SysUpdater" -ErrorAction SilentlyContinue

    # 3. Clean Autorun
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsTelemetryUpdater" -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Users\Public\telemetry_updater.bat" -Force -ErrorAction SilentlyContinue

    Write-Host "[+] Environment completely restored to normal."
}

if ($s) {
    Invoke-LabSetup
}
elseif ($r) {
    Invoke-LabRestore
}
else {
    Write-Host "Usage:"
    Write-Host "  .\Win_SecondBlock.ps1 -s  (Setup vulnerable environment)"
    Write-Host "  .\Win_SecondBlock.ps1 -r  (Restore environment)"
}