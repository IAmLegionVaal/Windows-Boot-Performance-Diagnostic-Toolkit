#requires -Version 5.1
<#
.SYNOPSIS
    Guarded Windows boot and startup repair toolkit.
.DESCRIPTION
    Diagnoses by default and performs selected repairs for Explorer startup, icon
    cache corruption, explicit non-Microsoft scheduled tasks, current-user Run
    entries and Windows component integrity.
.NOTES
    Created by Dewald Pretorius - L2 IT Support Engineer.
#>

[CmdletBinding()]
param(
    [switch]$RepairAllSafe,
    [switch]$RestartExplorer,
    [switch]$ClearIconCache,
    [switch]$DisableScheduledTask,
    [string]$TaskName,
    [string]$TaskPath = '\',
    [switch]$DisableCurrentUserRunEntry,
    [string]$RunValueName,
    [switch]$RunSfc,
    [switch]$RunDism,
    [switch]$DryRun,
    [switch]$Yes,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ScriptVersion = '1.0.0'
$Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$ExitCode = 0
$RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "Boot_Performance_Repair_$Stamp"
}
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$LogPath = Join-Path $OutputPath 'repair.log'
$BackupPath = Join-Path $OutputPath 'backup'
New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS','DRYRUN')][string]$Level = 'INFO'
    )
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    switch ($Level) {
        'WARN'    { Write-Host $Message -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Message -ForegroundColor Red }
        'SUCCESS' { Write-Host $Message -ForegroundColor Green }
        'DRYRUN'  { Write-Host "DRY RUN: $Message" -ForegroundColor Cyan }
        default   { Write-Host $Message }
    }
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Require-Administrator {
    if (-not (Test-IsAdministrator)) {
        throw 'This repair requires an elevated PowerShell session.'
    }
}

function Confirm-Action {
    param(
        [Parameter(Mandatory)][string]$Message,
        [switch]$HighImpact
    )
    if ($DryRun -or $Yes) { return $true }
    $token = if ($HighImpact) { 'REPAIR' } else { 'YES' }
    return (Read-Host "$Message Type $token to continue") -eq $token
}

function Get-CurrentUserRunEntries {
    if (-not (Test-Path -LiteralPath $RunKey)) { return @() }
    $item = Get-ItemProperty -LiteralPath $RunKey -ErrorAction SilentlyContinue
    if (-not $item) { return @() }

    return @(
        $item.PSObject.Properties | Where-Object {
            $_.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$'
        } | ForEach-Object {
            [pscustomobject]@{ Name = $_.Name; Command = [string]$_.Value }
        }
    )
}

function Save-State {
    param([Parameter(Mandatory)][string]$Stage)

    $bootEvents = @()
    try {
        $bootEvents = @(Get-WinEvent -FilterHashtable @{
            LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'
            Id = 100,101,102,103,106,109,110
            StartTime = (Get-Date).AddDays(-7)
        } -ErrorAction Stop | Select-Object -First 100 TimeCreated, Id, LevelDisplayName, Message)
    } catch {}

    $tasks = @(
        Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
            $_.State -ne 'Disabled'
        } | Select-Object TaskName, TaskPath, State, Author, Description
    )

    $state = [ordered]@{
        Stage = $Stage
        Generated = (Get-Date).ToString('o')
        ScriptVersion = $ScriptVersion
        Computer = $env:COMPUTERNAME
        User = "$env:USERDOMAIN\$env:USERNAME"
        IsAdministrator = (Test-IsAdministrator)
        LastBootTime = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).LastBootUpTime
        ExplorerProcesses = @(Get-Process explorer -ErrorAction SilentlyContinue | Select-Object Id, StartTime, Path)
        CurrentUserRunEntries = @(Get-CurrentUserRunEntries)
        EnabledScheduledTasks = @($tasks)
        BootPerformanceEvents = @($bootEvents)
        IconCacheFiles = @(
            Get-ChildItem -LiteralPath $env:LOCALAPPDATA -Filter 'IconCache.db' -File -ErrorAction SilentlyContinue | Select-Object FullName, Length, LastWriteTime
            Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer') -Filter 'iconcache*' -File -ErrorAction SilentlyContinue | Select-Object FullName, Length, LastWriteTime
        )
    }

    $path = Join-Path $OutputPath "$Stage.json"
    $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
    Write-Log "Saved $Stage state to $path." 'SUCCESS'
}

function Invoke-RestartExplorer {
    if (-not (Confirm-Action 'Restart Windows Explorer? The taskbar and desktop will briefly disappear.')) { throw 'User cancelled.' }
    if ($DryRun) {
        Write-Log 'Would restart Windows Explorer.' 'DRYRUN'
        return
    }

    Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
    Write-Log 'Windows Explorer restarted.' 'SUCCESS'
}

function Invoke-ClearIconCache {
    if (-not (Confirm-Action 'Back up and rebuild the current user icon cache? Explorer will restart.')) { throw 'User cancelled.' }

    $paths = @()
    $legacy = Join-Path $env:LOCALAPPDATA 'IconCache.db'
    if (Test-Path -LiteralPath $legacy) { $paths += Get-Item -LiteralPath $legacy }

    $explorerCache = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'
    if (Test-Path -LiteralPath $explorerCache) {
        $paths += @(Get-ChildItem -LiteralPath $explorerCache -Filter 'iconcache*' -File -ErrorAction SilentlyContinue)
    }

    if ($paths.Count -eq 0) {
        Write-Log 'No icon-cache files were found. Explorer will still be restarted.' 'WARN'
    }

    if ($DryRun) {
        foreach ($file in $paths) { Write-Log "Would move $($file.FullName) to the backup folder." 'DRYRUN' }
        Write-Log 'Would restart Explorer after rebuilding the icon cache.' 'DRYRUN'
        return
    }

    Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    $iconBackup = Join-Path $BackupPath 'IconCache'
    New-Item -ItemType Directory -Path $iconBackup -Force | Out-Null
    foreach ($file in $paths) {
        $destination = Join-Path $iconBackup $file.Name
        if (Test-Path -LiteralPath $destination) { $destination = Join-Path $iconBackup "$($file.BaseName)-$Stamp$($file.Extension)" }
        Move-Item -LiteralPath $file.FullName -Destination $destination -Force
        Write-Log "Backed up $($file.FullName) to $destination." 'SUCCESS'
    }

    Start-Process explorer.exe
    Write-Log 'Icon cache rebuilt and Windows Explorer restarted.' 'SUCCESS'
}

function Invoke-DisableScheduledTask {
    Require-Administrator
    if ([string]::IsNullOrWhiteSpace($TaskName)) { throw 'Specify -TaskName for this action.' }
    if ($TaskPath -like '\Microsoft\Windows\*') {
        throw 'Disabling Microsoft Windows system tasks is refused by this toolkit.'
    }

    $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue
    if (-not $task) { throw "Scheduled task '$TaskPath$TaskName' was not found." }

    $taskBackup = Join-Path $BackupPath (($TaskPath.Trim('\') + '_' + $TaskName) -replace '[^a-zA-Z0-9._-]', '_')
    Export-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath |
        Set-Content -LiteralPath "$taskBackup.xml" -Encoding UTF8

    if (-not (Confirm-Action "Disable scheduled task '$TaskPath$TaskName'?" -HighImpact)) { throw 'User cancelled.' }
    if ($DryRun) {
        Write-Log "Would disable scheduled task '$TaskPath$TaskName'." 'DRYRUN'
        return
    }

    Disable-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction Stop | Out-Null
    $after = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction Stop
    if ($after.State -ne 'Disabled') { throw "Scheduled task '$TaskPath$TaskName' was not disabled." }
    Write-Log "Disabled scheduled task '$TaskPath$TaskName'." 'SUCCESS'
}

function Invoke-DisableCurrentUserRunEntry {
    if ([string]::IsNullOrWhiteSpace($RunValueName)) { throw 'Specify -RunValueName for this action.' }
    if (-not (Test-Path -LiteralPath $RunKey)) { throw 'The current-user Run registry key does not exist.' }

    $entry = Get-ItemProperty -LiteralPath $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
    if (-not $entry) { throw "Current-user Run entry '$RunValueName' was not found." }
    $command = [string]$entry.$RunValueName

    & reg.exe export 'HKCU\Software\Microsoft\Windows\CurrentVersion\Run' (Join-Path $BackupPath 'HKCU-Run-before.reg') /y | Out-Null
    [pscustomobject]@{ Name = $RunValueName; Command = $command } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $BackupPath 'disabled-run-entry.json') -Encoding UTF8

    if (-not (Confirm-Action "Disable current-user startup entry '$RunValueName'?" -HighImpact)) { throw 'User cancelled.' }
    if ($DryRun) {
        Write-Log "Would remove current-user Run entry '$RunValueName'." 'DRYRUN'
        return
    }

    Remove-ItemProperty -LiteralPath $RunKey -Name $RunValueName -ErrorAction Stop
    Write-Log "Disabled current-user Run entry '$RunValueName'. Registry backup created." 'SUCCESS'
}

function Invoke-RunSfc {
    Require-Administrator
    if (-not (Confirm-Action 'Run System File Checker? This can take a long time and should not be interrupted.')) { throw 'User cancelled.' }
    if ($DryRun) {
        Write-Log 'Would run sfc.exe /scannow.' 'DRYRUN'
        return
    }

    & sfc.exe /scannow 2>&1 | Tee-Object -FilePath (Join-Path $OutputPath 'sfc-output.txt') | Add-Content -LiteralPath $LogPath
    if ($LASTEXITCODE -notin 0,1,2,3) { throw "SFC returned unexpected exit code $LASTEXITCODE." }
    Write-Log "System File Checker completed with exit code $LASTEXITCODE." 'SUCCESS'
}

function Invoke-RunDism {
    Require-Administrator
    if (-not (Confirm-Action 'Run DISM RestoreHealth? This can take a long time and should not be interrupted.')) { throw 'User cancelled.' }
    if ($DryRun) {
        Write-Log 'Would run DISM /Online /Cleanup-Image /RestoreHealth.' 'DRYRUN'
        return
    }

    & dism.exe /Online /Cleanup-Image /RestoreHealth 2>&1 | Tee-Object -FilePath (Join-Path $OutputPath 'dism-output.txt') | Add-Content -LiteralPath $LogPath
    if ($LASTEXITCODE -ne 0) { throw "DISM returned exit code $LASTEXITCODE." }
    Write-Log 'DISM RestoreHealth completed successfully.' 'SUCCESS'
}

function Invoke-SafeRepairSet {
    Invoke-ClearIconCache
}

Write-Log "Windows Boot Performance Repair Toolkit $ScriptVersion started. DryRun=$DryRun"
Save-State -Stage 'before'

$hasRepair = $RepairAllSafe -or $RestartExplorer -or $ClearIconCache -or $DisableScheduledTask -or $DisableCurrentUserRunEntry -or $RunSfc -or $RunDism
if (-not $hasRepair) {
    Write-Log 'Diagnostic-only run completed. No repair switch was selected.' 'SUCCESS'
    Save-State -Stage 'after'
    exit 0
}

try {
    if ($RepairAllSafe)                { Invoke-SafeRepairSet }
    if ($RestartExplorer)              { Invoke-RestartExplorer }
    if ($ClearIconCache)               { Invoke-ClearIconCache }
    if ($DisableScheduledTask)         { Invoke-DisableScheduledTask }
    if ($DisableCurrentUserRunEntry)   { Invoke-DisableCurrentUserRunEntry }
    if ($RunDism)                      { Invoke-RunDism }
    if ($RunSfc)                       { Invoke-RunSfc }
} catch {
    if ($_.Exception.Message -eq 'User cancelled.') {
        $ExitCode = 10
        Write-Log 'Repair cancelled by the user.' 'WARN'
    } elseif ($_.Exception.Message -match 'elevated') {
        $ExitCode = 4
        Write-Log $_.Exception.Message 'ERROR'
    } elseif ($_.Exception.Message -match 'refused|Specify|not found|does not exist') {
        $ExitCode = 2
        Write-Log $_.Exception.Message 'ERROR'
    } else {
        $ExitCode = 20
        Write-Log $_.Exception.Message 'ERROR'
    }
} finally {
    try { Save-State -Stage 'after' } catch { Write-Log "Post-repair snapshot failed: $($_.Exception.Message)" 'WARN' }
}

if ($ExitCode -eq 0) {
    Write-Log "Completed successfully. Output: $OutputPath" 'SUCCESS'
} else {
    Write-Log "Completed with exit code $ExitCode. Output: $OutputPath" 'ERROR'
}
exit $ExitCode
