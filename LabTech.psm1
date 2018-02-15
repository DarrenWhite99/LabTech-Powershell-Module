<#
.SYNOPSIS
    This is a PowerShell Module for LabTech.
    labtechconsulting.com
    labtechsoftware.com
    msdn.microsoft.com/powershell


.DESCRIPTION
    This is a set of commandlets to interface with the LabTech Agent.
    Tested Versions: v10.5, v11, v12

.NOTES
    Version:        1.4
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2

    Update Date: 1/23/2018
    Purpose/Change: Updates to address 32-bit vs. 64-bit operations.

    Update Date: 2/1/2018
    Purpose/Change: Updates for support of Proxy Settings. Enabled -WhatIf processing for many functions.

#>

if (-not ($PSVersionTable)) {Write-Warning 'PS1 Detected. PowerShell Version 2.0 or higher is required.';return}
if (-not ($PSVersionTable) -or $PSVersionTable.PSVersion.Major -lt 3 ) {Write-Verbose 'PS2 Detected. PowerShell Version 3.0 or higher may be required for full functionality'}

#Module Version
$ModuleVersion = "1.4"

if ($env:PROCESSOR_ARCHITEW6432 -match '64' -and [IntPtr]::Size -ne 8) {
    Write-Warning '32-bit PowerShell session detected on 64-bit OS. Attempting to launch 64-Bit session to process commands.'
    if ($myInvocation.Line) {
        &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile $myInvocation.Line
    } elseif ($myInvocation.InvocationName) {
        &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile -file "$($myInvocation.InvocationName)" $args
    } else {
        &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile $myInvocation.MyCommand
    }
    Write-Warning 'Exiting 64-bit session. Module will only remain loaded in native 64-bit PowerShell environment.'
exit $lastexitcode
}

#Ignore SSL errors
Add-Type -Debug:$False @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

#region [Functions]-------------------------------------------------------------

Function Get-LTServiceInfo{ 
#region [Get-LTServiceInfo]-----------------------------------------------------
<#
.SYNOPSIS
    This function will pull all of the registry data into an object.

.NOTES
    Version:        1.2
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
    Update Date: 8/24/2017
    Purpose/Change: Update to use Clear-Variable.
    
.LINK
    http://labtechconsulting.com
#> 
    [CmdletBinding()]
    Param ()
      
  Begin
  {
    Clear-Variable key,BasePath,exclude,Servers -EA 0 #Clearing Variables for use
    Write-Verbose "Starting Get-LTServiceInfo"

    if ((Test-Path 'HKLM:\SOFTWARE\LabTech\Service') -eq $False){
        Write-Error "ERROR: Unable to find information on LTSvc. Make sure the agent is installed."
        Return
    }
    $exclude = "PSParentPath","PSChildName","PSDrive","PSProvider","PSPath"
  }#End Begin
  
  Process{
    Write-Verbose "Checking for LT Service registry keys."
    Try{
        $key = Get-ItemProperty HKLM:\SOFTWARE\LabTech\Service -ErrorAction Stop | Select-Object * -exclude $exclude
        if (($key) -ne $Null -and -not ($key|Get-Member |Where-Object {$_.Name -match 'BasePath'})) {
            if (Test-Path HKLM:\SYSTEM\CurrentControlSet\Services\LTService) {
                $BasePath = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\LTService -ErrorAction Stop|Select-object -Expand ImagePath -EA 0).Split('"')|Where-Object {$_}|Select-Object -First 1|Get-Item|Select-object -Expand DirectoryName -EA 0
            } Else {
                $BasePath = "$env:windir\LTSVC" 
            }
            Add-Member -InputObject $key -MemberType NoteProperty -Name BasePath -Value $BasePath
        }
        $key.BasePath = [System.Environment]::ExpandEnvironmentVariables($($key|Select-object -Expand BasePath -EA 0))
        if (($key) -ne $Null -and ($key|Get-Member|Where-Object {$_.Name -match 'Server Address'})) {
        $Servers = ($Key|Select-Object -Expand 'Server Address' -EA 0).Split('|')|ForEach-Object {$_.Trim()}
        Add-Member -InputObject $key -MemberType NoteProperty -Name 'Server' -Value $Servers -Force
    }
    }#End Try
    
    Catch{
      Write-Error "ERROR: There was a problem reading the registry keys. $($Error[0])"
    }#End Catch
  }#End Process
  
  End{
    if ($?){
        $key
    }    
  }#End End
}#End Function Get-LTServiceInfo
#endregion Get-LTServiceInfo

Function Get-LTServiceSettings{ 
#region [Get-LTServiceSettings]-------------------------------------------------
<#
.SYNOPSIS
    This function will pull the registry data from HKLM:\SOFTWARE\LabTech\Service\Settings into an object.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#> 
    [CmdletBinding()]
    Param ()
      
  Begin{
    Write-Verbose "Checking for registry keys."
    if ((Test-Path 'HKLM:\SOFTWARE\LabTech\Service\Settings') -eq $False){
        Write-Error "ERROR: Unable to find LTSvc settings. Make sure the agent is installed." 
    }
    $exclude = "PSParentPath","PSChildName","PSDrive","PSProvider","PSPath"
  }#End Begin
  
  Process{
    Try{
        Get-ItemProperty HKLM:\SOFTWARE\LabTech\Service\Settings -ErrorAction Stop | Select-Object * -exclude $exclude
    }#End Try
    
    Catch{
      Write-Error "ERROR: There was a problem reading the registry keys. $($Error[0])"
    }#End Catch
  }#End Process
  
  End{
    if ($?){
        $key
    }    
  }#End End
}#End Function Get-LTServiceSettings
#endregion LTServiceSettings

Function Restart-LTService{
#region [Restart-LTService]-----------------------------------------------------
<#
.SYNOPSIS
    This function will restart the LabTech Services.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#> 
  
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param()
  
    Begin{
        if (-not (Get-Service 'LTService','LTSvcMon' -ErrorAction SilentlyContinue)) {
            Write-Error "ERROR: Services NOT Found $($Error[0])" -ErrorAction Stop
        }
    }#End Begin

    Process{
        Try{
            Stop-LTService
        }#End Try
        Catch{
            Write-Error "ERROR: There was an error restarting the services. $($Error[0])" -ErrorAction Stop
        }#End Catch

        Try{
            Start-LTService
        }#End Try
        Catch{
            Write-Error "ERROR: There was an error starting the services. $($Error[0])" -ErrorAction Stop
        }#End Catch
    }#End Process

    End{
        If ($?){Write-Output "Services Restarted successfully."}
        Else {$Error[0]}
    }#End End
}#End Function Restart-LTService
#endregion Restart-LTService

Function Stop-LTService{
#region [Stop-LTService]--------------------------------------------------------
<#
.SYNOPSIS
    This function will stop the LabTech Services.

.DESCRIPTION
    This function will verify that the LabTech services are present then attempt to stop them.
    It will then check for any remaining LabTech processes and kill them.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#>   
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param()
  
    Begin{
        Clear-Variable sw,timeout,svcRun -EA 0 #Clearing Variables for use
        if (-not (Get-Service 'LTService','LTSvcMon' -ErrorAction SilentlyContinue)) {
            Write-Error "ERROR: Services NOT Found $($Error[0])" -ErrorAction Stop
        }
    }#End Begin

    Process{

        $Null=Invoke-LTServiceCommand ('Kill VNC','Kill Trays') -EA 0

        Write-Verbose "Stopping Labtech Services"
        If ($PSCmdlet.ShouldProcess("LTService and LTSvcMon", "Stop-Service")) {
            Try{
                ('LTService','LTSvcMon') | Foreach-Object {$Null=sc.exe stop "$($_)" 2>''} 
                $timeout = new-timespan -Minutes 1
                $sw = [diagnostics.stopwatch]::StartNew()
                Write-Host -NoNewline "Waiting for Services to Stop." 
                Do {
                    Write-Host -NoNewline '.'
                    Start-Sleep 2
                    $svcRun = ('LTService','LTSvcMon') | Get-Service -EA 0 | Where-Object {$_.Status -ne 'Stopped'} | Measure-Object | Select-Object -Expand Count
                } until ($sw.elapsed -gt $timeout -or $svcRun -eq 0)
                Write-Host ""
                $sw.Stop()
                if ($svcRun -gt 0) {
                    Write-Verbose "Services did not stop. Terminating Processes after $(([int32]$sw.Elapsed.TotalSeconds).ToString()) seconds."
                }
                Get-Process | Where-Object {@('LTTray','LTSVC','LTSvcMon') -contains $_.ProcessName } | Stop-Process -Force -ErrorAction Stop
            }#End Try

            Catch{
                Write-Error "ERROR: There was an error stopping the LabTech processes. $($Error[0])" -ErrorAction Stop
            }#End Catch
        }#End If
    }#End Process

    End{
        If ($?){
            Write-Output "Services Stopped successfully."
        }
        Else {$Error[0]}
    }#End End
}#End Function Stop-LTService
#endregion Stop-LTService

Function Start-LTService{
#region [Start-LTService]-------------------------------------------------------
<#
.SYNOPSIS
    This function will start the LabTech Services.

.DESCRIPTION
    This function will verify that the LabTech services are present.
    It will then check for any process that is using the LTTray port (Default 42000) and kill it.
    Next it will start the services.

.NOTES
    Version:        1.2
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 5/11/2017
    Purpose/Change: added check for non standard port number and set services to auto start

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2

    Update Date: 12/14/2017
    Purpose/Change: Will increment the tray port if a conflict is detected.

    Update Date: 2/1/2018
    Purpose/Change: Added support for -WhatIf. Added Service Control Command to request agent check-in immediately after startup.

    .LINK
    http://labtechconsulting.com
#>
    
    [CmdletBinding(SupportsShouldProcess=$True)]
    Param()   
    
    Begin{
        if (-not (Get-Service 'LTService','LTSvcMon' -ErrorAction SilentlyContinue)) {
            Write-Error "ERROR: Services NOT Found $($Error[0])" -ErrorAction Stop
        }
        #Kill all processes that are using the tray port 
        [array]$processes = @()
        $Port = (Get-LTServiceInfo -EA 0 -Verbose:$False|Select-Object -Expand TrayPort -EA 0)
        if (-not ($Port)) {$Port = "42000"}
    }#End Begin
    
    Process{

        Try{
            $netstat = netstat.exe -a -o -n | Select-String -Pattern " .*[0-9\.]+:$($Port).*[0-9\.]+:[0-9]+ .*?([0-9]+)" -EA 0
            foreach ($line in $netstat){
                $processes += ($line -split '  {3,}')[-1]
            }
            $processes = $processes | Where-Object {$_ -gt 0 -and $_ -match '^\d+$'}| Sort-Object | Get-Unique
            if ($processes) {
                foreach ($proc in $processes){
                    If ($PSCmdlet.ShouldProcess("$proc", "Terminate Process")) {
                        Write-Output "Process ID:$proc is using port $Port. Killing process."
                        Try{Stop-Process -ID $proc -Force -Verbose -EA Stop}
                        Catch {
                            Write-Warning "There was an issue killing the following process: $proc"
                            Write-Warning "This generally means that a 'protected application' is using this port."
                            $newPort = [int]$port + 1
                            if($newPort > 42009) {$newPort = 42000}
                            Write-Warning "Setting tray port to $newPort."
                            New-ItemProperty -Path "HKLM:\Software\Labtech\Service" -Name TrayPort -PropertyType String -Value $newPort -Force | Out-Null
                        }#End Catch
                    }#End If
                }#End foreach
            }#End If
            @('LTService','LTSvcMon') | ForEach-Object {
                If (Get-Service $_ -EA 0) {
                    Set-Service $_ -StartupType Automatic -EA 0
                    $Null=sc.exe start "$($_)" 2>''
                    Write-Debug "Executed Start Service for $($_)"
                }#End If
            }#End ForEach-Object
        }#End Try
    
        Catch{
            Write-Error "ERROR: There was an error starting the LabTech services. $($Error[0])" -ErrorAction Stop
        }#End Catch
    }#End Process
    
    End
    {
        If ($PSCmdlet.ShouldProcess("LTService", "Issue Service Control Request for Agent Status Update")) {
            If ($?){
                $svcRun = ('LTService') | Get-Service -EA 0 | Where-Object {$_.Status -ne 'Running'} | Measure-Object | Select-Object -Expand Count
                if ($svcRun -gt 0) {
                    $timeout = new-timespan -Minutes 1
                    $sw = [diagnostics.stopwatch]::StartNew()
                    Write-Host -NoNewline "Waiting for Services to Start." 
                    Do {
                        Write-Host -NoNewline '.'
                        Start-Sleep 2
                        $svcRun = ('LTService') | Get-Service -EA 0 | Where-Object {$_.Status -ne 'Running'} | Measure-Object | Select-Object -Expand Count
                    } until ($sw.elapsed -gt $timeout -or $svcRun -eq 0)
                    Write-Host ""
                    $sw.Stop()
                }
                if ($svcRun -eq 0) {
                    $Null=Invoke-LTServiceCommand 'Send Status' -EA 0
                    Write-Output "Services Started successfully."
                } Else {
                    Write-Output "Service Start was issued but LTService has not reached Running state."
                }
            }
            else{
                    $($Error[0])
            }
        }#End If
    }#End End
}#End Function Start-LTService
#endregion Start-LTService

Function Uninstall-LTService{
#region [Uninstall-LTService]---------------------------------------------------
<#
.SYNOPSIS
    This function will uninstall the LabTech agent from the machine.

.DESCRIPTION
    This function will stop all the LabTech services. It will then download the current agent install MSI and issue an uninstall command.
    It will then download and run Agent_Uninstall.exe from the LabTech server. It will then scrub any remaining file/registry/service data.

.PARAMETER Server
    This is the URL to your LabTech server. 
    Example: https://lt.domain.com
    This is used to download the uninstall utilities.
    If no server is provided the uninstaller will use Get-LTServiceInfo to get the server address.

.PARAMETER Backup
    This will run a 'New-LTServiceBackup' before uninstalling.

.EXAMPLE
    Uninstall-LTService
    This will uninstall the LabTech agent using the server address in the registry.

.EXAMPLE
    Uninstall-LTService -Server 'https://lt.domain.com'
    This will uninstall the LabTech agent using the provided server URL to download the uninstallers.

.NOTES
    Version:        1.4
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
    Update Date: 6/10/2017
    Purpose/Change: Updates for pipeline input, support for multiple servers
    
    Update Date: 6/24/2017
    Purpose/Change: Update to detect Server Version and use updated URL format for LabTech 11 Patch 13.
    
    Update Date: 8/24/2017
    Purpose/Change: Update to use Clear-Variable. Modifications to Folder and Registry Delete steps. Additional Debugging.

    Update Date: 1/26/2017
    Purpose/Change: Added support for Proxy Server for Download and Installation steps.

.LINK
    http://labtechconsulting.com
#> 
    [CmdletBinding(SupportsShouldProcess=$True)]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string[]]$Server,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$Backup = $False
    )   
    Begin{
        Clear-Variable Executables,BasePath,reg,regs,installer,installerTest,installerResult,uninstaller,uninstallerTest,uninstallerResult,xarg,Svr,SVer,SvrVer,SvrVerCheck,GoodServer,Item -EA 0 #Clearing Variables for use
        If (-not ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()|Select-object -Expand groups -EA 0) -match 'S-1-5-32-544'))) {
            Throw "Needs to be ran as Administrator" 
        }
        if ($Backup){
            New-LTServiceBackup
        }
        $BasePath = $(Get-LTServiceInfo -EA 0 -Verbose:$False|Select-Object -Expand BasePath -EA 0)
        if (-not ($BasePath)){$BasePath = "$env:windir\LTSVC"}
        New-PSDrive HKU Registry HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
        $regs = @( 'Registry::HKEY_LOCAL_MACHINE\Software\LabTechMSP',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\LabTech\Service',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\LabTech\LabVNC',
            'Registry::HKEY_LOCAL_MACHINE\Software\Wow6432Node\LabTech\Service',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\Managed\\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\D1003A85576B76D45A1AF09A0FC87FAC\InstallProperties',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{3426921d-9ad5-4237-9145-f15dee7e3004}',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Appmgmt\{40bf8c82-ed0d-4f66-b73e-58a3d7ab6582}',
            'Registry::HKEY_CLASSES_ROOT\Installer\Dependencies\{3426921d-9ad5-4237-9145-f15dee7e3004}',
            'Registry::HKEY_CLASSES_ROOT\Installer\Dependencies\{3F460D4C-D217-46B4-80B6-B5ED50BD7CF5}',
            'Registry::HKEY_CLASSES_ROOT\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
            'Registry::HKEY_CLASSES_ROOT\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{09DF1DCA-C076-498A-8370-AD6F878B6C6A}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{15DD3BF6-5A11-4407-8399-A19AC10C65D0}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{3C198C98-0E27-40E4-972C-FDC656EC30D7}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{459C65ED-AA9C-4CF1-9A24-7685505F919A}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{7BE3886B-0C12-4D87-AC0B-09A5CE4E6BD6}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{7E092B5C-795B-46BC-886A-DFFBBBC9A117}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{9D101D9C-18CC-4E78-8D78-389E48478FCA}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{B0B8CDD6-8AAA-4426-82E9-9455140124A1}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{B1B00A43-7A54-4A0F-B35D-B4334811FAA4}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{BBC521C8-2792-43FE-9C91-CCA7E8ACBCC9}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{C59A1D54-8CD7-4795-AEDD-F6F6E2DE1FE7}',
            'Registry::HKEY_CLASSES_ROOT\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
            'Registry::HKEY_CLASSES_ROOT\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC',
            'Registry::HKEY_CURRENT_USER\SOFTWARE\LabTech\Service',
            'Registry::HKEY_CURRENT_USER\SOFTWARE\LabTech\LabVNC',
            'Registry::HKEY_CURRENT_USER\Software\Microsoft\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
            'HKU:\*\Software\Microsoft\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F'
        )

        #Cleanup previous uninstallers
        Remove-Item 'Uninstall.exe','Uninstall.exe.config' -ErrorAction SilentlyContinue

        New-Item $env:windir\temp\LabTech\Installer -type directory -ErrorAction SilentlyContinue | Out-Null

        $xarg = "/x `"$($env:windir)\temp\LabTech\Installer\Agent_Install.msi`" /qn"
    }#End Begin
  
    Process{
        if (-not ($Server)){
            $Server = Get-LTServiceInfo -EA 0 -Verbose:$False|Select-Object -Expand 'Server' -EA 0
        }
        if (-not ($Server)){
            $Server = Read-Host -Prompt 'Provide the URL to your LabTech server (https://lt.domain.com):'
        }
        Foreach ($Svr in $Server) {
        if (-not ($GoodServer)) {
                if ($Svr -match '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*){1,})$') {
                    Try{
                        if ($Svr -notmatch 'https?://.+') {$Svr = "http://$($Svr)"}
                        $SvrVerCheck = "$($Svr)/Labtech/Agent.aspx"
                        Write-Debug "Testing Server Response and Version: $SvrVerCheck"
                        $SvrVer = $Script:LTServiceNetWebClient.DownloadString($SvrVerCheck)
                        
                        Write-Debug "Raw Response: $SvrVer"
                        if ($SvrVer -NotMatch '(?<=[|]{6})[0-9]{3}\.[0-9]{3}') {
                            Write-Verbose "Unable to test version response from $($Svr)."
                            Continue
                        }
                        $SVer = $SvrVer|select-string -pattern '(?<=[|]{6})[0-9]{3}\.[0-9]{3}'|ForEach-Object {$_.matches}|Select-Object -Expand value
                        if ([System.Version]$SVer -ge [System.Version]'110.374') {
                            #New Style Download Link starting with LT11 Patch 13 - Direct Location Targeting is no longer available
                            $installer = "$($Svr)/Labtech/Deployment.aspx?Probe=1&installType=msi&MSILocations=1"
                        } else {
                            #Original Generic Installer URL - Yes, these both reference Location 1 and are thus the same. Will it change in Patch 14? This section is now ready.
                            $installer = "$($Svr)/Labtech/Deployment.aspx?Probe=1&installType=msi&MSILocations=1"
                        }
                        $installerTest = [System.Net.WebRequest]::Create($installer)
                        If (($Script:LTProxy.Enabled) -eq $True) {
                            Write-Debug "Proxy Configuration Needed. Applying Proxy Settings to request."
                            $installerTest.Proxy=$Script:LTWebProxy
                        }#End If                        
                        $installerTest.KeepAlive=$False
                        $installerTest.ProtocolVersion = '1.0'
                        $installerResult = $installerTest.GetResponse()
                        $installerTest.Abort()
                        if ($installerResult.StatusCode -ne 200) {
                            Write-Warning "Unable to download Agent_Install.msi from server $($Svr)."
                            Continue
                        }
                        else{
                            Write-Debug "Downloading Agent_Install.msi from $installer"
                            If ($PSCmdlet.ShouldProcess("$installer", "DownloadFile")) {
                                $Script:LTServiceNetWebClient.DownloadFile($installer,"$env:windir\temp\LabTech\Installer\Agent_Install.msi")
                            }
                        }

                        #Using $SVer results gathered above.
                        if ([System.Version]$SVer -ge [System.Version]'110.374') {
                            #New Style Download Link starting with LT11 Patch 13 - The Agent Uninstaller URI has changed.
                            $uninstaller = "$($Svr)/Labtech/Deployment.aspx?ID=-2"
                        } else {
                            #Original Uninstaller URL
                            $uninstaller = "$($Svr)/Labtech/Deployment.aspx?probe=1&ID=-2"
                        }
                        $uninstallerTest = [System.Net.WebRequest]::Create($uninstaller)
                        If (($Script:LTProxy.Enabled) -eq $True) {
                            Write-Debug "Proxy Configuration Needed. Applying Proxy Settings to request."
                            $uninstallerTest.Proxy=$Script:LTWebProxy
                        }#End If                        
                        $uninstallerTest.KeepAlive=$False
                        $uninstallerTest.ProtocolVersion = '1.0'
                        $uninstallerResult = $uninstallerTest.GetResponse()
                        $uninstallerTest.Abort()
                        if ($uninstallerResult.StatusCode -ne 200) {
                            Write-Warning "Unable to download Agent_Uninstall from server."
                            Continue
                        }
                        else{
                            Write-Debug "Downloading Agent_Uninstall.exe from $uninstaller"
                            #Download Agent_Uninstall.exe
                            If ($PSCmdlet.ShouldProcess("$uninstaller", "DownloadFile")) {
                                $Script:LTServiceNetWebClient.DownloadFile($uninstaller,"$($env:windir)\temp\Agent_Uninstall.exe")
                            }
                        }
                        If ((Test-Path "$env:windir\temp\LabTech\Installer\Agent_Install.msi") -and (Test-Path "$($env:windir)\temp\Agent_Uninstall.exe")) {
                            $GoodServer = $Svr
                            Write-Verbose "Successfully downloaded files from $($Svr)."
                        } else {
                            Write-Warning "Error encountered downloading from $($Svr). Uninstall file(s) could be received."
                            Continue
                        }
                    }
                    Catch {
                        Write-Warning "Error encountered downloading from $($Svr)."
                        Continue
                    }
                } else {
                    Write-Verbose "Server address $($Svr) is not formatted correctly. Example: https://lt.domain.com"
                }
            } else {
                Write-Debug "Server $($GoodServer) has been selected."
                Write-Verbose "Server has already been selected - Skipping $($Svr)."
            }
        }#End Foreach
    }#End Process

    End{
        if ($GoodServer) {
            Try{
                Write-Output "Starting Uninstall."

				try { Stop-LTService -ErrorAction SilentlyContinue } catch {}
				
                #Kill all running processes from %ltsvcdir%   
                if (Test-Path $BasePath){
                    $Executables = (Get-ChildItem $BasePath -Filter *.exe -Recurse -ErrorAction SilentlyContinue|Select-Object -Expand Name|ForEach-Object {$_.Trim('.exe')})
                    if ($Executables) {
                        Write-Verbose "Terminating LabTech Processes if found running: $($Executables)"
                        Get-Process | Where-Object {$Executables -contains $_.ProcessName } | ForEach-Object {
                            Write-Debug "Terminating Process $($_.ProcessName)"
                            $($_) | Stop-Process -Force -ErrorAction SilentlyContinue
                        }
                    }

                    If ($PSCmdlet.ShouldProcess("$($BasePath)\wodVPN.dll", "Unregister DLL")) {
                        #Unregister DLL
                        regsvr32.exe /u $BasePath\wodVPN.dll /s 2>''
                    }
                }#End If

                If ($PSCmdlet.ShouldProcess("msiexec.exe $($xarg)", "Execute Uninstall")) {
                    If ((Test-Path "$($env:windir)\temp\LabTech\Installer\Agent_Install.msi")) {
                        #Run MSI uninstaller for current installer
                        Write-Verbose "Launching Uninstall: msiexec.exe $($xarg)"
                        Start-Process -Wait -FilePath msiexec.exe -ArgumentList $xarg
                        Start-Sleep -Seconds 5
                    } else {
                        Write-Verbose "WARNING: $($env:windir)\temp\LabTech\Installer\Agent_Install.msi was not found."
                    }
                }

                If ($PSCmdlet.ShouldProcess("$($env:windir)\temp\Agent_Uninstall.exe", "Execute Uninstall")) {
                    If ((Test-Path "$($env:windir)\temp\Agent_Uninstall.exe")) {
                        #Run Agent_Uninstall.exe
                        Write-Verbose "Launching $($env:windir)\temp\Agent_Uninstall.exe"
                        Start-Process -Wait -FilePath "$($env:windir)\temp\Agent_Uninstall.exe"
                        Start-Sleep -Seconds 5
                    } else {
                        Write-Verbose "WARNING: $($env:windir)\temp\Agent_Uninstall.exe was not found."
                    }
                }

                Write-Verbose "Removing Services if found."
                #Remove Services
                @('LTService','LTSvcMon') | ForEach-Object {
                    if (Get-Service $_ -EA 0) {
						Write-Debug "Removing Service: $($_)"
						Start-Process -Wait -FilePath sc.exe -ArgumentList "delete $_"
					}
                }

                Write-Verbose "Cleaning Files remaining if found."
                #Remove %ltsvcdir% - Depth First Removal, First by purging files, then Removing Folders, to get as much removed as possible if complete removal fails
                @($BasePath, "$($env:windir)\temp\_ltupdate", "$($env:windir)\temp\_ltudpate") | foreach-object {
                    If ((Test-Path "$($_)" -EA 0)) {
						Write-Debug "Removing Item: $($_)"
						Get-ChildItem -Path $_ -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { ($_.psiscontainer) } | foreach-object { Get-ChildItem -Path "$($_.FullName)" -EA 0 | Where-Object { -not ($_.psiscontainer) } | Remove-Item -Force -ErrorAction SilentlyContinue }
						Get-ChildItem -Path $_ -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { ($_.psiscontainer) } | Sort-Object { $_.fullname.length } -Descending | Remove-Item -Force -ErrorAction SilentlyContinue -Recurse
						Remove-Item -Recurse -Force -Path $_ -ErrorAction SilentlyContinue
					}
                }

                Write-Verbose "Cleaning Registry Keys if found."
                #Remove all registry keys - Depth First Value Removal, then Key Removal, to get as much removed as possible if complete removal fails
                foreach ($reg in $regs) {
                    If ((Test-Path "$($reg)" -EA 0)) {
						Write-Debug "Removing Item: $($reg)"
						Get-ChildItem -Path $reg -Recurse -Force -ErrorAction SilentlyContinue | Sort-Object { $_.name.length } -Descending | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
						Remove-Item -Recurse -Force -Path $reg -ErrorAction SilentlyContinue
					}
                }
				
                #Post Uninstall Check
                If ($PSCmdlet.ShouldProcess("$($env:windir)\ltsvc", "Check Folder")) {
                    if((Test-Path $env:windir\ltsvc) -or (Test-Path $env:windir\temp\_ltudpate) -or (Test-Path registry::HKLM\Software\LabTech\Service) -or (Test-Path registry::HKLM\Software\WOW6432Node\Labtech\Service)){
                        Start-Sleep -Seconds 10
                    }
                }
                If ($PSCmdlet.ShouldProcess("HKLM\Software\LabTech\Service", "Check Registry Key")) {
                    if((Test-Path $env:windir\ltsvc) -or (Test-Path $env:windir\temp\_ltudpate) -or (Test-Path registry::HKLM\Software\LabTech\Service) -or (Test-Path registry::HKLM\Software\WOW6432Node\Labtech\Service)){
                        Write-Error "Remnants of previous install still detected after uninstall attempt. Please reboot and try again."
                    }
                }

            }#End Try
    
            Catch{
                Write-Error "ERROR: There was an error during the uninstall process. $($Error[0])" -ErrorAction Stop
            }#End Catch
            If ($?){
                Write-Output "LabTech has been successfully uninstalled."
            }
            else {
                $($Error[0])
            }
        } else {
            Write-Error "ERROR: No valid server was reached to use for the uninstall." -ErrorAction Stop
        }#End If
    }#End End
}#End Function Uninstall-LTService
#endregion Uninstall-LTService

Function Install-LTService{
#region [Install-LTService]-----------------------------------------------------
<#
.SYNOPSIS
    This function will install the LabTech agent on the machine.

.DESCRIPTION
    This function will install the LabTech agent on the machine with the specified server/password/location.

.PARAMETER Server
    This is the URL to your LabTech server. 
    example: https://lt.domain.com
    This is used to download the installation files.
    (Get-LTServiceInfo|Select-Object -Expand 'Server Address' -ErrorAction SilentlyContinue)

.PARAMETER Password
    This is the server password that agents use to authenticate with the LabTech server.
    (Get-LTServiceInfo).ServerPassword

.PARAMETER LocationID
    This is the LocationID of the location that the agent will be put into.
    (Get-LTServiceInfo).LocationID

.PARAMETER TrayPort
    This is the port LTSvc.exe listens on for communication with LTTray processess.

.PARAMETER Rename
    This will call Rename-LTAddRemove after the install.

.PARAMETER Hide
    This will call Hide-LTAddRemove after the install.

.PARAMETER Force
    This will disable some of the error checking on the install process.

.EXAMPLE
    Install-LTService -Server https://lt.domain.com -Password sQWZzEDYKFFnTT0yP56vgA== -LocationID 42
    This will install the LabTech agent using the provided Server URL, Password, and LocationID.

.NOTES
    Version:        1.7
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
    Update Date: 6/10/2017
    Purpose/Change: Updates for pipeline input, support for multiple servers
    
    Update Date: 6/24/2017
    Purpose/Change: Update to detect Server Version and use updated URL format for LabTech 11 Patch 13.

    Update Date: 8/24/2017
    Purpose/Change: Update to use Clear-Variable. Additional Debugging.
    
    Update Date: 8/29/2017
    Purpose/Change: Additional Debugging.
    
    Update Date: 9/7/2017
    Purpose/Change: Support for ShouldProcess to enable -Confirm and -WhatIf.
    
    Update Date: 1/26/2018
    Purpose/Change: Added support for Proxy Server for Download and Installation steps.

    Update Date: 2/13/2018
    Purpose/Change: Added -TrayPort parameter.

.LINK
    http://labtechconsulting.com
#> 
    [CmdletBinding(SupportsShouldProcess=$True)]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory=$True)]
        [string[]]$Server,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias("Password")]
        [string]$ServerPassword,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [int]$LocationID,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [int]$TrayPort,
        [string]$Rename = $null,
        [switch]$Hide = $False,
        [switch]$Force = $False
    )

    Begin{
        Clear-Variable DotNET,OSVersion,PasswordArg,Result,logpath,logfile,curlog,installer,installerTest,installerResult,GoodServer,GoodTrayPort,TestTrayPort,Svr,SVer,SvrVer,SvrVerCheck,iarg,timeout,sw,tmpLTSI -EA 0 #Clearing Variables for use

        if (!($Force)) {
            if (Get-Service 'LTService','LTSvcMon' -ErrorAction SilentlyContinue) {
                Write-Error "LabTech is already installed." -ErrorAction Stop
            }

            If (-not ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()|Select-object -Expand Groups -EA 0) -match "S-1-5-32-544"))) {
                Write-Error "Needs to be ran as Administrator" -ErrorAction Stop
            }
        }

        $DotNET = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse -EA 0 | Get-ItemProperty -name Version,Release -EA 0 | Where-Object { $_.PSChildName -match '^(?!S)\p{L}'} | Select-Object -ExpandProperty Version -EA 0
        if (-not ($DotNet -like '3.5.*'))
        {
            Write-Output ".NET 3.5 installation needed."
            #Install-WindowsFeature Net-Framework-Core
            $OSVersion = [System.Environment]::OSVersion.Version

            if ([version]$OSVersion -gt [version]'6.2'){
                try{
                    If ( $PSCmdlet.ShouldProcess("NetFx3", "Enable-WindowsOptionalFeature") ) {
                        $Install = Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -All
                        if ($Install.RestartNeeded) {
                            Write-Output ".NET 3.5 installed but a reboot is needed."
                        }
                    }
                }
                catch{
                    Write-Error "ERROR: .NET 3.5 install failed." -ErrorAction Continue
                    if (!($Force)) { Write-Error $Install -ErrorAction Stop }
                }
            }
            else{
                If ( $PSCmdlet.ShouldProcess("NetFx3", "Add Windows Feature") ) {
                    $Result = Dism.exe /online /get-featureinfo /featurename:NetFx3 2>''
                    If ($Result -contains "State : Enabled"){
                        # also check reboot status, unsure of possible outputs
                        # Restart Required : Possible 

                        Write-Warning ".Net Framework 3.5 has been installed and enabled." 
                    } 
                    Else { 
                        Write-Error "ERROR: .NET 3.5 install failed." -ErrorAction Continue
                        if (!($Force)) { Write-Error $Result -ErrorAction Stop }
                    }
                }
            }
            
            $DotNET = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse | Get-ItemProperty -name Version,Release -EA 0 | Where-Object{ $_.PSChildName -match '^(?!S)\p{L}'} | Select-Object -ExpandProperty Version
        }

        if (-not ($DotNet -like '3.5.*')){
            if (($Force)) {
                if ($DotNet -like '2.0.*'){
                    Write-Error "ERROR: .NET 3.5 is not detected and could not be installed." -ErrorAction Continue
                }
                Else {
                    Write-Error "ERROR: .NET 2.0 is not detected and could not be installed." -ErrorAction Stop
                }
            }
            else {
                Write-Error "ERROR: .NET 3.5 is not detected and could not be installed." -ErrorAction Stop            
            }
        }

        $logpath = [System.Environment]::ExpandEnvironmentVariables("%windir%\temp\LabTech")
        $logfile = "LTAgentInstall"
        $curlog = "$($logpath)\$($logfile).log"
        if (-not (Test-Path -PathType Container -Path "$logpath\Installer" )){
            New-Item "$logpath\Installer" -type directory -ErrorAction SilentlyContinue | Out-Null
        }#End if
        if ((Test-Path -PathType Leaf -Path $($curlog))){
            $curlog = Get-Item -Path $curlog -EA 0
            Rename-Item -Path $($curlog|Select-Object -Expand FullName -EA 0) -NewName "$($logfile)-$(Get-Date $($curlog|Select-Object -Expand LastWriteTime -EA 0) -Format 'yyyyMMddHHmmss').log" -Force
            Remove-Item -Path $($curlog|Select-Object -Expand FullName -EA 0) -Force -EA 0
        }#End if
    }#End Begin
  
    Process{
        if (-not ($LocationID)){
            $LocationID = "1"
        }
        if (-not ($TrayPort) -or -not ($TrayPort -ge 1 -and $TrayPort -le 65535)){
            $TrayPort = "42000"
        }
        Foreach ($Svr in $Server) {
            if (-not ($GoodServer)) {
                if ($Svr -match '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*){1,})$') {
                    if ($Svr -notmatch 'https?://.+') {$Svr = "http://$($Svr)"}
                    Try {
                        $SvrVerCheck = "$($Svr)/Labtech/Agent.aspx"
                        Write-Debug "Testing Server Response and Version: $SvrVerCheck"
                        $SvrVer = $Script:LTServiceNetWebClient.DownloadString($SvrVerCheck)
                        Write-Debug "Raw Response: $SvrVer"
                        if ($SvrVer -NotMatch '(?<=[|]{6})[0-9]{3}\.[0-9]{3}') {
                            Write-Verbose "Unable to test version response from $($Svr)."
                            Continue
                        }
                        $SVer = $SvrVer|select-string -pattern '(?<=[|]{6})[0-9]{3}\.[0-9]{3}'|ForEach-Object {$_.matches}|Select-Object -Expand value
                        if ([System.Version]$SVer -ge [System.Version]'110.374') {
                            #New Style Download Link starting with LT11 Patch 13 - Direct Location Targeting is no longer available
                            $installer = "$($Svr)/Labtech/Deployment.aspx?Probe=1&installType=msi&MSILocations=1"
                        } else {
                            #Original URL
                            $installer = "$($Svr)/Labtech/Deployment.aspx?Probe=1&installType=msi&MSILocations=$LocationID"
                        }
                        $installerTest = [System.Net.WebRequest]::Create($installer)
                        If (($Script:LTProxy.Enabled) -eq $True) {
                            Write-Debug "Proxy Configuration Needed. Applying Proxy Settings to request."
                            $installerTest.Proxy=$Script:LTWebProxy
                        }#End If                        
                        $installerTest.KeepAlive=$False
                        $installerTest.ProtocolVersion = '1.0'
                        $installerResult = $installerTest.GetResponse()
                        $installerTest.Abort()
                        if ($installerResult.StatusCode -ne 200) {
                            Write-Warning "Unable to download Agent_Install from server $($Svr)."
                            Continue
                        } else {
                            Write-Debug "Downloading Agent_Install.msi from $installer"
                            If ( $PSCmdlet.ShouldProcess($installer, "DownloadFile") ) {
                                $Script:LTServiceNetWebClient.DownloadFile($installer,"$env:windir\temp\LabTech\Installer\Agent_Install.msi")
                                If (Test-Path "$env:windir\temp\LabTech\Installer\Agent_Install.msi") {
                                    $GoodServer = $Svr
                                    Write-Verbose "Agent_Install.msi downloaded successfully from server $($Svr)."
                                } else {
                                    Write-Warning "Error encountered downloading from $($Svr). No installation file was received."
                                    Continue
                                }
                            } else {$GoodServer = $Svr}
                        }
                    }
                    Catch {
                        Write-Warning "Error encountered downloading from $($Svr)."
                        Continue
                    }
                } else {
                    Write-Warning "Server address $($Svr) is not formatted correctly. Example: https://lt.domain.com"
                }
            } else {
                Write-Debug "Server $($GoodServer) has been selected."
                Write-Verbose "Server has already been selected - Skipping $($Svr)."
            }
        }#End Foreach
    }#End Process
  
    End{
        if (($ServerPassword)){
            $PasswordArg = "SERVERPASS=$ServerPassword"
        }
        if ($GoodServer) {
            If ( $PSCmdlet.ShouldProcess("Folder and Registry Paths", "Checking for Remnants from Previous Installations") ) {
                if((Test-Path "$($env:windir)\ltsvc" -EA 0) -or (Test-Path "$($env:windir)\temp\_ltudpate" -EA 0) -or (Test-Path registry::HKLM\Software\LabTech\Service -EA 0) -or (Test-Path registry::HKLM\Software\WOW6432Node\Labtech\Service -EA 0)){
                    Write-Warning "Previous install detected. Calling Uninstall-LTService"
                    Uninstall-LTService -Server $GoodServer 
                    Start-Sleep 10
                }
            }

            $GoodTrayPort=$Null;
            $TestTrayPort=$TrayPort;
            For ($i=0; $i -le 10; $i++) {
                If (-not ($GoodTrayPort)) {
                    If (-not (Test-LTPorts -TrayPort $TestTrayPort -Quiet)){
                        $TestTrayPort++;
                        If ($TestTrayPort -gt 42009) {$TestTrayPort=42000}
                    } Else {
                        $GoodTrayPort=$TestTrayPort
                    }#End If
                }#End If
            }#End For
            If ($GoodTrayPort -and $GoodTrayPort -ne $TrayPort) {
                Write-Verbose "TrayPort $($TrayPort) is in use. Changing TrayPort to $($GoodTrayPort)"
                $TrayPort=$GoodTrayPort
            }

            Write-Output "Starting Install."
            $iarg = "/i $env:windir\temp\LabTech\Installer\Agent_Install.msi SERVERADDRESS=$GoodServer $PasswordArg LOCATION=$LocationID SERVICEPORT=$TrayPort /qn /l $logpath\$logfile.log"

            Try{
                Write-Verbose "Launching Installation Process: msiexec.exe $(($iarg))"
                If ( $PSCmdlet.ShouldProcess("msiexec.exe $($iarg)", "Execute Install") ) {
                    Start-Process -Wait -FilePath msiexec.exe -ArgumentList $iarg
                }
                If (($Script:LTProxy.Enabled) -eq $True) {
                    If ( $PSCmdlet.ShouldProcess($Script:LTProxy.ProxyServerURL, "Configure Agent Proxy") ) {
                        Write-Verbose "Proxy Configuration Needed. Applying Proxy Settings to Agent Installation."
                        $svcRun = ('LTService') | Get-Service -EA 0 | Where-Object {$_.Status -eq 'Running'} | Measure-Object | Select-Object -Expand Count
                        if ($svcRun -ne 0) {
                            $timeout = new-timespan -Minutes 2
                            $sw = [diagnostics.stopwatch]::StartNew()
                            Write-Host -NoNewline "Waiting for Service to Start." 
                            Do {
                                Write-Host -NoNewline '.'
                                Start-Sleep 2
                                $svcRun = ('LTService') | Get-Service -EA 0 | Where-Object {$_.Status -eq 'Running'} | Measure-Object | Select-Object -Expand Count
                            } until ($sw.elapsed -gt $timeout -or $svcRun -eq 1)
                            Write-Host ""
                            $sw.Stop()
                        }
                        Set-LTProxy -ProxyServerURL $Script:LTProxy.ProxyServerURL -ProxyUsername $Script:LTProxy.ProxyUsername -ProxyPassword $Script:LTProxy.ProxyPassword
                    }
                } else {
                    Write-Verbose "No Proxy Configuration has been specified - Continuing."
                }#End If
                $timeout = new-timespan -Minutes 3
                $sw = [diagnostics.stopwatch]::StartNew()
                Write-Host -NoNewline "Waiting for agent to register." 
                If ( $PSCmdlet.ShouldProcess("LTService","Monitor Agent Registration") ) {
                    Do {
                        Write-Host -NoNewline '.'
                        Start-Sleep 2
                        $tmpLTSI = (Get-LTServiceInfo -EA 0 -Verbose:$False | Select-Object -Expand 'ID' -EA 0)
                    } until ($sw.elapsed -gt $timeout -or $tmpLTSI -gt 1)
                    $sw.Stop()
                    Write-Verbose "Completed wait for LabTech Installation after $(([int32]$sw.Elapsed.TotalSeconds).ToString()) seconds."
                }
                If ($Hide) {Hide-LTAddRemove}
            }#End Try

            Catch{
                Write-Error "ERROR: There was an error during the install process. $($Error[0])" -ErrorAction Stop
            }#End Catch

            If ( $PSCmdlet.ShouldProcess("LTService","Verify Install") ) {
                $tmpLTSI = Get-LTServiceInfo -EA 0 -Verbose:$False
                if (($tmpLTSI)) {
                    if (($tmpLTSI|Select-Object -Expand 'ID' -EA 0) -gt 1) {
                        Write-Host ""
                        Write-Output "LabTech has been installed successfully. Agent ID: $($tmpLTSI|Select-Object -Expand 'ID' -EA 0) LocationID: $($tmpLTSI|Select-Object -Expand 'LocationID' -EA 0)"
                        if (($Rename) -and $Rename -notmatch 'False'){
                            Rename-LTAddRemove -Name $Rename
                        }
                    }
                }
                else {
                    if (($Error)) {
                        Write-Error "ERROR: There was an error installing LabTech. Check the log, $($env:windir)\temp\LabTech\LTAgentInstall.log $($Error[0])" -ErrorAction Stop
                    } else {
                        Write-Error "ERROR: There was an error installing LabTech. Check the log, $($env:windir)\temp\LabTech\LTAgentInstall.log" -ErrorAction Stop
                    }
                }
            } else {
                if (($Rename) -and $Rename -notmatch 'False'){
                    Rename-LTAddRemove -Name $Rename
                }
            }
        } else {
            Write-Error "ERROR: No valid server was reached to use for the install." -ErrorAction Stop
        }
    }#End End
}#End Function Install-LTService
#endregion Install-LTService

Function Redo-LTService{
#region [Redo-LTService]---------------------------------------------------
<#
.SYNOPSIS
    This function will reinstall the LabTech agent from the machine.

.DESCRIPTION
    This script will attempt to pull all current settings from machine and issue an 'Uninstall-LTService', 'Install-LTService' with gathered information. 
    If the function is unable to find the settings it will ask for needed parameters. 

.PARAMETER Server
    This is the URL to your LabTech server. 
    Example: https://lt.domain.com
    This is used to download the installation and removal utilities.
    If no server is provided the uninstaller will use Get-LTServiceInfo to get the server address.
    If it is unable to find LT currently installed it will try Get-LTServiceInfoBackup

.PARAMETER Password
    This is the Server Password to your LabTech server. 
    example: sRWyzEF0KaFzHTnyP56vgA==
    You can find this from a configured agent with, '(Get-LTServiceInfo).ServerPassword'
    
.PARAMETER LocationID
    The LocationID of the location that you want the agent in
    example: 555

.PARAMETER Backup
    This will run a New-LTServiceBackup command before uninstalling.

.PARAMETER Hide
    Will remove from add-remove programs

.PARAMETER Rename
    This will call Rename-LTAddRemove to rename the install in Add/Remove Programs

.EXAMPLE
    Redo-LTService 
    This will ReInstall the LabTech agent using the server address in the registry.

.EXAMPLE
    Redo-LTService -Server https://lt.domain.com -Password sQWZzEDYKFFnTT0yP56vgA== -LocationID 42
    This will ReInstall the LabTech agent using the provided server URL to download the installation files.

.NOTES
    Version:        1.4
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
    Update Date: 6/8/2017
    Purpose/Change: Update to support user provided settings for -Server, -Password, -LocationID.
    
    Update Date: 6/10/2017
    Purpose/Change: Updates for pipeline input, support for multiple servers
    
    Update Date: 8/24/2017
    Purpose/Change: Update to use Clear-Variable.
    
.LINK
    http://labtechconsulting.com
#> 
    [CmdletBinding(SupportsShouldProcess=$True)]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $true, ValueFromPipeline=$True)]
        [string[]]$Server,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias("Password")]
        [string]$ServerPassword,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$LocationID,
        [switch]$Backup = $False,
        [switch]$Hide = $False,
        [string]$Rename = $null
    )
           
    Begin{
        Clear-Variable PasswordArg, RenameArg, Svr, ServerList, Settings -EA 0 #Clearing Variables for use
        # Gather install stats from registry or backed up settings
        $Settings = Get-LTServiceInfo -EA 0 -Verbose:$False
        if (-not ($Settings)){
            $Settings = Get-LTServiceInfoBackup -ErrorAction SilentlyContinue
        }
        $ServerList=@()
    }#End Begin
  
    Process{
        if (-not ($Server)){
            if ($Settings){
              $Server = $Settings|Select-object -Expand 'Server' -EA 0
            }
            if (-not ($Server)){
                $Server = Read-Host -Prompt 'Provide the URL to your LabTech server (https://lt.domain.com):'
            }
        }
        if (-not ($LocationID)){
            if ($Settings){
                $LocationID = $Settings|Select-object -Expand LocationID -EA 0
            }
            if (-not ($LocationID)){
                $LocationID = Read-Host -Prompt 'Provide the LocationID'
            }
        }
        if (-not ($LocationID)){
            $LocationID = "1"
        }
        $ServerList += $Server
    }#End Process
  
    End{
        if ($Backup){
            New-LTServiceBackup
        }

        $RenameArg=''
        if ($Rename){
            $RenameArg = "-Rename $Rename"
        }

        if (($ServerPassword)){
            $PasswordArg = "-Password '$ServerPassword'"
        }

        Write-Host "Reinstalling LabTech with the following information, -Server $($ServerList -join ',') $PasswordArg -LocationID $LocationID $RenameArg"
        Write-Verbose "Starting: Uninstall-LTService -Server $($ServerList -join ',')"
        Try{
            Uninstall-LTService -Server $serverlist -ErrorAction Stop
        }#End Try
    
        Catch{
            Write-Error "ERROR: There was an error during the reinstall process while uninstalling. $($Error[0])" -ErrorAction Stop
        }#End Catch

        Start-Sleep 10
        Write-Verbose "Starting: Install-LTService -Server $($ServerList -join ',') $PasswordArg -LocationID $LocationID -Hide:`$$($Hide) $RenameArg"
        Try{
            Install-LTService -Server $ServerList $ServerPassword -LocationID $LocationID -Force -Hide:$Hide $RenameArg 
        }#End Try
    
        Catch{
            Write-Error "ERROR: There was an error during the reinstall process while installing. $($Error[0])" -ErrorAction Stop
        }#End Catch

        If ($?){
            Return
        }
        else {
            $($Error[0])
        }
    }#End End
}#End Function Redo-LTService
#endregion Redo-LTService
Set-Alias -Name ReInstall-LTService -Value Redo-LTService

Function Get-LTError{
#region [Get-LTError]-----------------------------------------------------------
<#
.SYNOPSIS
    This will pull the %ltsvcdir%\LTErrors.txt file into an object.

.EXAMPLE
    Get-LTError | where {(Get-date $_.Time) -gt (get-date).AddHours(-24)}
    Get a list of all errors in the last 24hr

.EXAMPLE
    Get-LTError | Out-Gridview
    Open the log file in a sortable searchable window.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#> 

    [CmdletBinding()]
    Param()
    
    Begin{
        $BasePath = $(Get-LTServiceInfo -EA 0 -Verbose:$False|Select-object -Expand BasePath -EA 0)
        if (!$BasePath){$BasePath = "$env:windir\LTSVC"}
        if ($(Test-Path -Path $BasePath\LTErrors.txt) -eq $False) {
            Write-Error "ERROR: Unable to find log. $($Error[0])" -ErrorAction Stop
        }
    }#End Begin
  
    Process{
        Try{
            $errors = Get-Content "$BasePath\LTErrors.txt"
            $errors = $errors -join ' ' -split ':::'
            foreach($Line in $Errors){
                $items = $Line -split "`t" -replace ' - ',''
                if ($items[1]){
                    $object = New-Object -TypeName PSObject
                    $object | Add-Member -MemberType NoteProperty -Name ServiceVersion -Value $items[0]
                    $object | Add-Member -MemberType NoteProperty -Name Timestamp -Value $([datetime]$items[1])
                    $object | Add-Member -MemberType NoteProperty -Name Message -Value $items[2]
                    Write-Output $object
                }
            }
            
        }#End Try
    
        Catch{
            Write-Error "ERROR: There was an error reading the log. $($Error[0])" -ErrorAction Stop
        }#End Catch
    }#End Process
  
    End{
        if ($?){
        }
        Else {$Error[0]}
        
    }#End End
}#End Function Get-LTError
#endregion Get-LTError

Function Reset-LTService{
#region [Reset-LTService]-------------------------------------------------------
<#
.SYNOPSIS
    This function will remove local settings on the agent.

.DESCRIPTION
    This function can remove some of the agents local settings.
    ID, MAC, LocationID
    The function will stop the services, make the change, then start the services.
    Resetting all of these will force the agent to check in as a new agent.
    If you have MAC filtering enabled it should check back in with the same ID.
    This function is useful for duplicate agents.

.PARAMETER ID
    This will reset the AgentID of the computer

.PARAMETER Location
    This will reset the LocationID of the computer

.PARAMETER MAC
    This will reset the MAC of the computer

.EXAMPLE
    Reset-LTService
    This resets the ID, MAC and LocationID on the agent. 

.EXAMPLE
    Reset-LTService -ID
    This resets only the ID of the agent.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#> 

    [CmdletBinding()]
    Param(
        [switch]$ID,
        [switch]$Location,
        [switch]$MAC        
    )   
    
    Begin{
        if (!(Get-Service 'LTService','LTSvcMon' -ErrorAction SilentlyContinue)) {
            Write-Error "ERROR: LabTech Services NOT Found $($Error[0])" -ErrorAction Stop
        }
        $Reg = 'HKLM:\Software\LabTech\Service'
        if (!($ID -or $LocationID -or $MAC)){
            $ID=$true
            $Location=$true
            $MAC=$true
        }
        Write-Output "OLD ID: $(Get-LTServiceInfo -EA 0 -Verbose:$False|Select-object -Expand ID -EA 0) LocationID: $(Get-LTServiceInfo -EA 0 -Verbose:$False|Select-object -Expand LocationID -EA 0) MAC: $(Get-LTServiceInfo -EA 0 -Verbose:$False|Select-object -Expand MAC -EA 0)"
        
    }#End Begin
  
    Process{
        Try{
            Stop-LTService
            if ($ID) {
                Write-Output ".Removing ID"
                Remove-ItemProperty -Name ID -Path $Reg -ErrorAction SilentlyContinue            
            }
            if ($Location) {
                Write-Output ".Removing LocationID"
                Remove-ItemProperty -Name LocationID -Path $Reg -ErrorAction SilentlyContinue
            }
            if ($MAC) {
                Write-Output ".Removing MAC"
                Remove-ItemProperty -Name MAC -Path $Reg -ErrorAction SilentlyContinue
            }
            Start-LTService
            $timeout = new-timespan -Minutes 1
            $sw = [diagnostics.stopwatch]::StartNew()
            While (!(Get-LTServiceInfo -EA 0 -Verbose:$False|Select-object -Expand ID -EA 0) -or !(Get-LTServiceInfo -EA 0 -Verbose:$False|Select-object -Expand LocationID -EA 0) -or !(Get-LTServiceInfo|Select-object -Expand MAC -EA 0) -and $($sw.elapsed) -lt $timeout){
                Write-Host -NoNewline '.'
                Start-Sleep 2
            }

        }#End Try
    
        Catch{
            Write-Error "ERROR: There was an error during the reset process. $($Error[0])" -ErrorAction Stop
        }#End Catch
    }#End Process
  
    End{
        if ($?){
            Write-Output ""
            Write-Output "NEW ID: $(Get-LTServiceInfo -EA 0 -Verbose:$False|Select-object -Expand ID -EA 0) LocationID: $(Get-LTServiceInfo -EA 0 -Verbose:$False|Select-object -Expand LocationID -EA 0) MAC: $(Get-LTServiceInfo -EA 0 -Verbose:$False|Select-object -Expand MAC -EA 0)"
        }
        Else {$Error[0]}
    }#End End
}#End Function Reset-LTService
#endregion Reset-LTService

Function Hide-LTAddRemove{
#region [Hide-LTAddRemove]------------------------------------------------------
<#
.SYNOPSIS
    This function hides the LabTech install from the Add/Remove Programs list.

.DESCRIPTION
    This function will rename the DisplayName registry key to hide it from the Add/Remove Programs list.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#>
    [CmdletBinding(SupportsShouldProcess=$True)]
    Param()

    Begin{
        $RegRoots = 'HKLM:\SOFTWARE\Classes\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F','HKLM:\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC'
        foreach($RegRoot in $RegRoots){
            if (Get-ItemProperty $RegRoot -Name ProductName -ErrorAction SilentlyContinue) {
                Write-Output "LabTech found in add/remove programs."
            }
            else {
                if (Get-ItemProperty $RegRoot -Name HiddenProductName -ErrorAction SilentlyContinue) {
                    Write-Error "LabTech already hidden from add/remove programs." -ErrorAction Stop
                }    
            }
        }
        
    }#End Begin
  
    Process{
        Try{
            Rename-ItemProperty $RegRoot -Name ProductName -NewName HiddenProductName
        }#End Try
    
        Catch{
            Write-Error "There was an error renaming the registry key. $($Error[0])" -ErrorAction Stop
        }#End Catch
    }#End Process
  
    End{
        if ($?){
            Write-Output "LabTech is now hidden from Add/Remove Programs."
        }
        else {$Error[0]}
    }#End End
}#End Function Hide-LTAddRemove
#endregion Hide-LTAddRemove

Function Show-LTAddRemove{
#region [Show-LTAddRemove]------------------------------------------------------
<#
.SYNOPSIS
    This function shows the LabTech install in the add/remove programs list.

.DESCRIPTION
    This function will rename the HiddenDisplayName registry key to show it in the add/remove programs list.
    If there is not HiddenDisplayName key the function will import a new entry.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#>
    [CmdletBinding(SupportsShouldProcess=$True)]
    Param()

    Begin{
        $RegRoots = 'HKLM:\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC'
    }#End Begin
  
    Process{
        Try{
            foreach($RegRoot in $RegRoots){

                if (Get-ItemProperty $RegRoot -Name HiddenProductName -ErrorAction SilentlyContinue){
                    Rename-ItemProperty $RegRoot -Name HiddenProductName -NewName ProductName
                }
                else{
                    $RegImport = @'
[HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC]
"PackageCode"="8059C8AD908AB434A9F2225AF86355C2"
"Language"=dword:00000409
"Version"=dword:0b00016d
"Assignment"=dword:00000001
"AdvertiseFlags"=dword:00000184
"ProductIcon"="C:\\WINDOWS\\Installer\\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}\\LabTeCh.ico"
"InstanceType"=dword:00000000
"AuthorizedLUAApp"=dword:00000000
"DeploymentFlags"=dword:00000003
"Clients"=hex(7):3a,00,00,00,00,00
"ProductName"="LabTech® Software Remote Agent"
'@
                    $RegImport | Out-File "$env:TEMP\LT.reg" -Force
                    Start-Process -Wait -FilePath reg -ArgumentList "import $($env:TEMP)\LT.reg"
                    Remove-Item "$env:TEMP\LT.reg" -Force
                    New-ItemProperty -Path "$RegRoot\SourceList" -Name LastUsedSource -Value "u;1;$((Get-LTServiceInfo -EA 0 -Verbose:$False|Select-object -Expand 'Server Address' -EA 0).Split(';'))/Labtech/" -PropertyType ExpandString -Force | Out-Null
                    New-ItemProperty -Path "$RegRoot\SourceList\URL" -Name 1 -Value "$((Get-LTServiceInfo -EA 0 -Verbose:$False|Select-object -Expand 'Server Address' -EA 0).Split(';'))/Labtech/" -PropertyType ExpandString -Force | Out-Null
                }
            }
        }#End Try
    
        Catch{
            Write-Error "There was an error renaming the registry key. $($Error[0])" -ErrorAction Stop
        }#End Catch
    }#End Process
  
    End{
        if ($?) {
            Write-Output "LabTech is now shown in Add/Remove Programs."
        }
        Else{$Error[0]}
    }#End End
}#End Function Show-LTAddRemove
#endregion Show-LTAddRemove

Function Test-LTPorts{
#region [Test-LTPorts]----------------------------------------------------------
<#
.SYNOPSIS
    This function will attempt to connect to all required TCP ports.

.DESCRIPTION
    The function will confirm the LTTray port is available locally.
    It will then test required TCP ports to the Server.

.PARAMETER Server
    This is the URL to your LabTech server. 
    Example: https://lt.domain.com
    If no server is provided the function will use Get-LTServiceInfo to 
    get the server address. If it is unable to find LT currently installed 
    it will try calling Get-LTServiceInfoBackup.

.PARAMETER TrayPort
    This is the port LTSvc.exe listens on for communication with LTTray.
    It will be checked to verify it is available. If not provided the 
    default port will be used (42000).

.PARAMETER Quiet
    This will return a boolean for connectivity status to the Server

.NOTES
    Version:        1.6
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date:    5/11/2017 
    Purpose/Change: Quiet feature

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2

    Update Date: 6/10/2017
    Purpose/Change: Updates for pipeline input, support for multiple servers

    Update Date: 8/24/2017
    Purpose/Change: Update to use Clear-Variable.

    Update Date: 8/29/2017
    Purpose/Change: Added Server Address Format Check

    Update Date: 2/13/2018
    Purpose/Change: Added -TrayPort parameter.

.LINK
    http://labtechconsulting.com
#>
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $true, ValueFromPipeline=$True)]
        [string[]]$Server,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [int]$TrayPort,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$Quiet
    )

    Begin{
        Function Private:TestPort{
        Param(
            [parameter(Position=0)]
            [string]
            $ComputerName,

            [parameter(Mandatory=$False)]
            [System.Net.IPAddress]
            $IPAddress,

            [parameter(Mandatory=$True , Position=1)]
            [int]
            $Port
            )

        $RemoteServer = If ([string]::IsNullOrEmpty($ComputerName)) {$IPAddress} Else {$ComputerName};
        If ([string]::IsNullOrEmpty($RemoteServer)) {Write-Error "No ComputerName or IPAddress was provided to test."; return}

        $test = New-Object System.Net.Sockets.TcpClient;
        Try
        {
            Write-Output "Connecting to $($RemoteServer):$Port (TCP)..";
            $test.Connect($RemoteServer, $Port);
            Write-Output "Connection successful";
        }
        Catch
        {
            Write-Output "ERROR: Connection failed";
            $Global:PortTestError = 1
        }
        Finally
        {
            $test.Close();
        }

        }#End Function TestPort

        Clear-Variable CleanSvr,svr,proc,processes,port,netstat,line -EA 0 #Clearing Variables for use

    }#End Begin
  
    Process{
        If (-not ($Server) -and (-not ($TrayPort) -or -not ($Quiet))){
            Write-Verbose 'No Server Input - Checking for names.'
            $Server = Get-LTServiceInfo -EA 0 -Verbose:$False|Select-Object -Expand 'Server' -EA 0
            If (-not ($Server)){
                Write-Verbose 'No Server found in installed Service Info. Checking for Service Backup.'
                $Server = Get-LTServiceInfoBackup -EA 0 -Verbose:$False|Select-Object -Expand 'Server' -EA 0
            }#End If
        }#End If

        If (-not ($Quiet) -or (($TrayPort) -ge 1 -and ($TrayPort) -le 65530)){
            If (-not ($TrayPort) -or -not (($TrayPort) -ge 1 -and ($TrayPort) -le 65530)){
                #Learn LTTrayPort if available.
                $TrayPort = (Get-LTServiceInfo -EA 0 -Verbose:$False|Select-Object -Expand TrayPort -EA 0)
            }
            If (-not ($TrayPort) -or $TrayPort -notmatch '^\d+$') {$TrayPort=42000}

            [array]$processes = @()
            #Get all processes that are using LTTrayPort (Default 42000)
            $netstat = netstat.exe -a -o -n | Select-String -Pattern " .*[0-9\.]+:$($TrayPort).*[0-9\.]+:[0-9]+ .*?([0-9]+)" -EA 0
            Foreach ($line In $netstat){
                $processes += ($line -split '  {3,}')[-1]
            }
            $processes = $processes | Where-Object {$_ -gt 0 -and $_ -match '^\d+$'}| Sort-Object | Get-Unique
            If (($processes)) {
                If (-not ($Quiet)){
                    Foreach ($proc In $processes) {
                        If ((Get-Process -ID $proc -EA 0|Select-object -Expand ProcessName -EA 0) -eq 'LTSvc') {
                            Write-Output "TrayPort Port $TrayPort is being used by LTSvc."
                        } Else {
                            Write-Output "Error: TrayPort Port $TrayPort is being used by $(Get-Process -ID $proc|Select-object -Expand ProcessName -EA 0)."
                        }#End If
                    }#End Foreach
                } Else {return $False}#End If
            } ElseIf (($Quiet) -eq $True){
                return $True
            } Else {
                Write-Output "TrayPort Port $TrayPort is available."
            }#End If
        }#End If

        foreach ($svr in $Server) {
            if ($Quiet){
                Test-Connection $Svr -Quiet
                return
            }

            if ($Svr -match '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*){1,})$') {
                Try{
                    $CleanSvr = ($Svr -replace 'https?://',''|ForEach-Object {$_.Trim()})
                    Write-Output "Testing connectivity to required TCP ports:"
                    TestPort -ComputerName $CleanSvr -Port 70
                    TestPort -ComputerName $CleanSvr -Port 80
                    TestPort -ComputerName $CleanSvr -Port 443
                    TestPort -ComputerName mediator.labtechsoftware.com -Port 8002

                }#End Try

                Catch{
                    Write-Error "ERROR: There was an error testing the ports. $($Error[0])" -ErrorAction Stop
                }#End Catch
            } else {
                Write-Warning "Server address $($Svr) is not a valid address or is not formatted correctly. Example: https://lt.domain.com"
            }#End If
        }#End Foreach
    }#End Process

    End{
        If ($?){
            if (-not ($Quiet)){
                Write-Output "Test-LTPorts Finished"
            }
        }
        else{$Error[0]}
    }#End End

}#End Function Test-LTPorts
#endregion Test-LTPorts

Function Get-LTLogging{
#region [Get-LTLogging]---------------------------------------------------- ----
<#
.SYNOPSIS
    This function will pull the logging level of the LabTech service.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#> 
    [CmdletBinding()]
    Param ()
      
  Begin{
    Write-Verbose "Checking for registry keys."
    if ((Test-Path 'HKLM:\SOFTWARE\LabTech\Service\settings') -eq $False){
        Write-Error "ERROR: Unable to find logging settings for LTSvc. Make sure the agent is installed." -ErrorAction Stop
    }
  }#End Begin
  
  Process{
    Try{
        $Value = (Get-LTServiceSettings|Select-object -Expand Debuging -EA 0)
    }#End Try
    
    Catch{
      Write-Error "ERROR: There was a problem reading the registry key. $($Error[0])" -ErrorAction Stop
    }#End Catch
  }#End Process
  
  End{
    if ($?){
        if ($value -eq 1){
            Write-Output "Current logging level: Normal"
        }
        elseif ($value -eq 1000){
            Write-Output "Current logging level: Verbose"
        }
        else{
            Write-Error "ERROR: Unknown Logging level $(Get-LTServiceInfo -EA 0 -Verbose:$False|Select-object -Expand Debuging -EA 0)" -ErrorAction Stop
        }
    }    
  }#End End
}#End Function Get-LTLogging
#endregion Get-LTLogging

Function Set-LTLogging{
#region [Set-LTLogging]---------------------------------------------------- ----
<#
.SYNOPSIS
        This function will set the logging level of the LabTech service.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#> 
   Param (
        [switch]$Normal,
        [switch]$Verbose
    )

      
  Begin{
    if ($Normal -ne $true -and $Verbose -ne $true ){
        Write-Error "Please provide a logging level. -Normal or -Verbose" -ErrorAction Stop
    }

  }#End Begin
  
  Process{
    Try{
        Stop-LTService
        if ($Normal){
            Set-ItemProperty HKLM:\SOFTWARE\LabTech\Service\Settings -Name 'Debuging' -Value 1
        }
        if ($Verbose){
            Set-ItemProperty HKLM:\SOFTWARE\LabTech\Service\Settings -Name 'Debuging' -Value 1000
        }
        Start-LTService
    }#End Try
    
    Catch{
      Write-Error "ERROR: There was a problem writing the registry key. $($Error[0])" -ErrorAction Stop
    }#End Catch
  }#End Process
  
  End{
    if ($?){
        Get-LTLogging          
    }    
  }#End End
}#End Function Set-LTLogging
#endregion Set-LTLogging

Function Get-LTProbeErrors{
#region [Get-LTProbeErrors]-----------------------------------------------------
<#
.SYNOPSIS
    This will pull the %ltsvcdir%\LTProbeErrors.txt file into an object.

.EXAMPLE
    Get-LTProbeErrors | where {(Get-date $_.Time) -gt (get-date).AddHours(-24)}
    Get a list of all errors in the last 24hr

.EXAMPLE
    Get-LTProbeErrors | Out-Gridview
    Open the log file in a sortable searchable window.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  3/14/2016
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#> 

    [CmdletBinding()]
    Param()
    
    Begin{
        $BasePath = $(Get-LTServiceInfo -EA 0 -Verbose:$False|Select-object -Expand BasePath -EA 0)
        if (!$BasePath){$BasePath = "$env:windir\LTSVC"}
        if ($(Test-Path -Path $BasePath\LTProbeErrors.txt) -eq $False) {
            Write-Error "ERROR: Unable to find log. $($Error[0])" -ErrorAction Stop
        }
    }#End Begin
    process{
        $errors = Get-Content $BasePath\LTProbeErrors.txt
        $errors = $errors -join ' ' -split ':::'
        foreach($Line in $Errors){
            $items = $Line -split "`t" -replace ' - ',''
            $object = New-Object -TypeName PSObject
            $object | Add-Member -MemberType NoteProperty -Name ServiceVersion -Value $items[0]
            $object | Add-Member -MemberType NoteProperty -Name Timestamp -Value $([datetime]$items[1])
            $object | Add-Member -MemberType NoteProperty -Name Message -Value $items[2]
            Write-Output $object
        }
    }
    End{
        if ($?){
        }
        Else {$Error[0]}
        
    }#End End
}#End Function Get-LTProbeErrors
#endregion Get-LTProbeErrors

Function New-LTServiceBackup{
#region [New-LTServiceBackup]---------------------------------------------------
<#
.SYNOPSIS
    This function will backup all the reg keys to 'HKLM\SOFTWARE\LabTechBackup'
    This will also backup those files to "$((Get-LTServiceInfo).BasePath)Backup"

.NOTES
    Version:        1.3
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  5/11/2017
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
    Update Date: 6/7/2017
    Purpose/Change: Updated error handling.
    
    Update Date: 8/24/2017
    Purpose/Change: Update to use Clear-Variable.
    
.LINK
    http://labtechconsulting.com
#> 
    [CmdletBinding()]
    Param ()
      
  Begin{
    Clear-Variable LTPath,BackupPath,Keys,Path,Result,Reg,RegPath -EA 0 #Clearing Variables for use
    $LTPath = "$(Get-LTServiceInfo -EA 0 -Verbose:$False|Select-Object -Expand BasePath -EA 0)"
    if (-not ($LTPath)) {
      Write-Error "ERROR: Unable to find LTSvc folder path." -ErrorAction Stop
    }
    $BackupPath = "$($LTPath)Backup"
    $Keys = "HKLM\SOFTWARE\LabTech"
    $RegPath = "$BackupPath\LTBackup.reg"
    
    Write-Verbose "Checking for registry keys."
    if ((Test-Path ($Keys -replace '^(H[^\\]*)','$1:')) -eq $False){
        Write-Error "ERROR: Unable to find registry information on LTSvc. Make sure the agent is installed." -ErrorAction Stop
        Return
    }
    if ($(Test-Path -Path $LTPath -PathType Container) -eq $False) {
      Write-Error "ERROR: Unable to find LTSvc folder path $LTPath" -ErrorAction Stop
    }
    New-Item $BackupPath -type directory -ErrorAction SilentlyContinue | Out-Null
    if ($(Test-Path -Path $BackupPath -PathType Container) -eq $False) {
      Write-Error "ERROR: Unable to create backup folder path $BackupPath" -ErrorAction Stop
    }
  }#End Begin
  
  Process{
    Try{
    Copy-Item $LTPath $BackupPath -Recurse -Force
    }#End Try
    
    Catch{
    Write-Error "ERROR: There was a problem backing up the LTSvc Folder. $($Error[0])"
    }#End Catch

    Try{
    $Result = reg.exe export "$Keys" "$RegPath" /y 2>''
    $Reg = Get-Content $RegPath
    $Reg = $Reg -replace [Regex]::Escape('[HKEY_LOCAL_MACHINE\SOFTWARE\LabTech'),'[HKEY_LOCAL_MACHINE\SOFTWARE\LabTechBackup'
    $Reg | Out-File $RegPath
    $Result = reg.exe import "$RegPath" 2>''
    $True | Out-Null #Protection to prevent exit status error
    }#End Try
 
    Catch{
    Write-Error "ERROR: There was a problem backing up the LTSvc Registry keys. $($Error[0])"
    }#End Catch
  }#End Process
  
  End{
    If ($?){
    Write-Output "The LabTech Backup has been created."
    }
    Else {
        Write-Error "ERROR: There was a problem completing the LTSvc Backup. $($Error[0])"
    }#End If
  }#End End
}#End Function New-LTServiceBackup
#endregion New-LTServiceBackup

Function Get-LTServiceInfoBackup{
#region [Get-LTServiceInfoBackup]-----------------------------------------------
<#
.SYNOPSIS
    This function will pull all of the backed up registry data into an object.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  5/11/2017
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2
    
.LINK
    http://labtechconsulting.com
#> 
    [CmdletBinding()]
    Param ()
      
  Begin{
    Write-Verbose "Checking for registry keys."
    If ((Test-Path 'HKLM:\SOFTWARE\LabTechBackup\Service') -eq $False){
        Write-Error "ERROR: Unable to find backup information on LTSvc. Use New-LTServiceBackup to create a settings backup."
        Return
    }
    $exclude = "PSParentPath","PSChildName","PSDrive","PSProvider","PSPath"
  }#End Begin
  
  Process{
    Try{
        $key = Get-ItemProperty HKLM:\SOFTWARE\LabTechBackup\Service -ErrorAction Stop | Select-Object * -exclude $exclude
        if (($key) -ne $Null -and ($key|Get-Member|Where-Object {$_.Name -match 'BasePath'})) {
            $key.BasePath = [System.Environment]::ExpandEnvironmentVariables($key.BasePath)
        }
        if (($key) -ne $Null -and ($key|Get-Member|Where-Object {$_.Name -match 'Server Address'})) {
        $Servers = ($Key|Select-Object -Expand 'Server Address' -EA 0).Split('|')|ForEach-Object {$_.Trim()}
        Add-Member -InputObject $key -MemberType NoteProperty -Name 'Server' -Value $Servers -Force
    }
    }#End Try
    
    Catch{
      Write-Error "ERROR: There was a problem reading the registry keys. $($Error[0])"
    }#End Catch
  }#End Process
  
  End{
    If ($?){
        $key
    }    
  }#End End
}#End Function Get-LTServiceInfoBackup
#endregion Get-LTServiceInfoBackup

Function Rename-LTAddRemove{
#region [Rename-LTAddRemove]----------------------------------------------------
<#
.SYNOPSIS
    This function renames the LabTech install as shown in the Add/Remove Programs list.

.DESCRIPTION
    This function will change the value of the DisplayName registry key to effect Add/Remove Programs list.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  5/14/2017
    Purpose/Change: Initial script development

    Update Date: 6/1/2017
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2

.PARAMETER Name
    This is the Name for the LabTech Agent as displayed in the list of installed software.

.PARAMETER PublisherName
    This is the Name for the Publisher of the LabTech Agent as displayed in the list of installed software.

.LINK
    http://labtechconsulting.com
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
        $Name,

        [Parameter(Mandatory=$False)]
        [string]$PublisherName
    )

    Begin{
        $RegRoots = 'HKLM:\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC'
        $PublisherRegRoots = ('HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}')
    }#End Begin
  
    Process{
        Try{
            foreach($RegRoot in $RegRoots){
                if (Get-ItemProperty $RegRoot -Name ProductName -ErrorAction SilentlyContinue){
                    Write-Verbose "Setting $($RegRoot)\ProductName=$($Name)"
                    Set-ItemProperty $RegRoot -Name ProductName -Value $Name
                } elseif (Get-ItemProperty $RegRoot -Name HiddenProductName -ErrorAction SilentlyContinue){
                    Write-Verbose "Setting $($RegRoot)\HiddenProductName=$($Name)"
                    Set-ItemProperty $RegRoot -Name HiddenProductName -Value $Name
                }
            }#End Foreach
        }#End Try

        Catch{
            Write-Error "There was an error setting the registry key value. $($Error[0])" -ErrorAction Stop
        }#End Catch

        if (($PublisherName)){
            Try{
                foreach($RegRoot in $PublisherRegRoots){
                    if (Get-ItemProperty $RegRoot -Name Publisher -ErrorAction SilentlyContinue){
                        Write-Verbose "Setting $($RegRoot)\Publisher=$($PublisherName)"
                        Set-ItemProperty $RegRoot -Name Publisher -Value $PublisherName
                    }#End If
                }#End foreach
            }#End Try
    
            Catch{
                Write-Error "There was an error setting the registry key value. $($Error[0])" -ErrorAction Stop
            }#End Catch
        }#End If
    }#End Process
  
    End{
        if ($?){
            Write-Output "LabTech is now listed as $($Name) in Add/Remove Programs."
            if (($PublisherName)){
                Write-Output "The Publisher is now listed as $($PublisherName)."
            }#End If
        }
        else {$Error[0]}
    }#End End
}#End Function Rename-LTAddRemove
#endregion Rename-LTAddRemove

Function Invoke-LTServiceCommand {
#region [Invoke-LTServiceCommand]--------------------------------------------------
<#
.SYNOPSIS
    This function tells the agent to execute the desired command.

.DESCRIPTION
    This function will allow you to execute all known commands against an agent.

.NOTES
    Version:        1.1
    Author:         Chris Taylor
    Website:        labtechconsulting.com
    Creation Date:  2/2/2018
    Purpose/Change: Initial script development
    Thanks:         Gavin Stone, for finding the command list

    Update Date: 2/8/2018
    Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2

.LINK
    http://labtechconsulting.com
#>  
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$True, Position=1, ValueFromPipeline=$True)]
        [ValidateSet("Update Schedule",
                     "Send Inventory",
                     "Send Drives",
                     "Send Processes",
                     "Send Spyware List",
                     "Send Apps",
                     "Send Events",
                     "Send Printers",
                     "Send Status",
                     "Send Screen",
                     "Send Services",
                     "Analyze Network",
                     "Write Last Contact Date",
                     "Kill VNC",
                     "Kill Trays",
                     "Send Patch Reboot",
                     "Run App Care Update",
                     "Start App Care Daytime Patching")][string[]]$Command
    )

    begin {
        $Service = Get-Service 'LTService' -ErrorAction Stop
    }
    process {
        If ($Service.Status -ne 'Running') {Write-Warning "Service 'LTService' is not running. Cannot send service command"; return}
        foreach ($Cmd in $Command) {
            $CommandID=$Null
            Try{
                switch($Cmd){
                    'Update Schedule' {$CommandID = 128}
                    'Send Inventory' {$CommandID = 129}
                    'Send Drives' {$CommandID = 130}
                    'Send Processes' {$CommandID = 131}
                    'Send Spyware List'{$CommandID = 132}
                    'Send Apps' {$CommandID = 133}
                    'Send Events' {$CommandID = 134}
                    'Send Printers' {$CommandID = 135}
                    'Send Status' {$CommandID = 136}
                    'Send Screen' {$CommandID = 137}
                    'Send Services' {$CommandID = 138}
                    'Analyze Network' {$CommandID = 139}
                    'Write Last Contact Date' {$CommandID = 140}
                    'Kill VNC' {$CommandID = 141}
                    'Kill Trays' {$CommandID = 142}
                    'Send Patch Reboot' {$CommandID = 143}
                    'Run App Care Update' {$CommandID = 144}
                    'Start App Care Daytime Patching' {$CommandID = 145}
                    default {"Invalid entry"}
                }
                If ($PSCmdlet.ShouldProcess("LTService", "Send Service Command '$($Cmd)' ($($CommandID))")) {
                    If (($CommandID) -ne $Null) {
                        Write-Debug "Sending service command '$($Cmd)' ($($CommandID)) to 'LTService'"
                        $Null=sc.exe control LTService $CommandID 2>''
                        Write-Output "Sent Command '$($Cmd)' to 'LTService'"
                    }
                }
            } # End Try

            Catch{
              Write-Warning $_.Exception
            } # End Catch

        } # End foreach

    } # End Process

    end{}    

} # End Function Invoke-LTServiceCommand
#endregion Invoke-LTServiceCommand

Function Get-LTServiceKeys{
#region [Get-LTServiceKeys]--------------------------------------------------------
Param(
)
    End {
        $LTSI=Get-LTServiceInfo -EA 0 -Verbose:$False
        if (($LTSI) -and ($LTSI|Get-Member|Where-Object {$_.Name -eq 'ServerPassword'})) {
            write-Debug "Decoding Server Password."
            $Script:LTServiceKeys.ServerPasswordString=$(ConvertFrom-LTSecurity -InputString "$($LTSI.ServerPassword)")
            if (($LTSI) -ne $Null -and ($LTSI|Get-Member|Where-Object {$_.Name -eq 'Password'})) {
                Write-Debug "Decoding Agent Password."
                $Script:LTServiceKeys.PasswordString=$(ConvertFrom-LTSecurity -InputString "$($LTSI.Password)" -Key "$($Script:LTServiceKeys.ServerPasswordString)")
            } else {
                $Script:LTServiceKeys.PasswordString=''
            }
        } else {
            $Script:LTServiceKeys.ServerPasswordString=''
        }
    }#End 
}#End Function Get-LTServiceKeys
#endregion Get-LTServiceKeys

Function ConvertFrom-LTSecurity{
#region [ConvertFrom-LTSecurity]----------------------------------------------------
Param(
    [parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 1)]
    [string[]]$InputString,

    [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [string[]]$Key,

    [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
    [switch]$Force=$True
)

    Begin {
        $DefaultKey='Thank you for using LabTech.'
        $_initializationVector = [byte[]](240, 3, 45, 29, 0, 76, 173, 59)
        $NoKeyPassed=$False
        $DecodedString=$Null
        $DecodeString=$Null
    }#End Begin

    Process {
        If ($Key -eq $Null) {
            $NoKeyPassed=$True
            $Key=$DefaultKey
        }
        foreach ($testInput in $InputString) {
            $DecodeString=$Null
            foreach ($testKey in $Key) {
                If ($DecodeString -eq $Null) {
                    If ($testKey -eq $Null) {
                        $NoKeyPassed=$True
                        $testKey=$DefaultKey
                    }#End If
                    try {
                        $numarray=[System.Convert]::FromBase64String($testInput)
                        $ddd = new-object System.Security.Cryptography.TripleDESCryptoServiceProvider
                        $ddd.key=(new-Object Security.Cryptography.MD5CryptoServiceProvider).ComputeHash([Text.Encoding]::UTF8.GetBytes($testKey))
                        $ddd.IV=$_initializationVector
                        $dd=$ddd.CreateDecryptor()
                        $DecodeString=[System.Text.Encoding]::UTF8.GetString($dd.TransformFinalBlock($numarray,0,($numarray.Length)))
                        $DecodedString+=@($DecodeString)
                    } catch {
                    }#End Catch

                    Finally {
                        if ((Get-Variable -Name dd -Scope 0 -EA 0)) {try {$dd.Dispose()} catch {$dd.Clear()}}
                        if ((Get-Variable -Name ddd -Scope 0 -EA 0)) {try {$ddd.Dispose()} catch {$ddd.Clear()}}
                    }#End Finally
                } else {
                }#End If
            }#End foreach
            if ($DecodeString -eq $Null) {
                If ($Force) {
                    If (($NoKeyPassed)) {
                        $DecodeString=ConvertFrom-LTSecurity -InputString "$($testInput)" -Key '' -Force:$False
                        if (-not ($DecodeString -eq $Null)) {
                            $DecodedString+=@($DecodeString)
                        }
                    } Else {
                        $DecodeString=ConvertFrom-LTSecurity -InputString "$($testInput)"
                        if (-not ($DecodeString -eq $Null)) {
                            $DecodedString+=@($DecodeString)
                        }
                    }#End If
                } Else {
                }#End If
            }#End If
        }#End foreach
    }#End Process

    End {
        If ($DecodedString -eq $Null) {
            Write-Debug "Failed to Decode string: '$($InputString)'"
            return $Null
        } else {
            return $DecodedString
        }#End If
   }#End End

}#End Function ConvertFrom-LTSecurity
#endregion ConvertFrom-LTSecurity

Function ConvertTo-LTSecurity{
#region [ConvertTo-LTSecurity]----------------------------------------------------
Param(
    [parameter(Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [string]$InputString,

    [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    $Key
)

    Begin {
        $_initializationVector = [byte[]](240, 3, 45, 29, 0, 76, 173, 59)
        $DefaultKey='Thank you for using LabTech.'

        If ($Key -eq $Null) {
            $Key=$DefaultKey
        }#End If

        try {
            $numarray=[System.Text.Encoding]::UTF8.GetBytes($InputString)
        } catch {
            try { $numarray=[System.Text.Encoding]::ASCII.GetBytes($InputString) } catch {}
        }
        try {
            $ddd = new-object System.Security.Cryptography.TripleDESCryptoServiceProvider
            $ddd.key=(new-Object Security.Cryptography.MD5CryptoServiceProvider).ComputeHash([Text.Encoding]::UTF8.GetBytes($Key))
            $ddd.IV=$_initializationVector
            $dd=$ddd.CreateEncryptor()
            $str=[System.Convert]::ToBase64String($dd.TransformFinalBlock($numarray,0,($numarray.Length)))
        } 
        catch {
            Write-Debug "Failed to Encrypt string."; $str=''
        }
        Finally
        {
            if ($dd) {try {$dd.Dispose()} catch {$dd.Clear()}}
            if ($ddd) {try {$ddd.Dispose()} catch {$ddd.Clear()}}
        }
        return $str
    }#End Begin
}#End Function ConvertTo-LTSecurity
#endregion ConvertTo-LTSecurity

Function Set-LTProxy{
#region [Set-LTProxy]-----------------------------------------------------------
<#
.SYNOPSIS
    This function configures module functions to use the specified proxy configuration for all operations as long as the module remains loaded.

.DESCRIPTION
    This function will set or clear Proxy settings needed for function and agent operations. If an agent is already installed, 
    this function will set the ProxyUsername, ProxyPassword, and ProxyServerURL values for the Agent.
    NOTE - Agent Services will be restarted while changes (if found) are applied.

.PARAMETER ProxyServerURL
    This is the URL and Port to assign as the ProxyServerURL for Module
    operations during this session and for the Installed Agent (if present).
    Example: Set-LTProxy -ProxyServerURL 'proxyhostname.fqdn.com'
    Example: Set-LTProxy -ProxyServerURL 'proxyhostname.fqdn.com:8080'
    This parameter may be used with the additional following parameters:
    ProxyUsername, ProxyPassword, EncodedProxyUsername, EncodedProxyPassword

.PARAMETER ProxyUsername
    This is the plain text Username for Proxy operations.
    Example: Set-LTProxy -ProxyServerURL 'proxyhostname.fqdn.com:8080' -ProxyUsername 'Test-User' -ProxyPassword 'SomeFancyPassword'

.PARAMETER ProxyPassword
    This is the plain text Password for Proxy operations.

.PARAMETER EncodedProxyUsername
    This is the encoded Username for Proxy operations. The parameter must be
    encoded with the Agent Password. This Parameter will be decoded using the
    Agent Password, and the decoded string will be configured.
    NOTE: Reinstallation of the Agent will generate a new password.
    Example: Set-LTProxy -ProxyServerURL 'proxyhostname.fqdn.com:8080' -EncodedProxyUsername '1GzhlerwMy0ElG9XNgiIkg==' -EncodedProxyPassword 'Duft4r7fekTp5YnQL9F0V9TbP7sKzm0n'

.PARAMETER EncodedProxyPassword
    This is the encoded Password for Proxy operations. The parameter must be
    encoded with the Agent Password. This Parameter will be decoded using the
    Agent Password, and the decoded string will be configured.
    NOTE: Reinstallation of the Agent will generate a new password.

.PARAMETER DetectProxy
    This parameter attempts to automatically detect the system Proxy settings
    for Module operations during this session. Discovered settings will be
    assigned to the Installed Agent (if present).
    Example: Set-LTProxy -DetectProxy
    This parameter may not be used with other parameters.

.PARAMETER ResetProxy
    This parameter clears any currently defined Proxy Settings for Module
    operations during this session. Discovered settings will be assigned
    to the Installed Agent (if present).
    Example: Set-LTProxy -ResetProxy
    This parameter may not be used with other parameters.

.NOTES
    Version:        1.1
    Author:         Darren White (Module by Chris Taylor)
    Website:        labtechconsulting.com
    Creation Date:  1/24/2018
    Purpose/Change: Initial script development

.LINK
    http://labtechconsulting.com
#>

[CmdletBinding(SupportsShouldProcess=$true)]
Param(
    [parameter(Mandatory = $False, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0)]
    [string]$ProxyServerURL,

    [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True, Position = 1)]
    [string]$ProxyUsername,

    [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True, Position = 2)]
    [string]$ProxyPassword,

    [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
    [string]$EncodedProxyUsername,

    [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
    [string]$EncodedProxyPassword,

    [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
    [alias('Detect')]
    [alias('AutoDetect')]
    [switch]$DetectProxy,

    [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
    [alias('Clear')]
    [alias('Reset')]
    [alias('ClearProxy')]
    [switch]$ResetProxy
)

    Begin {
        Clear-Variable LTServiceSettingsChanged,LTSS,LTServiceRestartNeeded,proxyURL,proxyUser,proxyPass,passwd,Svr -EA 0 #Clearing Variables for use
        try {
            $LTSS=Get-LTServiceSettings -EA 0 -Verbose:$False -WA 0 -Debug:$False
        } catch {}

    }#End Begin

    Process{

        If (
(($ResetProxy -eq $True) -and (($DetectProxy -eq $True) -or ($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword))) -or 
(($DetectProxy -eq $True) -and (($ResetProxy -eq $True) -or ($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword))) -or 
((($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword)) -and (($ResetProxy -eq $True) -or ($DetectProxy -eq $True))) -or 
((($ProxyUsername) -or ($ProxyPassword)) -and (-not ($ProxyServerURL) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword) -or ($ResetProxy -eq $True) -or ($DetectProxy -eq $True))) -or 
((($EncodedProxyUsername) -or ($EncodedProxyPassword)) -and (-not ($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($ResetProxy -eq $True) -or ($DetectProxy -eq $True)))
        ) {Write-Error "Set-LTProxy: Invalid Parameter specified"; Break}
        If (-not (($ResetProxy -eq $True) -or ($DetectProxy -eq $True) -or ($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword))) 
        {
            If ($Args.Count -gt 0) {Write-Error "Set-LTProxy: Unknown Parameter specified"; Break}
            Else {Write-Error "Set-LTProxy: Required Parameters Missing"; Break}
        }

        Try{
            If ($($ResetProxy) -eq $True) {
                Write-Verbose "ResetProxy selected. Clearing Proxy Settings."
                If ( $PSCmdlet.ShouldProcess("LTProxy", "Clear") ) {
                    $Script:LTProxy.Enabled=$False
                    $Script:LTProxy.ProxyServerURL=''
                    $Script:LTProxy.ProxyUsername=''
                    $Script:LTProxy.ProxyPassword=''
                    $Script:LTWebProxy=New-Object System.Net.WebProxy
                    $Script:LTServiceNetWebClient.Proxy=$Script:LTWebProxy
                }#End If
            } ElseIf ($($DetectProxy) -eq $True) {
                Write-Verbose "DetectProxy selected. Attempting to Detect Proxy Settings."
                If ( $PSCmdlet.ShouldProcess("LTProxy", "Detect") ) {
                    $Script:LTWebProxy=[System.Net.WebRequest]::GetSystemWebProxy()
                    $Script:LTProxy.Enabled=$False
                    $Script:LTProxy.ProxyServerURL=''
                    $Servers = @($("$($LTSS|Select-Object -Expand 'ServerAddress' -EA 0)|www.connectwise.com").Split('|')|ForEach-Object {$_.Trim()})
                    Foreach ($Svr In $Servers) {
                        If (-not ($Script:LTProxy.Enabled)) {
                            If ($Svr -match '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*){1,})$') {
                                $Svr = $Svr -replace 'https?://',''
                                Try{
                                    $Script:LTProxy.ProxyServerURL=$Script:LTWebProxy.GetProxy("http://$($Svr)").Authority
                                } catch {}
                                If (($Script:LTProxy.ProxyServerURL -ne $Null) -and ($Script:LTProxy.ProxyServerURL -ne '') -and ($Script:LTProxy.ProxyServerURL -notcontains "$($Svr)")) {
                                    Write-Debug "Detected Proxy URL: $($Script:LTProxy.ProxyServerURL) on server $($Svr)"
                                    $Script:LTProxy.Enabled=$True
                                }#End If
                            }#End If
                        }#End If
                    }#End Foreach
                    If (-not ($Script:LTProxy.Enabled)) {
                        if (($Script:LTProxy.ProxyServerURL -eq '') -or ($Script:LTProxy.ProxyServerURL -contains '$Svr')) {
                            $Script:LTProxy.ProxyServerURL = netsh winhttp show proxy | select-string -pattern '(?i)(?<=Proxyserver.*http\=)([^;\r\n]*)' -EA 0|ForEach-Object {$_.matches}|Select-Object -Expand value
                        }
                        if (($Script:LTProxy.ProxyServerURL -eq $Null) -or ($Script:LTProxy.ProxyServerURL -eq '')) {
                            $Script:LTProxy.ProxyServerURL=''
                            $Script:LTProxy.Enabled=$False
                        } else {
                            $Script:LTProxy.Enabled=$True
                            Write-Debug "Detected Proxy URL: $($Script:LTProxy.ProxyServerURL)"
                        }
                    }#End If
                    $Script:LTProxy.ProxyUsername=''
                    $Script:LTProxy.ProxyPassword=''
                    $Script:LTServiceNetWebClient.Proxy=$Script:LTWebProxy
                }#End If
            } ElseIf (($ProxyServerURL)) {
                If ( $PSCmdlet.ShouldProcess("LTProxy", "Set") ) {
                    foreach ($ProxyURL in $ProxyServerURL) {
                        $Script:LTWebProxy = New-Object System.Net.WebProxy($ProxyURL, $true);
                        $Script:LTProxy.Enabled=$True
                        $Script:LTProxy.ProxyServerURL=$ProxyURL
                    }
                    Write-Verbose "Setting Proxy URL to: $($ProxyServerURL)"
                    If ((($ProxyUsername) -and ($ProxyPassword)) -or (($EncodedProxyUsername) -and ($EncodedProxyPassword))) {
                        If (($ProxyUsername)) {
                            foreach ($proxyUser in $ProxyUsername) {
                                $Script:LTProxy.ProxyUsername=$proxyUser
                            }
                        }
                        If (($EncodedProxyUsername)) {
                            foreach ($proxyUser in $EncodedProxyUsername) {
                                $Script:LTProxy.ProxyUsername=$(ConvertFrom-LTSecurity -InputString "$($proxyUser)" -Key ("$($Script:LTServiceKeys.PasswordString)",''))
                            }
                        }
                        If (($ProxyPassword)) {
                            foreach ($proxyPass in $ProxyPassword) {
                                $Script:LTProxy.ProxyPassword=$proxyPass
                                $passwd = ConvertTo-SecureString $proxyPass -AsPlainText -Force; ## Website credentials
                            }
                        }
                        If (($EncodedProxyPassword)) {
                            foreach ($proxyPass in $EncodedProxyPassword) {
                                $Script:LTProxy.ProxyPassword=$(ConvertFrom-LTSecurity -InputString "$($proxyPass)" -Key ("$($Script:LTServiceKeys.PasswordString)",''))
                                $passwd = ConvertTo-SecureString $Script:LTProxy.ProxyPassword -AsPlainText -Force; ## Website credentials
                            }
                        }
                        $Script:LTWebProxy.Credentials = New-Object System.Management.Automation.PSCredential ($Script:LTProxy.ProxyUsername, $passwd);
                    }#End If
                    $Script:LTServiceNetWebClient.Proxy=$Script:LTWebProxy
                }#End If
            }#End If
        }#End Try
    
        Catch{
            Write-Error "ERROR: There was an error during the Proxy Configuration process. $($Error[0])" -ErrorAction Stop
        }#End Catch
    }#End Process
  
    End{
        If ($?){
            $LTServiceSettingsChanged=$False
            If (($LTSS) -ne $Null) {
                If (($LTSS|Get-Member|Where-Object {$_.Name -eq 'ProxyServerURL'})) {
                    If ($($LTSS|Select-object -Expand ProxyServerURL -EA 0) -match 'https?://.*') {
                        If ($($LTSS|Select-object -Expand ProxyServerURL -EA 0) -ne "http://$($Script:LTProxy.ProxyServerURL)") {
                            Write-Debug "ProxyServerURL Changed: Old Value: $($LTSS|Select-object -Expand ProxyServerURL -EA 0) New Value: http://$($Script:LTProxy.ProxyServerURL)"
                            $LTServiceSettingsChanged=$True
                        }
                    } Else {
                        If (($($LTSS|Select-object -Expand ProxyServerURL -EA 0) -replace 'https?://','' -ne $Script:LTProxy.ProxyServerURL) -and ($($LTSS|Select-object -Expand ProxyServerURL -EA 0) -replace 'https?://','' -ne '' -or $Script:LTProxy.ProxyServerURL -ne '')) {
                            Write-Debug "ProxyServerURL Changed: Old Value: $($LTSS|Select-object -Expand ProxyServerURL -EA 0) New Value: $($Script:LTProxy.ProxyServerURL)"
                            $LTServiceSettingsChanged=$True
                        }
                    }
                }#End If
                if (($LTSS|Get-Member|Where-Object {$_.Name -eq 'ProxyUsername'}) -and ($LTSS|Select-object -Expand ProxyUsername -EA 0)) {
                    If ($(ConvertFrom-LTSecurity -InputString "$($LTSS|Select-object -Expand ProxyUsername -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",'')) -ne $Script:LTProxy.ProxyUsername) {
                        Write-Debug "ProxyUsername Changed: Old Value: $(ConvertFrom-LTSecurity -InputString "$($LTSS|Select-object -Expand ProxyUsername -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",'')) New Value: $($Script:LTProxy.ProxyUsername)"
                        $LTServiceSettingsChanged=$True
                    }
                }#End If
                If (($LTSS) -ne $Null -and ($LTSS|Get-Member|Where-Object {$_.Name -eq 'ProxyPassword'}) -and ($LTSS|Select-object -Expand ProxyPassword -EA 0)) {
                    If ($(ConvertFrom-LTSecurity -InputString "$($LTSS|Select-object -Expand ProxyPassword -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",'')) -ne $Script:LTProxy.ProxyPassword) {
                        Write-Debug "ProxyPassword Changed: Old Value: $(ConvertFrom-LTSecurity -InputString "$($LTSS|Select-object -Expand ProxyPassword -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",'')) New Value: $($Script:LTProxy.ProxyPassword)"
                        $LTServiceSettingsChanged=$True
                    }
                }#End If
            } else {
                $svcRun = ('LTService') | Get-Service -EA 0 | Where-Object {$_.Status -eq 'Running'} | Measure-Object | Select-Object -Expand Count
                if (($svcRun -gt 0) -and ($($Script:LTProxy.ProxyServerURL) -match '.+')) {
                    $LTServiceSettingsChanged=$True
                }#End If
            }#End If
            If ($LTServiceSettingsChanged -eq $True) {
                If ((Get-Service 'LTService','LTSvcMon' -ErrorAction SilentlyContinue|Where-Object {$_.Status -match 'Running'})) { $LTServiceRestartNeeded=$True; try {Stop-LTService -EA 0 -WA 0} catch {} }
                Write-Verbose "Updating LabTech\Service\Settings Proxy Configuration."
                If ( $PSCmdlet.ShouldProcess("LTService Registry", "Update") ) {
                    $Svr=$($Script:LTProxy.ProxyServerURL); If (($Svr -ne '') -and ($Svr -notmatch 'https?://')) {$Svr = "http://$($Svr)"}
                    @{"ProxyServerURL"=$Svr;
                    "ProxyUserName"="$(ConvertTo-LTSecurity -InputString "$($Script:LTProxy.ProxyUserName)" -Key "$($Script:LTServiceKeys.PasswordString)")";
                    "ProxyPassword"="$(ConvertTo-LTSecurity -InputString "$($Script:LTProxy.ProxyPassword)" -Key "$($Script:LTServiceKeys.PasswordString)")"}.GetEnumerator() | Foreach-Object { 
                        Write-Debug "Setting Registry value for $($_.Name) to `"$($_.Value)`""
                        Set-ItemProperty -Path 'HKLM:Software\LabTech\Service\Settings' -Name $($_.Name) -Value $($_.Value) -EA 0
                    }#End Foreach-Object
                }#End If
                If ($LTServiceRestartNeeded -eq $True) { try {Start-LTService -EA 0 -WA 0} catch {} }
            }#End If
        }#End If
        Else {$Error[0]}
    }#End End

}#End Function Set-LTProxy
#endregion Set-LTProxy

Function Get-LTProxy{
#region [Get-LTProxy]-----------------------------------------------------------
<#
.SYNOPSIS
    This function retrieves the current agent proxy settings for module functions to use the specified proxy configuration for all operations as long as the module remains loaded.

.DESCRIPTION
    This function will get the current LabTech Proxy settings from the 
    installed agent (if present). If no agent settings are found, the function
    will attempt to discover the current proxy settings for the system.
    The Proxy Settings determined will be reported.

.NOTES
    Version:        1.1
    Author:         Darren White (Module by Chris Taylor)
    Website:        labtechconsulting.com
    Creation Date:  1/24/2018
    Purpose/Change: Initial script development

.LINK
    http://labtechconsulting.com
#>

    [CmdletBinding()]
    Param(
    )   

  Begin
  {
    Clear-Variable CustomProxyObject,LTSI,LTSS -EA 0 #Clearing Variables for use
    Write-Verbose "Checking for LT Agent Proxy Settings."
  }#End Begin
  
  Process{
  }#End Process
  
  End{
    $Null=Get-LTServiceKeys
    Try {
        $LTSI=Get-LTServiceInfo -EA 0 -Verbose:$False
        If (($LTSI) -ne $Null -and ($LTSI|Get-Member|Where-Object {$_.Name -eq 'ServerPassword'})) {
            $LTSS=Get-LTServiceSettings -EA 0 -Verbose:$False -WA 0 -Debug:$False
            If (($LTSS) -ne $Null) {
                If (($LTSS|Get-Member|Where-Object {$_.Name -eq 'ProxyServerURL'}) -and ($($LTSS|Select-object -Expand ProxyServerURL -EA 0) -Match 'https?://.+')) {
                    Write-Debug "Proxy Detected. Setting ProxyServerURL to $($LTSS|Select-object -Expand ProxyServerURL -EA 0)"
                    $Script:LTProxy.Enabled=$True
                    $Script:LTProxy.ProxyServerURL="$($LTSS|Select-object -Expand ProxyServerURL -EA 0)"
                } Else {
                    Write-Debug "Setting ProxyServerURL to "
                    $Script:LTProxy.Enabled=$False
                    $Script:LTProxy.ProxyServerURL=''
                }#End If
                if (($LTSS|Get-Member|Where-Object {$_.Name -eq 'ProxyUsername'}) -and ($LTSS|Select-object -Expand ProxyUsername -EA 0)) {
                    $Script:LTProxy.ProxyUsername="$(ConvertFrom-LTSecurity -InputString "$($LTSS|Select-object -Expand ProxyUsername -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",''))"
                    Write-Debug "Setting ProxyUsername to $($Script:LTProxy.ProxyUsername)"
                } Else {
                    Write-Debug "Setting ProxyUsername to "
                    $Script:LTProxy.ProxyUsername=''
                }#End If
                If (($LTSS|Get-Member|Where-Object {$_.Name -eq 'ProxyPassword'}) -and ($LTSS|Select-object -Expand ProxyPassword -EA 0)) {
                    $Script:LTProxy.ProxyPassword="$(ConvertFrom-LTSecurity -InputString "$($LTSS|Select-object -Expand ProxyPassword -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",''))"
                    Write-Debug "Setting ProxyPassword to $($Script:LTProxy.ProxyPassword)"
                } Else {
                    Write-Debug "Setting ProxyPassword to "
                    $Script:LTProxy.ProxyPassword=''
                }#End If
            }#End If
        } Else {
            Write-Verbose "No Server password or settings exist. No Proxy information will be available."
        }#End If

        return $Script:LTProxy
    }#End Try
    Catch{
      Write-Error "ERROR: There was a problem retrieving Proxy Information. $($Error[0])"
    }#End Catch
  }#End End
}#End Function Get-LTProxy
#endregion Get-LTProxy

Function Initialize-LTServiceModule{
#region [Initialize-LTServiceModule]--------------------------------------------

    #Initialize LTServiceNetWebClient Object
    $Script:LTServiceNetWebClient = New-Object System.Net.WebClient

    #Populate $Script:LTServiceKeys Object
    $Script:LTServiceKeys = New-Object -TypeName PSObject
    Add-Member -InputObject $Script:LTServiceKeys -MemberType NoteProperty -Name ServerPasswordString -Value ''
    Add-Member -InputObject $Script:LTServiceKeys -MemberType NoteProperty -Name PasswordString -Value ''

    #Populate $LTProxy Object
    $Script:LTProxy = New-Object -TypeName PSObject
    Add-Member -InputObject $Script:LTProxy -MemberType NoteProperty -Name ProxyServerURL -Value ''
    Add-Member -InputObject $Script:LTProxy -MemberType NoteProperty -Name ProxyUsername -Value ''
    Add-Member -InputObject $Script:LTProxy -MemberType NoteProperty -Name ProxyPassword -Value ''
    Add-Member -InputObject $Script:LTProxy -MemberType NoteProperty -Name Enabled -Value ''

    #Populate $LTWebProxy Object
    $Script:LTWebProxy=new-object System.Net.WebProxy
    $Script:LTServiceNetWebClient.Proxy=$Script:LTWebProxy

    $Null=Get-LTProxy

}#End Initialize-LTServiceModule
#endregion Initialize-LTServiceModule

#endregion Functions

$PublicFunctions=((@"
Get-LTError
Get-LTLogging
Get-LTProbeErrors
Get-LTProxy
Get-LTServiceInfo
Get-LTServiceInfoBackup
Get-LTServiceSettings
Hide-LTAddRemove
Install-LTService
Invoke-LTServiceCommand
New-LTServiceBackup
Redo-LTService
Rename-LTAddRemove
Reset-LTService
Restart-LTService
Set-LTLogging
Set-LTProxy
Show-LTAddRemove
Start-LTService
Stop-LTService
Test-LTPorts
Uninstall-LTService
"@) -replace "[`r`n]+","`n") -split "[`n]"

$PublicAlias=((@"
ReInstall-LTService
"@) -replace "[`r`n]+","`n") -split "[`n]"

If ($MyInvocation.Line -contains 'Import-Module') {
    Export-ModuleMember -Function $PublicFunctions -Alias $PublicAlias -EA 0 -WA 0
}

$Null=Initialize-LTServiceModule
