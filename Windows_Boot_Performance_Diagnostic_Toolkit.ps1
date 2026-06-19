#requires -Version 5.1
[CmdletBinding()]
param([int]$Days=7,[string]$OutputPath)
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Boot_Performance_Reports'}
New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null
$os=Get-CimInstance Win32_OperatingSystem
$summary=[PSCustomObject]@{Computer=$env:COMPUTERNAME;OS=$os.Caption;Build=$os.BuildNumber;LastBoot=$os.LastBootUpTime;UptimeHours=[math]::Round(((Get-Date)-$os.LastBootUpTime).TotalHours,2);Generated=Get-Date}
$start=(Get-Date).AddDays(-1*$Days)
$events=Get-WinEvent -FilterHashtable @{LogName='System';StartTime=$start;Id=12,13,41,1074,6005,6006,6008} -ErrorAction SilentlyContinue|Select-Object TimeCreated,Id,ProviderName,LevelDisplayName,Message
$startup=Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue|Select-Object Name,Command,Location,User
$summary|Export-Csv (Join-Path $OutputPath "boot_summary_$stamp.csv") -NoTypeInformation -Encoding UTF8
$events|Export-Csv (Join-Path $OutputPath "boot_events_$stamp.csv") -NoTypeInformation -Encoding UTF8
$startup|Export-Csv (Join-Path $OutputPath "startup_items_$stamp.csv") -NoTypeInformation -Encoding UTF8
@{Summary=$summary;Events=$events;StartupItems=$startup}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $OutputPath "boot_report_$stamp.json") -Encoding UTF8
$html="<h1>Boot Performance - $env:COMPUTERNAME</h1><p>Generated $(Get-Date)</p><h2>Summary</h2>$(@($summary)|ConvertTo-Html -Fragment)<h2>Boot Events</h2>$($events|ConvertTo-Html -Fragment)<h2>Startup Items</h2>$($startup|ConvertTo-Html -Fragment)"
$html|ConvertTo-Html -Title 'Boot Performance'|Set-Content (Join-Path $OutputPath "boot_report_$stamp.html") -Encoding UTF8
$summary|Format-List
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
