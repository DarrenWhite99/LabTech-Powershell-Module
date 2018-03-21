#start powershell -noexit "$LabtechModule='https://raw.githubusercontent.com/DarrenWhite99/LabTech-Powershell-Module/master/LabTech.psm1'; (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/DarrenWhite99/LabTech-Powershell-Module/TestScript/ExerciseFunctions.ps1') | iex -verbose"
#start powershell -noexit "$LabtechModule='https://raw.githubusercontent.com/DarrenWhite99/LabTech-Powershell-Module/master/LabTech.psm1'; (New-Object Net.WebClient).DownloadString('C:\Users\Dwhite\Documents\GitHub\LabTech-Powershell-Module\ExerciseFunctions.ps1') | iex -verbose"
#https://raw.githubusercontent.com/DarrenWhite99/LabTech-Powershell-Module/master/LabTech.psm1

$DebugPreference='Continue'
$InformationPreference='Continue'
$VerbosePreference='Continue'
$ErrorActionPreference='Continue'
$WarningPreference='Continue'

$DestModulePath="$($Env:windir)\temp\labtech-$(Get-Random -Minimum 10000 -Maximum 99999).psm1"
If ($LabtechModule -match '//') {
  If (-not ($LabtechModule -match 'https?://.+')) {"Invalid URL format specified: $($LabtechModule)"; return}
  (New-Object Net.WebClient).DownloadFile($LabtechModule,$DestModulePath)
} ElseIf (($LabtechModule) -and (Test-Path $LabtechModule)) {
  Copy-Item $LabtechModule $DestModulePath -Force
} Else {"Could not find source $($LabtechModule)"; return}
If (-not (Test-Path $DestModulePath)) {"Failed to prepare local copy of $($LabtechModule) in $($DestModulePath)"}

$DestModulePath=Get-Item $DestModulePath

#Starting Script
function WhatIfTests {
$DebugPreference='Continue'
$InformationPreference='Continue'
$VerbosePreference='Continue'
$ErrorActionPreference='Stop'
$WarningPreference='Stop'

'Checking if LTService is installed'

If (-not (Get-LTServiceInfo -EA 0)) {
    'LTService is not installed. Switching Error and Warning Action Preference to Continue'
    $ErrorActionPreference='Continue'
    $WarningPreference='Continue'
}

'Running "WhatIf" tests - Any hard errors will stop the script.'

#'Whatif Testing Get-LTServiceSettings'; Get-LTServiceSettings -WhatIf
#'Whatif Testing New-LTServiceBackup'; New-LTServiceBackup -WhatIf
#'Whatif Checking LT Backup Info'; Get-LTServiceInfoBackup -WhatIf

'Whatif Testing Get-LTServiceInfo'; Get-LTServiceInfo -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Restart-LTService'; Restart-LTService -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Stop-LTService'; Stop-LTService -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Start-LTService'; Start-LTService -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Reinstall-LTService'; Reinstall-LTService -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Get-LTServiceInfo | Uninstall-LTService'; Get-LTServiceInfo -EA 0 -WA 0 | Uninstall-LTService -WhatIf -EA $ErrorActionPreference -WA 'Continue'
'Whatif Running Get-LTServiceInfo | Install-LTService'; Get-LTServiceInfo -EA 0 -WA 0 | Install-LTService -EA $ErrorActionPreference -Force -WA 'Continue' -WhatIf

'Whatif Running Hide-LTAddRemove'; Hide-LTAddRemove -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Show-LTAddRemove'; Show-LTAddRemove -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Rename-LTAddRemove'; Rename-LTAddRemove -Name 'Automate Testing Agent' -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Rename-LTAddRemove with Publisher'; Rename-LTAddRemove -Name 'Automate Testing Agent' -PublisherName 'Automate Testing Inc.' -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Invoke-LTServiceCommand ''Send Status'''; Invoke-LTServiceCommand 'Send Status' -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running ''Send Status'' | Invoke-LTServiceCommand'; 'Send Status' | Invoke-LTServiceCommand -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Set-LTProxy -ProxyServerURL ''http://www.notrealproxy.com/'''; Set-LTProxy -ProxyServerURL 'http://www.notrealproxy.com/' -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Set-LTProxy -ProxyServerURL ''http://www.notrealproxy.com/'' -ProxyUsername ''proxyuser'' -ProxyPassword ''123'' -WhatIf'; Set-LTProxy -ProxyServerURL 'http://www.notrealproxy.com/' -ProxyUsername 'proxyuser' -ProxyPassword '123' -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Set-LTProxy -Clear'; Set-LTProxy -Clear -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Set-LTProxy -Detect'; Set-LTProxy -Detect -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Reset-LTService'; Reset-LTService -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Reset-LTService -MAC -Nowait'; Reset-LTService -MAC -Nowait -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Reset-LTService -MAC -Location -ID -WhatIf'; Reset-LTService -MAC -Location -ID -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
'Whatif Running Reset-LTService -Nowait -WhatIf'; Reset-LTService -Nowait -WhatIf -EA $ErrorActionPreference -WA $WarningPreference
}

function Round1Tests {
'Running Round 1 Tests'
$DebugPreference='Continue'
$InformationPreference='Continue'
$VerbosePreference='Continue'
$ErrorActionPreference='Continue'
$WarningPreference='Continue'

'Running Test-LTPorts -Quiet'
try {Test-LTPorts -Quiet}
catch {'Error running Test-Ports -Quiet'; $($Error[0])}

'Running Test-LTPorts'
try {Test-LTPorts}
catch {'Error running Test-LTPorts'; $($Error[0])}

try {if (!($Global:LTServiceInfo)) {'Loading from Get-LTServiceInfo'; $Global:LTServiceInfo = Get-LTServiceInfo}}
catch {'Error Get-LTServiceInfo'; $($Error[0])}
if (!($Global:LTServiceInfo)) {'Could not get LTServiceInfo'} else {$Global:LTServiceInfo}
try {if (!($Global:LTServiceSettings)) {'Loading from Get-LTServiceSettings'; $Global:LTServiceSettings = Get-LTServiceSettings}}
catch {'Error running Get-LTServiceSettings'; $($Error[0])}
if (!($Global:LTServiceSettings)) {'Could not get LTServiceSettings'} else {$Global:LTServiceSettings}

'Running New-LTServiceBackup'
try {New-LTServiceBackup}
catch {'Error running New-LTServiceBackup'; $($Error[0])}

'Running Restart-LTService'
try {Restart-LTService}
catch {'Error running Restart-LTService'; $($Error[0])}

'Checking LT Backup Settings' 
try {$Global:BackupSettings = Get-LTServiceInfoBackup -ErrorAction SilentlyContinue}
catch {}
if (!($Global:BackupSettings)) {'Error - Could not get BackupSettings'} else {$Global:BackupSettings}

'Running Stop-LTService'
try {Stop-LTService; Start-Sleep 5}
catch {'Error running Stop-LTService'; $($Error[0])}
}

function Round2Tests {
'Running Round 2 Tests'

$DebugPreference='Continue'
$InformationPreference='Continue'
$VerbosePreference='Continue'
$ErrorActionPreference='Continue'
$WarningPreference='Continue'
'Running Start-LTService'
try {Start-LTService}
catch {'Error running Start-LTService'; $($Error[0])}

'Running $Global:BackupSettings | Reinstall-LTService'
    $Global:BackupSettings | Reinstall-LTService -ErrorAction Stop

    'Reinstall Succeeded. Testing Uninstall/Reinstall individually.'
    if (!($Global:BackupSettings)) {$Global:BackupSettings = Get-LTServiceInfo -ErrorAction Stop}
  
    Start-Sleep 10 
    'Running Get-LTServiceInfo | Uninstall-LTService'
    try { Get-LTServiceInfo | Uninstall-LTService }
    catch {'Error running Get-LTServiceInfo | Uninstall-LTService'; $($Error[0])}
}

function Round3Tests {
    'Running Round 3 Tests'

    $DebugPreference='Continue'
    $InformationPreference='Continue'
    $VerbosePreference='Continue'
    $ErrorActionPreference='Continue'
    $WarningPreference='Continue'

    Start-Sleep 10 
    'Running $Global:BackupSettings | Install-LTService'
    try { $Global:BackupSettings | Install-LTService }
    catch {'Error running $Global:BackupSettings | Install-LTService'; $($Error[0])}

    $LTSI=(Get-LTServiceInfo -EA 0 |Get-Member -EA 0|Select-Object -Expand Name -EA 0)
    $AllFound=$True; @('ID','Server Address','LocationID','MAC') | ForEach-Object {if ($LTSI -notcontains $_) {$AllFound=$False}}
    if ($AllFound -eq $True) {
      Try {
        'Running Get-LTServiceInfo | Install-LTService on top of existing install.'
        Stop-LTService
        sc.exe delete ltsvcmon
        sc.exe delete ltservice
        Get-LTServiceInfo  | Install-LTService
      } catch {'Error running $Global:BackupSettings | Install-LTService'; $($Error[0])}
    }
}


Import-Module $DestModulePath.FullName
WhatIfTests
Remove-Module $DestModulePath.BaseName
'Done with -WhatIf tests.. Moving on to LIVE tests. Observing 30 seconds of silence.'

Start-Sleep 30

Import-Module $DestModulePath.FullName
Round1Tests
Remove-Module $DestModulePath.BaseName
'Done with Round1 tests..'
Start-Sleep 5

Import-Module $DestModulePath.FullName
Round2Tests
WhatIfTests
Remove-Module $DestModulePath.BaseName
'Done with Round2 tests'
Start-Sleep 5

Import-Module $DestModulePath.FullName
Round3Tests
Remove-Module $DestModulePath.BaseName
'Done with Round3 tests'
Start-Sleep 5

'Switching from Module Mode to IEX mode'

(Get-Content $DestModulePath.FullName|Out-String)|iex;
WhatIfTests
'Done with -WhatIf tests.. Moving on to LIVE tests. Observing 30 seconds of silence.'
Start-Sleep 30

(Get-Content $DestModulePath.FullName|Out-String)|iex;
Round1Tests
'Done with Round1 tests..'
Start-Sleep 5

(Get-Content $DestModulePath.FullName|Out-String)|iex;
Round2Tests
'Done with Round2 tests'
Start-Sleep 5

(Get-Content $DestModulePath.FullName|Out-String)|iex;
Round3Tests
'Done with Round3 tests'
