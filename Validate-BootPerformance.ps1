#requires -Version 5.1
<# Created by Dewald Pretorius. Read-only Windows boot duration validator. #>
[CmdletBinding()]
param([ValidateRange(10,600)][int]$MaximumBootSeconds=120,[string]$OutputPath=(Join-Path ([Environment]::GetFolderPath('Desktop')) 'Boot_Performance_Validation'))
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
try{
 $event=Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Diagnostics-Performance/Operational';Id=100} -MaxEvents 1 -ErrorAction Stop
 $bootSeconds=[math]::Round(([double]$event.Properties[6].Value)/1000,2)
 $result=[ordered]@{Generated=(Get-Date);BootSeconds=$bootSeconds;ThresholdSeconds=$MaximumBootSeconds;Status=$(if($bootSeconds-gt$MaximumBootSeconds){'Warning'}else{'Healthy'})}
 $result|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $OutputPath "boot_validation_$stamp.json") -Encoding UTF8
 if($bootSeconds-gt$MaximumBootSeconds){Write-Warning "Boot duration is $bootSeconds seconds.";exit 1}
 Write-Host 'Boot performance validation passed.' -ForegroundColor Green;exit 0
}catch{Write-Error $_.Exception.Message;exit 5}
