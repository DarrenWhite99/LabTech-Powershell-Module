# BRANCH HAS BEEN ABANDONED
**I am leaving this branch because of the lessons learned in escaping the WOW6432 environment under ARM64. Since the Automate agent is not compiled for ARM64 it operates in the x86 WOW environment and so this module works correctly in the WOW context as well.  If the Automate agent is ever supported under ARM64, the approach taken in this branch to expose the native 64bit ARM environment may be necessary.**


# LabTech-Powershell-Module
This is an attempt to create a comprehensive LT PoSH module. 
To import this module in your scripts you can run:
```
(new-object Net.WebClient).DownloadString('https://bit.ly/LTPoSh') | iex
```

# Functions


[ConvertFrom-LTSecurity](LabTech/ConvertFrom-LTSecurity.md)

[ConvertTo-LTSecurity](LabTech/ConvertTo-LTSecurity.md)

[Get-LTError](LabTech/Get-LTError.md)

[Get-LTLogging](LabTech/Get-LTLogging.md)

[Get-LTProbeErrors](LabTech/Get-LTProbeErrors.md)

[Get-LTProxy](LabTech/Get-LTProxy.md)

[Get-LTServiceInfo](LabTech/Get-LTServiceInfo.md)

[Get-LTServiceInfoBackup](LabTech/Get-LTServiceInfoBackup.md)

[Get-LTServiceSettings](LabTech/Get-LTServiceSettings.md)

[Hide-LTAddRemove](LabTech/Hide-LTAddRemove.md)

[Install-LTService](LabTech/Install-LTService.md)

[Invoke-LTServiceCommand](LabTech/Invoke-LTServiceCommand.md)

[New-LTServiceBackup](LabTech/New-LTServiceBackup.md)

[Redo-LTService](LabTech/Redo-LTService.md)

[Rename-LTAddRemove](LabTech/Rename-LTAddRemove.md)

[Reset-LTService](LabTech/Reset-LTService.md)

[Restart-LTService](LabTech/Restart-LTService.md)

[Set-LTLogging](LabTech/Set-LTLogging.md)

[Set-LTProxy](LabTech/Set-LTProxy.md)

[Show-LTAddRemove](LabTech/Show-LTAddRemove.md)

[Start-LTService](LabTech/Start-LTService.md)

[Stop-LTService](LabTech/Stop-LTService.md)

[Test-LTPorts](LabTech/Test-LTPorts.md)

[Uninstall-LTService](LabTech/Uninstall-LTService.md)

[Update-LTService](LabTech/Update-LTService.md)

