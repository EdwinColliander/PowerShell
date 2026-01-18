<#
.SYNOPSIS
    Brief description of what the script does

.DESCRIPTION
    Detailed description of the script's functionality and use case

.PARAMETER ParameterName
    Description of what the parameter does

.EXAMPLE
    .\ScriptName.ps1 -ParameterName "value"
    Description of what this example does

.NOTES
    Filename     : ScriptName.ps1
    Author       : Your name
    Created      : YYYY-MM-DD
    Last Modified: YYYY-MM-DD
    Version      : 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ParameterName = "DefaultValue",
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

# --- Required module ---


# --- Configuration ---
$ErrorActionPreference = "Stop"
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $ScriptPath "$(Get-Date -Format 'yyyyMMdd_HHmmss')_ScriptLog.log"

# --- Functions ---

function Write-Log {
    <#
    .SYNOPSIS
        Writes messages to log file and console
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    # Write to file
    Add-Content -Path $LogFile -Value $LogMessage
    
    # Write to console with color
    switch ($Level) {
        'INFO'    { Write-Host $LogMessage -ForegroundColor Green }
        'WARNING' { Write-Host $LogMessage -ForegroundColor Yellow }
        'ERROR'   { Write-Host $LogMessage -ForegroundColor Red }
    }
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Checks that all prerequisites are met
    #>
    Write-Log "Checking prerequisites..." -Level INFO
    
    # Example: Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Log "PowerShell version 5 or higher is required" -Level ERROR
        return $false
    }
    
    # Add more checks here
    
    return $true
}

# --- Execution ---

begin {
    try {
        Write-Log "=== Script starting (BEGIN) ===" -Level INFO
        Write-Log "Script running from: $ScriptPath" -Level INFO
        
        # Check prerequisites
        if (-not (Test-Prerequisites)) {
            throw "Prerequisites not met"
        }
        
        # Initialization and preparation
        Write-Log "Initializing..." -Level INFO
        
        # --- YOUR INITIALIZATION CODE HERE ---
        # Example: Create connections, load files, etc.
        
    }
    catch {
        Write-Log "An error occurred in BEGIN block: $($_.Exception.Message)" -Level ERROR
        Write-Log "Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
        throw
    }
}

process {
    try {
        # This block runs once per pipeline object
        Write-Log "Processing object (PROCESS)..." -Level INFO
        
        # --- YOUR PROCESS CODE HERE ---
        # Example using parameter
        Write-Log "Parameter value: $ParameterName" -Level INFO
        
        # If the script receives pipeline input, use $_ here
        # Example: Write-Log "Processing: $_" -Level INFO
        
    }
    catch {
        Write-Log "An error occurred in PROCESS block: $($_.Exception.Message)" -Level ERROR
        Write-Log "Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
        # Choose whether to continue with next object or abort completely
        throw
    }
}

end {
    try {
        Write-Log "Finalizing (END)..." -Level INFO
        
        # --- YOUR FINALIZATION CODE HERE ---
        # Summarize results, close connections, etc.
        
        Write-Log "=== Script completed successfully ===" -Level INFO
        exit 0
    }
    catch {
        Write-Log "An error occurred in END block: $($_.Exception.Message)" -Level ERROR
        Write-Log "Line: $($_.InvocationInfo.ScriptLineNumber)" -Level ERROR
        exit 1
    }
    finally {
        # Cleanup if necessary
        Write-Log "Performing cleanup..." -Level INFO
    }
}
