<#
# Read this before running the script; here's what you need to know:
# --- PRIVILEGE ESCALATION VECTORS (5) ---
# 1. AlwaysInstallElevated (Registry)
# 2. Unquoted Service Path 
# 3. Weak Service Binary Permissions
# 4. Weak Registry Permissions for a Service
# 5. Modifiable Scheduled Task running as SYSTEM
#
# --- PERSISTENCE MECHANISMS (3) ---
# 6. Malicious Run Registry Key
# 7. Malicious Startup Folder Script
# 8. DLL/Binary Hijacking via Writable System PATH
#
# Run script: 
# 1. Open PowerShell as Administrator.
# 2. Set-ExecutionPolicy Bypass -Scope Process -Force
# 3. .\Win_ThirdBlock.ps1 -s
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
    Write-Host "[*] Deploying Final Exam: The Grizzly Compromise..."

    # ==========================================
    # PRIVILEGE ESCALATION VECTORS
    # ==========================================

    # 1. AlwaysInstallElevated
    $HKCU_Path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer"
    $HKLM_Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"
    if (-not (Test-Path $HKCU_Path)) { New-Item -Path $HKCU_Path -Force | Out-Null }
    if (-not (Test-Path $HKLM_Path)) { New-Item -Path $HKLM_Path -Force | Out-Null }
    New-ItemProperty -Path $HKCU_Path -Name "AlwaysInstallElevated" -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $HKLM_Path -Name "AlwaysInstallElevated" -Value 1 -PropertyType DWord -Force | Out-Null

    # 2. Unquoted Service Path
    New-Item -Path "C:\Grizzly Corp\Enterprise Tools" -ItemType Directory -Force | Out-Null
    Set-Content -Path "C:\Grizzly Corp\Enterprise Tools\updater.bat" -Value "@echo Checking updates..."
    icacls "C:\Grizzly Corp" /grant "Users:(OI)(CI)W" /T /C /Q | Out-Null
    sc.exe create "GrizzlyUnquoted" binpath= "C:\Grizzly Corp\Enterprise Tools\updater.bat" start= demand obj= "LocalSystem" DisplayName= "Grizzly Enterprise Updater" | Out-Null

    # 3. Weak Service Binary Permissions
    New-Item -Path "C:\Opt\GrizzlySec" -ItemType Directory -Force | Out-Null
    Set-Content -Path "C:\Opt\GrizzlySec\agent.bat" -Value "@echo Running security agent..."
    icacls "C:\Opt\GrizzlySec\agent.bat" /grant "Users:F" /C /Q | Out-Null
    sc.exe create "GrizzlyAgent" binpath= '"C:\Opt\GrizzlySec\agent.bat"' start= demand obj= "LocalSystem" DisplayName= "Grizzly Security Agent" | Out-Null

    # 4. Weak Registry Permissions for a Service
    sc.exe create "GrizzlyLegacy" binpath= "C:\windows\system32\cmd.exe" start= demand obj= "LocalSystem" DisplayName= "Grizzly Legacy Service" | Out-Null
    $acl = Get-Acl "HKLM:\SYSTEM\CurrentControlSet\Services\GrizzlyLegacy"
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule("Users", "FullControl", "Allow")
    $acl.SetAccessRule($rule)
    Set-Acl -Path "HKLM:\SYSTEM\CurrentControlSet\Services\GrizzlyLegacy" -AclObject $acl

    # 5. Modifiable Scheduled Task (SYSTEM)
    New-Item -Path "C:\Tasks" -ItemType Directory -Force | Out-Null
    Set-Content -Path "C:\Tasks\cleanup.bat" -Value "@echo Cleaning temp files..."
    icacls "C:\Tasks\cleanup.bat" /grant "Users:F" /C /Q | Out-Null
    schtasks /create /tn "GrizzlyMaintenance" /tr "C:\Tasks\cleanup.bat" /sc daily /st 00:00 /ru SYSTEM /f | Out-Null

    # ==========================================
    # PERSISTENCE MECHANISMS
    # ==========================================

    # 6. Malicious Run Registry Key
    Set-Content -Path "C:\Users\Public\telemetry.bat" -Value "@echo Beeping home..."
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "GrizzlyTelemetry" -Value "C:\Users\Public\telemetry.bat" -Force | Out-Null

    # 7. Malicious Startup Folder Script
    $startupPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\win_update.bat"
    Set-Content -Path $startupPath -Value "@echo Hooked startup..."

    # 8. DLL / Binary Hijacking via PATH
    New-Item -Path "C:\Grizzly_Hijack" -ItemType Directory -Force | Out-Null
    icacls "C:\Grizzly_Hijack" /grant "Users:(OI)(CI)F" /T /C /Q | Out-Null
    $oldPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    # Prepend the writable folder to the SYSTEM path
    if ($oldPath -notmatch "C:\\Grizzly_Hijack") {
        $newPath = "C:\Grizzly_Hijack;" + $oldPath
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
    }

    Write-Host "[+] The environment is fully compromised. Good luck hunting, Capitán."
}

function Invoke-LabRestore {
    Write-Host "[*] Purging vulnerabilities and restoring the system..."

    # Clean Services
    $services = @("GrizzlyUnquoted", "GrizzlyAgent", "GrizzlyLegacy")
    foreach ($svc in $services) {
        sc.exe stop $svc 2>$null | Out-Null
        sc.exe delete $svc 2>$null | Out-Null
    }

    # Clean Scheduled Tasks
    schtasks /delete /tn "GrizzlyMaintenance" /f 2>$null | Out-Null

    # Clean Directories
    Remove-Item -Path "C:\Grizzly Corp" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Opt" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Tasks" -Recurse -Force -ErrorAction SilentlyContinue

    # Clean Registry & AlwaysInstallElevated
    Remove-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "AlwaysInstallElevated" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "AlwaysInstallElevated" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "GrizzlyTelemetry" -ErrorAction SilentlyContinue

    # Clean Startup & Public scripts
    Remove-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\win_update.bat" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Users\Public\telemetry.bat" -Force -ErrorAction SilentlyContinue

    # Restore PATH
    $oldPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($oldPath -match "C:\\Grizzly_Hijack;") {
        $restoredPath = $oldPath -replace "C:\\Grizzly_Hijack;", ""
        [Environment]::SetEnvironmentVariable("Path", $restoredPath, "Machine")
    }
    Remove-Item -Path "C:\Grizzly_Hijack" -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "[+] Environment completely sanitized."
}

if ($s) {
    Invoke-LabSetup
}
elseif ($r) {
    Invoke-LabRestore
}
else {
    Write-Host "Usage:"
    Write-Host "  .\Win_FinalExam.ps1 -s  (Setup vulnerable environment)"
    Write-Host "  .\Win_FinalExam.ps1 -r  (Restore environment)"
}