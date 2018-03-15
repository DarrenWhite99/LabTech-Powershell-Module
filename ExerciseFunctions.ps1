#powershell "(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/DarrenWhite99/LabTech-Powershell-Module/ProxyAware/LabTech.psm1') | iex -verbose;(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/DarrenWhite99/LabTech-Powershell-Module/TestScript/ExerciseFunctions.ps1') | iex -verbose"
#https://raw.githubusercontent.com/DarrenWhite99/LabTech-Powershell-Module/master/LabTech.psm1

$DebugPreference='Continue'
$ErrorActionPreference='Continue'
$InformationPreference='Continue'
$VerbosePreference='Continue'
$WarningPreference='Continue'

'Running "WhatIf" tests'
'Running Test-LTPorts'; try {Test-LTPorts -WhatIf} catch {'Error running Test-LTPorts'; $($Error[0])}
'Testing Get-LTServiceSettings'; try { Get-LTServiceSettings -WhatIf} catch {'Error'; $($Error[0])}
'Testing New-LTServiceBackup'; try {New-LTServiceBackup -WhatIf} catch {'Error'; $($Error[0])}
'Checking LT Backup Settings'; try {Get-LTServiceInfoBackup -WhatIf} catch {'Error'; $($Error[0])}

'Testing Get-LTServiceInfo'; try {Get-LTServiceInfo -WhatIf} catch {'Error'; $($Error[0])}
'Running Restart-LTService'; try {Restart-LTService -WhatIf} catch {'Error'; $($Error[0])}
'Running Stop-LTService'; try {Stop-LTService -WhatIf} catch {'Error running Stop-LTService'; $($Error[0])}
'Running Start-LTService'; try {Start-LTService -WhatIf} catch {'Error running Start-LTService'; $($Error[0])}
'Running Reinstall-LTService'; try {Reinstall-LTService -WhatIf} catch {'Error running Reinstall-LTService'; $($Error[0])}
'Running Get-LTServiceInfo | Uninstall-LTService'; try { Get-LTServiceInfo | Uninstall-LTService -WhatIf} catch {'Error running Get-LTServiceInfo | Uninstall-LTService'; $($Error[0])}
'Running $BackupSettings | Install-LTService'; try { Get-LTServiceInfo | Install-LTService -WhatIf} catch {'Error running Get-LTServiceInfo | Install-LTService'; $($Error[0])}

'Done with -WhatIf tests.. Moving on to LIVE tests. Observing 30 seconds of silence.'
Start-Sleep 30

'Running Test-LTPorts -Quiet'
try {Test-LTPorts -Quiet}
catch {'Error running Test-Ports -Quiet'; $($Error[0])}

'Running Test-LTPorts'
try {Test-LTPorts}
catch {'Error running Test-LTPorts'; $($Error[0])}

try {if (!($LTServiceInfo)) {'Loading from Get-LTServiceInfo'; $LTServiceInfo = Get-LTServiceInfo}}
catch {'Error Get-LTServiceInfo'; $($Error[0])}
if (!($LTServiceInfo)) {'Could not get LTServiceInfo'} else {$LTServiceInfo}
try {if (!($LTServiceSettings)) {'Loading from Get-LTServiceSettings'; $LTServiceSettings = Get-LTServiceSettings}}
catch {'Error running Get-LTServiceSettings'; $($Error[0])}
if (!($LTServiceSettings)) {'Could not get LTServiceSettings'} else {$LTServiceSettings}

'Running New-LTServiceBackup'
try {New-LTServiceBackup}
catch {'Error running New-LTServiceBackup'; $($Error[0])}

'Running Restart-LTService'
try {Restart-LTService}
catch {'Error running Restart-LTService'; $($Error[0])}

'Checking LT Backup Settings' 
try {$BackupSettings = Get-LTServiceInfoBackup -ErrorAction SilentlyContinue}
catch {}
if (!($BackupSettings)) {'Error - Could not get BackupSettings'} else {$BackupSettings}

'Running Stop-LTService'
try {Stop-LTService; Start-Sleep 5}
catch {'Error running Stop-LTService'; $($Error[0])}

'Running Start-LTService'
try {Start-LTService}
catch {'Error running Start-LTService'; $($Error[0])}

if (!($BackupSettings)) {
  'Running Reinstall-LTService'
  try {Reinstall-LTService}
  catch {'Error running Reinstall-LTService'; $($Error[0])}
} else {
  'Running $BackupSettings | Reinstall-LTService'
  try { $BackupSettings | Reinstall-LTService 

    'Reinstall Succeeded. Testing Uninstall/Reinstall individually.'
    'Running Get-LTServiceInfo | Uninstall-LTService'
    try { Get-LTServiceInfo | Uninstall-LTService }
    catch {'Error running Get-LTServiceInfo | Uninstall-LTService'; $($Error[0])}

    Start-Sleep 10 
    'Running $BackupSettings | Install-LTService'
    try { $BackupSettings | Install-LTService }
    catch {'Error running $BackupSettings | Install-LTService'; $($Error[0])}

    if ($(Get-LTServiceInfo -EA 0 |Get-Member -EA 0|Select-Object -Expand Name -EA 0) -contains ('ID','Server Address','LocationID','MAC')) {
      'Running Get-LTServiceInfo | Install-LTService on top of existing install.'
      net.exe stop ltsvcmon
      net.exe stop ltservice
      sc.exe delete ltsvcmon
      sc.exe delete ltservice
      Get-LTServiceInfo  | Install-LTService
    }

  }
  catch {'Error running $BackupSettings | Reinstall-LTService'; $($Error[0])}
}


