#powershell "(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/DarrenWhite99/LabTech-Powershell-Module/DarrenWhite99-P2-Testing/LabTech.psm1') | iex -verbose;(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/DarrenWhite99/LabTech-Powershell-Module/TestScript/ExerciseFunctions.ps1') | iex -verbose"
#https://raw.githubusercontent.com/DarrenWhite99/LabTech-Powershell-Module/master/LabTech.psm1

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
try {Stop-LTService; Sleep 5}
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
try { $BackupSettings | Reinstall-LTService }
catch {'Error running $BackupSettings | Reinstall-LTService'; $($Error[0])}
}
