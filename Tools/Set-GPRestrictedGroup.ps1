<#
.SYNOPSIS
    Configures Restricted Groups on a newly created GPO to manage local Administrator membership.

.DESCRIPTION
    Automates Restricted Groups configuration by directly manipulating SYSVOL files. 
    The script configures the specified AD groups as local Administrators on computers 
    where the GPO is applied.
    
    Requirements:
    - Target GPO must be newly created (version 0)
    - Restricted Groups enforces exact membership (removes unlisted members)
    
    The script validates GPO version, creates GptTmpl.inf with the group configuration, 
    and updates both SYSVOL and Active Directory with correct version numbers and 
    Client-Side Extension GUIDs.

.PARAMETER GPOName
    Name of the Group Policy Object to configure (must be version 0).

.PARAMETER Groups
    AD group(s) to add as local Administrators via Restricted Groups.

.EXAMPLE
    .\Set-GPRestrictedGroup.ps1 -GPOName "Server-Admins-GPO" -Groups "Domain Admins"

.EXAMPLE
    .\Set-GPRestrictedGroup.ps1 -GPOName "Workstation-GPO" -Groups "Domain Admins","IT-Support"

.NOTES
    Filename     : Set-GPRestrictedGroup.ps1
    Author       : Edwin Colliander
    Created      : 2026-01-22
    Last Modified: 2026-01-23
    Version      : 1.0

    Prerequisites: 
    - Active Directory and GroupPolicy PowerShell modules
    - Domain Administrator or delegated GPO permissions
    - SYSVOL access
    
    WARNING: Only run on newly created GPOs. Restricted Groups enforces exact membership.
#>

[CmdletBinding()]
param(
    [Parameter(
        Mandatory = $true,
        Position = 0
    )]
    [string]$GPOName,

    [Parameter(
        Mandatory = $true,
        Position = 1
    )]
    [string[]]$Groups
)
# --- Required module ---
Import-Module GroupPolicy
Import-Module ActiveDirectory

# --- Configuration ---
$ErrorActionPreference = "Stop"

# Target PDC Emulator for authoritative GPO operations
$domain = Get-ADDomain
$pdcEmulator = $domain.PDCEmulator
$domainDnsRoot = $domain.DNSRoot
$uncSysvol = "\\$pdcEmulator\SYSVOL\$domainDnsRoot"


# Retrieve AD objects (groups and GPO)
$groupObjects = foreach ($groupName in $Groups) {
    Get-ADGroup -Identity $groupName
}
$gpoObject = Get-GPO -Name $GPOName
$gpoSysvolRootPath = "$uncSysvol\Policies\{$($gpoObject.Id)}"
$gptIniPath = "$gpoSysvolRootPath\GPT.ini"


# --- Validation ---
# Verify GPO exists in SYSVOL and is newly created (version 0)
if (-not (Test-Path $gptIniPath)) {
    throw "GPO not found in SYSVOL: $gpoSysvolRootPath"
}

$currentVersion = (Get-Content $gptIniPath | Select-String "Version=").ToString().Split("=")[1]
if ($currentVersion -ne "0") {
    throw "GPO has already been modified (version $currentVersion). This script only runs on new GPOs."
}

# --- Execution ---
# Format SIDs with asterisk prefix for INF syntax
$groupSids = $groupObjects | ForEach-Object { "*$($_.SID.Value)" }
$localAdministrators = "*S-1-5-32-544__Members = $($groupSids -join ',')"

# Create GptTmpl.inf with directory structure
$gptTmplContent = @(
    '[Unicode]'
    'Unicode=yes'
    '[Version]'
    'signature="$CHICAGO$"'
    'Revision=1'
    '[Group Membership]'
    '*S-1-5-32-544__Memberof ='
    $localAdministrators
)
$gptTmpl = New-Item -Path "$gpoSysvolRootPath\Machine\Microsoft\Windows NT\SecEdit" -Name GptTmpl.inf -ItemType File -Force
Set-Content -Path $gptTmpl -Value $gptTmplContent -Encoding Unicode


# Update GPT.ini
$gptContent = @(
    '[General]'
    'Version=1'
)
Set-Content -Path "$gpoSysvolRootPath\GPT.ini" -Value $gptContent -Encoding Ascii

# Update AD object
Set-ADObject -Identity $gpoObject.Path -Replace @{
    gPCMachineExtensionNames = "[{827D319E-6EAC-11D2-A4EA-00C04F79F83A}{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}]"
    versionNumber            = "1"
}

Write-Verbose "Successfully configured Restricted Groups for GPO '$GPOName'"
Write-Verbose "Added groups: $($Groups -join ', ')"
