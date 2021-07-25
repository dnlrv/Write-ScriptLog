# Write-ScriptLog
Add RFC3164/RFC5424-compatible logging to a flat file or the Event Viewer to your PowerShell scripts.

The following lines must be included in your script:
```
. .\Write-ScriptLog.ps1
$LogFacility = 16                    # setting the "Log Facility" here. Default is 16 'local use 0'.
$LogLevel    = 7                     # setting the log level that you wish to be logged. Only severity this level and below are logged.
$LogFileName = "log.txt"             # the name of the log file for "FlatFile" use. Ignored if "EventViewer" is used.
$LogTarget   = [LogTarget]::FlatFile # specifying wether "FlatFile" logging or "EventViewer" logging is desired. "Both" is also an option.
$LogFormat   = [LogFormat]::RFC3164  # specifying the RFC log format, either RFC3164 or RFC5424.
$LogSource   = "Write-ScriptLog"     # The Event Viewer source. Must be registered. See Register-EventLogSource for more info.
$LogName     = "Application"         # The Event LogName to use. Default is the Application log.
```
## $LogTarget
The $LogTarget is either the specified flat file, or the Event Viewer. If flat file logging is desired, there is no need to register an Event Source for the Event Viewer. Registering a new Event Source requires an elevated prompt and the following:
```
Register-EventLogSource -Name "MyPowerShellScript"
```
This function checks if the session is being run as a local administrator and checks if the Event Source is already registered.

## $LogLevel
The $LogLevel states the kind of logging that should be written to the $LogTarget. This uses the following designations:
```
EMERGENCY     = 0 # issue has severely impacted script system's usability
ALERT         = 1 # action must be taken immediately
CRITICAL      = 2 # critical conditions
ERROR         = 3 # error conditions
WARNING       = 4 # warning conditions 
NOTICE        = 5 # normal but significant conditions
INFORMATIONAL = 6 # informational messages
DEBUG         = 7 # debug messages
```

## Log messages
Log messages will only occur if the $Severity message is less than or equal to the $LogLevel. For example take the following:
```
$LogLevel = 3
Write-ScriptLog -Severity DEBUG -Message "My script is doing this"
```
In this example, the message will not be sent to the $LogTarget as the $Severity parameter's level is greater than the current $LogLevel.

## -Verbose
In addition, you can also print to the console using the -Verbose switch.
```
Write-ScriptLog -Severity INFORMATIONAL -Message "This will print to the console on a Verbose switch." -Verbose
```
In this example, the message will be sent to the console. The message will only be sent to the $LogTarget if the $Severity is less than or equal to the $LogLevel.
