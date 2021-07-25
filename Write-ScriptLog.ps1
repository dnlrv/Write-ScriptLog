enum LogTarget
{
    FlatFile
    EventViewer
    Both
}

enum LogFormat
{
    RFC3164
    RFC5424
}

enum Severity
{
    EMERGENCY     = 0 # issue has severely impacted script system's usability
    ALERT         = 1 # action must be taken immediately
    CRITICAL      = 2 # critical conditions
    ERROR         = 3 # error conditions
    WARNING       = 4 # warning conditions 
    NOTICE        = 5 # normal but significant conditions
    INFORMATIONAL = 6 # informational messages
    DEBUG         = 7 # debug messages
}

###########
#region ### global:Register-EventLogSource # Registers a new Event Source for the Event Viewer
###########
function global:Register-EventLogSource
{
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "The name of the new event source.")]
        [Severity]$Name,

        [Parameter(Mandatory = $false, HelpMessage = "The log name to register the new event source. Default is 'Application'.")]
        [System.String]$LogName = "Application"
    )
    
    # if this execution is running as local admin, then proceed
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        # check to see if the source is already registered
        if ([System.Diagnostics.EventLog]::SourceExists($Name))
        {
            Write-Warning = ("This source {0} is already registered." -f $Name)
            Exit 101 # EXITCODE 101 : Event Source already registered.
        }
        else
        {
            # attempt to register it
            Try
            {
                Write-Host ("Attempting to register [{0}] as new event source in the [{1}] Log ... " -f $Name, $LogName) -NoNewline
                New-EventLog -Source $Name -LogName $LogName
                Write-Host ("Done!") -ForegroundColor Green
            }
            Catch
            {
                Write-Host ("Error!") -ForegroundColor Red
                Write-Error $_.Exception.Message
            }
        }# else
    }# if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
    else # otherwise inform the user this needs to run as local admin and quit
    {
        Write-Warning = "This function needs to run on an elevated prompt. Run PowerShell as an Administrator and try it again."
        Exit 102 # EXITCODE 102 : Not running with an elevated prompt
    }
}# function global:Register-EventLogSource
#endregion
###########

###########
#region ### global:Write-ScriptLog # Writes to the Script Log in RFC 3164 format
###########
function global:Write-ScriptLog
{
    [CmdletBinding(DefaultParameterSetName="RFC3164")]
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "The message to log.")]
		[System.String]$Message,

        [Parameter(Mandatory = $false, HelpMessage = "The facility of the message to log.")]
		[System.Int32]$Facility = $Script:LogFacility,

        [Parameter(Mandatory = $false, HelpMessage = "The severity of the message to log.")]
		[Severity]$Severity,

        [Parameter(Mandatory = $false, HelpMessage = "The Structured Data part of the message.",ParameterSetName="RFC5424")]
        [System.String[]]$StructuredData = "-",

        [Parameter(Mandatory = $false, HelpMessage = "The process name or ID of the application.",ParameterSetName="RFC5424")]
        [System.String]$ProcessID = "-",

        [Parameter(Mandatory = $false, HelpMessage = "The message ID number.",ParameterSetName="RFC5424")]
        [System.String]$MessageID = "-",

        [Parameter(Mandatory = $false, HelpMessage = "The LogName to write the message.")]
        [System.String]$LogName = $Script:LogName,

        [Parameter(Mandatory = $false, HelpMessage = "The Source for the message.")]
        [System.String]$Source = $Script:LogSource,

        [Parameter(Mandatory = $false, HelpMessage = "The EventID for message.")]
        [System.Int32]$EventID = 999,

        [Parameter(Mandatory = $false, HelpMessage = "The LogName to write the message.")]
        [ValidateSet("Error","Information","FailureAudit","SuccessAudit","Warning")]
        [System.String]$EntryType = "Information"
    )# param

    # if the format is RFC3164
    if ($Script:LogFormat -eq [LogFormat]::RFC3164)
    {
        # setting the log message in RFC 3164 format, Facility is 16 'local use 0'
        $Log = ("<{0}>{1} {2} {3}:{4}" -f ($Facility * 8 + $Severity), (Get-Date -Format "MMM dd hh:mm:ss"), (hostname), ($Script:MyInvocation.MyCommand).Name, $Message)
    }
    else # otherwise it is in RFC5424 format
    {
        $sd = foreach ($s in $StructuredData) {Write-Output ("[{0}]" -f $s)}
        $sd = $sd -join ""
        $Log = ("<{0}>1 {1} {2} {3} {4} {5} {6} {7}" -f ($Facility * 8 + $Severity), (Get-Date -Format "yyyy-MM-ddThh:mm:ssK"), (hostname), ($Script:MyInvocation.MyCommand).Name, $ProcessID, $MessageID, $sd, $Message)
    }

    # if the Severity value is less than or equal to the LogLevel
    if ($Severity.value__ -le $Script:LogLevel)
    {
        # based on our log target ...
        Switch($Script:LogTarget)
        {
            FlatFile # for flat files, append to our log file
            {
                Write-Output $Log | Out-File -Append -FilePath $Script:LogFileName -Encoding UTF8
            }
            EventViewer # for event viewers, add to the event viewer (PowerShell 5.1 only)
            {
                Write-EventLog -LogName $LogName -Source $Source -Event $EventID -EntryType $EntryType -Message $Log
            }
            Both # for both, do both
            {
                Write-Output $Log | Out-File -Append -FilePath $Script:LogFileName -Encoding UTF8
                Write-EventLog -LogName $LogName -Source $Source -Event $EventID -EntryType $EntryType -Message $Log
            }
            default { break }
        }# Switch($Script:LogTarget)
    }# if ($Severity.value__ -le $Script:LogLevel)

    # if the -Verbose switch was used in the script, also write it to the console
    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent)
    {
        Write-Host $Log -ForegroundColor Yellow
    }
}# function global:Write-ScriptLog
#endregion
###########

###########
#region ### Include these in your main script
###########

. .\Write-ScriptLog.ps1

# Basic Log info

$LogFacility = 16                    # setting the "Log Facility" here. Default is 16 'local use 0'.
$LogLevel    = 7                     # setting the log level that you wish to be logged. Only severity this level and below are logged.
$LogFileName = "log.txt"             # the name of the log file for "FlatFile" use. Ignored if "EventViewer" is used.
$LogTarget   = [LogTarget]::FlatFile # specifying wether "FlatFile" logging or "EventViewer" logging is desired. "Both" is also an option.
$LogFormat   = [LogFormat]::RFC3164  # specifying the RFC log format, either RFC3164 or RFC5424.

# Event Viewer Only

$LogSource   = "Write-ScriptLog"     # The Event Viewer source. Must be registered. See Register-EventLogSource for more info.
$LogName     = "Application"         # The Event LogName to use. Default is the Application log.

### Examples ###
# Writing a basic FlatFile message in RFC3164 format.
# Write-ScriptLog -Severity INFORMATIONAL -Message "The script performed a task." -Verbose

# an RFC5424 format use case. MessageID, ProcessID, and StructuredData are optional.
# Write-ScriptLog -Severity ERROR -MessageID 1234 -ProcessID 1234 -StructuredData "a='1'","b='2'" -Message "My log message"

# writing a basic RFC3164 format message to the Event Viewer
#Write-ScriptLog -Severity DEBUG -EventID 1234 -EntryType Information -Message "My script logged something"

# writing a RFC5424 format message to the Event Viewer
# Write-ScriptLog -Severity ERROR -MessageID 1234 -ProcessID 1234 -StructuredData "a='1'","b='2'" -Message "My log message" -EventID 1234 -EntryType Information

#endregion
###########