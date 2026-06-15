<#
# Read this before running the script; here's what you need to know:
# --- PROBLEM 1: Registry misconfigured to allow AlwaysInstallElevated ---
# --- PROBLEM 2: Service configured with an Unquoted Path containing spaces ---
# --- PROBLEM 3: Service executable with Weak Permissions (World-writable) ---
# --- PROBLEM 4: Service running as LOCAL SERVICE (Vector for Token Impersonation) ---

# Run script: 
# 1. Open PowerShell as Administrator.
# 2. Set-ExecutionPolicy Bypass -Scope Process -Force
# 3. .\Win_privesc.ps1 -s

# Capitan note: Just read the challenges before you can't solve anything. Enumeration is the key to Privilege Escalation.
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
    Write-Host "[*] Deploying Third Block: Privilege Escalation Vectors..."

    # Vector 1: Always Install Elevated
    Write-Host "[+] Configuring AlwaysInstallElevated in Registry..."
    $HKCU_Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer"
    $HKLM_Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"
    
    if (-not (Test-Path $HKCU_Path)) { New-Item -Path $HKCU_Path -Force | Out-Null }
    New-ItemProperty -Path $HKCU_Path -Name "AlwaysInstallElevated" -Value 1 -PropertyType DWord -Force | Out-Null
    
    if (-not (Test-Path $HKLM_Path)) { New-Item -Path $HKLM_Path -Force | Out-Null }
    New-ItemProperty -Path $HKLM_Path -Name "AlwaysInstallElevated" -Value 1 -PropertyType DWord -Force | Out-Null

    # Vector 2: Unquoted Service Path
    Write-Host "[+] Deploying Unquoted Service Path..."
    New-Item -Path "C:\Enterprise Software\Internal Tools" -ItemType Directory -Force | Out-Null
    Set-Content -Path "C:\Enterprise Software\Internal Tools\service.bat" -Value "@echo Running Enterprise Service..."
    # Grant Users write access to the base folder so they can plant a malicious binary
    icacls "C:\Enterprise Software" /grant "Users:(OI)(CI)W" /T /C /Q | Out-Null
    sc.exe create "UnquotedSvc" binpath= "C:\Enterprise Software\Internal Tools\service.bat" start= demand obj= "LocalSystem" DisplayName= "Enterprise Unquoted Service" | Out-Null

    # Vector 3: Weak Binary Permissions
    Write-Host "[+] Deploying Service with Weak Permissions..."
    New-Item -Path "C:\VulnerableApps\WeakBin" -ItemType Directory -Force | Out-Null
    Set-Content -Path "C:\VulnerableApps\WeakBin\backend.bat" -Value "@echo Running backend..."
    # Grant Full Control to standard Users on the specific binary
    icacls "C:\VulnerableApps\WeakBin\backend.bat" /grant "Users:F" /C /Q | Out-Null
    sc.exe create "WeakBinSvc" binpath= '"C:\VulnerableApps\WeakBin\backend.bat"' start= demand obj= "LocalSystem" DisplayName= "Backend Weak Permissions Service" | Out-Null

    # Vector 4: Token Impersonation Target (LOCAL SERVICE)
    Write-Host "[+] Deploying Token Impersonation Vector..."
    New-Item -Path "C:\VulnerableApps\TokenApp" -ItemType Directory -Force | Out-Null
    Set-Content -Path "C:\VulnerableApps\TokenApp\webworker.bat" -Value "@echo Running web worker..."
    icacls "C:\VulnerableApps\TokenApp\webworker.bat" /grant "Users:F" /C /Q | Out-Null
    # Runs as LOCAL SERVICE, which has SeImpersonatePrivilege natively
    sc.exe create "TokenSvc" binpath= '"C:\VulnerableApps\TokenApp\webworker.bat"' start= demand obj= "NT AUTHORITY\LOCAL SERVICE" DisplayName= "Local Service Web Worker" | Out-Null

    Write-Host "[+] Laboratory deployed. Time to escalate to SYSTEM."
}

function Invoke-LabRestore {
    Write-Host "[*] Cleaning up the environment..."

    # Clean Services
    $services = @("UnquotedSvc", "WeakBinSvc", "TokenSvc")
    foreach ($svc in $services) {
        sc.exe stop $svc 2>$null | Out-Null
        sc.exe delete $svc 2>$null | Out-Null
    }

    # Clean Directories
    Remove-Item -Path "C:\Enterprise Software" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\VulnerableApps" -Recurse -Force -ErrorAction SilentlyContinue

    # Clean Registry
    Remove-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "AlwaysInstallElevated" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "AlwaysInstallElevated" -ErrorAction SilentlyContinue

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
    Write-Host "  .\Win_ThirdBlock.ps1 -s  (Setup vulnerable environment)"
    Write-Host "  .\Win_ThirdBlock.ps1 -r  (Restore environment)"
}