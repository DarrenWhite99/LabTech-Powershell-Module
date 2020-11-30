---
schema: 2.0.0
---

# Get-LTProxy

## SYNOPSIS
This function retrieves the current agent proxy settings for module functions
 to use the specified proxy configuration for all communication operations as 
 long as the module remains loaded.

## SYNTAX

```
Get-LTProxy [<CommonParameters>]
```

## DESCRIPTION
This function will get the current LabTech Proxy settings from the 
installed agent (if present). If no agent settings are found, the function
will attempt to discover the current proxy settings for the system.
The Proxy Settings determined will be stored in memory for internal use, and
returned as the function result.

## EXAMPLES

## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Version:        1.1

Author:         Darren White

Creation Date:  1/24/2018

Purpose/Change: Initial function development



Update Date: 3/18/2018

Purpose/Change: Ensure ProxyUser and ProxyPassword are set correctly when proxy

is not configured. 


## RELATED LINKS
