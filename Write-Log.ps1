<#
    .SYNOPSIS
    This fucntions are designed to create Microsoft Endpoing Configuration Manager style format logs.

    .DESCRIPTION

    Write-Log is a function that creates log events using Confiugraiton Manager stype formatting so it is best to 
    review the log using CMTrace.exe which can be obtained from Microsoft Downloads. The log file will be
    stored in the %TEMP% folder and will be called Deploy-DeviceMigrationScripts.log. it is typical for
    client management solutions to execute scripts using the "NT AUTHORITY\System" account context as such
    the log file path should be "%WINDIR%\Temp\Log_File_Name.log".

    .EXAMPLE
    Write-InfoMessage -Message "Information message" -Component $script:component -Thread $PID -File "$($script:scriptName):$(Get-CurrentLine)"

    Creates a informational log entry

    .EXAMPLE
    Write-WarmingMessage -Message "Warning message" -Component $script:component -Thread $PID -File "$($script:scriptName):$(Get-CurrentLine)"

    Creates a warning log entry

    .EXAMPLE
    Write-InfoMessage -Message -ErrorRecord $PSItem -Component $script:component -Thread $PID

    Creates a error log entry
	
	.INPUTS
	None. This script does not support piped input.

	.OUTPUTS
	None. This script does not return a value or an object.

	.NOTES
    CMTrace.exe can be downloaded from Microsoft Downloads using the link below:
	https://www.microsoft.com/en-us/download/details.aspx?id=50012

	.LINK
	None

	.COMPONENT
    Deploy-DeviceMigrationScripts    
    
	.FUNCTIONALITY
	None
#>

[CmdletBinding()]

#==============================================================
#region: Invoke Extension Scripts (dot-source)
#==============================================================

#endregion

#==============================================================
#region: Declare Variables (script-scope).
#==============================================================

# Set install target folder
[string] $script:InstallTargetFolderPath = $Path

# Get script name
[string] $script:scriptName = $MyInvocation.MyCommand.Name

# Get invocation name
[string] $script:component = $script:scriptName.Substring(0,$script:scriptName.Length-4)

# Build log file path
[string] $script:logFile = "$env:TEMP\$script:component.log"

#endregion

function Write-Log {

    [CmdletBinding()]

    Param (
        [Parameter(Mandatory)]
        [string]
        $Message,
            
        [Parameter(Mandatory)]
        [string]
        $Component,
            
        [Parameter(Mandatory)]
        [ValidateSet('Info','Warning','Error')]
        [string]
        $Severity,
                
        [Parameter(Mandatory)]
        [int32]
        $Thread,
                
        [Parameter(Mandatory)]
        [string]
        $File,
                    
        [Parameter(Mandatory)]
        [string]
        $LogFile
    )

    process {
        switch ($Severity) {
            Info    { [int] $local:type = 1 ; continue }
            Warning { [int] $local:type = 2 ; continue }
            Error   { [int] $local:type = 3 ; continue }
        }
                
        # Get time
        $local:time = Get-Date -Format "HH:mm:ss.ffffff"
                
        # Get date
        $local:date = Get-Date -Format "MM-dd-yyyy"
                
        # Build message
        $local:logMessage = "<![LOG[$Message]LOG]!><time=`"$local:time`" date=`"$local:date`" component=`"$Component`" context=`"`" type=`"$local:type`" thread=`"$Thread`" file=`"$File`">"
                
        # Write to log
        $local:logMessage | Out-File -Append -Encoding utf8 -FilePath $LogFile -Force
    }
}
function Get-CurrentLine {
    $MyInvocation.ScriptLineNumber
}
function Write-InfoMessage {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory=$true)]
        [string]
        $Message,
            
        [Parameter(Mandatory=$true)]
        [string]
        $Component,

        [Parameter(Mandatory=$false)]
        [string]
        $Severity = 'Info',

        [Parameter(Mandatory=$true)]
        [int32]
        $Thread,

        [Parameter(Mandatory=$true)]
        [string]
        $File
    )

    Process {
        
        # Create empty ordered array
        $local:writeLog = @{}

        # Create Write-Log splat
        $local:writeLog = [ordered]@{
            Message = $Message
            Component = $Component
            Severity = $Severity
            Thread = $Thread
            File = $File
            LogFile = $script:logFile
        }
        
        # Write the log messages
        Write-Log @local:writeLog
    }
}
function Write-WarmingMessage {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory=$true)]
        [string]
        $Message,
            
        [Parameter(Mandatory=$true)]
        [string]
        $Component,

        [Parameter(Mandatory=$false)]
        [string]
        $Severity = 'Warning',

        [Parameter(Mandatory=$true)]
        [int32]
        $Thread,

        [Parameter(Mandatory=$true)]
        [string]
        $File
    )

    Process {

        # Create empty ordered array
        $local:writeLog = @{}

        $local:writeLog = [ordered]@{
            Message = $Message
            Component = $Component
            Severity = $Severity
            Thread = $Thread
            File = $File
            LogFile = $script:logFile
        }
        
        # Write the log messages
        Write-Log @local:writeLog
    }
}
function Write-ErrorMessage {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [psobject]
        $ErrorRecord,

        [Parameter(Mandatory=$true)]
        [string]
        $Component,

        [Parameter(Mandatory=$false)]
        [string]
        $Severity = 'Error',

        [Parameter(Mandatory=$true)]
        [string]
        $Thread
    )

    Process {
        # Set severity level
            

        # Format StackTrace
        [string[]] $local:messages = @()
        [string[]] $local:stackTraces = @()
        $local:writeLog = [System.Collections.Specialized.OrderedDictionary]::new()

        [string] $local:FileName = $($ErrorRecord.InvocationInfo.PSCommandPath | Split-Path -Leaf)
        [string] $local:LineNumber = $($ErrorRecord.InvocationInfo.ScriptLineNumber)

        [string] $local:file = "$($local:FileName):$($local:LineNumber)"

        # Get StackTrace
        $local:stackTraces = $ErrorRecord.ScriptStackTrace -split "`r?`n" | ForEach-Object {"++++ $_"}

        # Build messages to log
        $local:messages = @(
            'Exception Detected:',"++++ Message: $ErrorRecord",
            "++++ Line: $($ErrorRecord.InvocationInfo.ScriptLineNumber): $(($ErrorRecord.InvocationInfo.Line.ToString()).Trim())",
            "++++ Exception: $($ErrorRecord.Exception.GetType())",
            'Call Stack Trace:'
        )

        # Append StackTrace to messages
        $local:messages = $local:messages + $local:stackTraces

        # Log each message
        foreach ($local:message in $local:messages) {
                    
            # Create a hash to splat Write-Log function
            $local:writeLog = [ordered]@{
                Message = $local:message
                Component = $Component
                Severity = $Severity
                Thread = $Thread
                File = $local:file
                LogFile = $script:logFile
            }

            # Write the log messages
            Write-Log @local:writeLog
        }
    }
}