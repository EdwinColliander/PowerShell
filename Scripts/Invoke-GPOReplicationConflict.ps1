#Requires -Modules GroupPolicy, ActiveDirectory

#region !! DISCLAIMER !!
<#
################################################################################
##                                                                            ##
##   ██╗    ██╗ █████╗ ██████╗ ███╗   ██╗██╗███╗   ██╗ ██████╗              ##
##   ██║    ██║██╔══██╗██╔══██╗████╗  ██║██║████╗  ██║██╔════╝              ##
##   ██║ █╗ ██║███████║██████╔╝██╔██╗ ██║██║██╔██╗ ██║██║  ███╗             ##
##   ██║███╗██║██╔══██║██╔══██╗██║╚██╗██║██║██║╚██╗██║██║   ██║             ##
##   ╚███╔███╔╝██║  ██║██║  ██║██║ ╚████║██║██║ ╚████║╚██████╔╝             ##
##    ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝             ##
##                                                                            ##
##  THIS SCRIPT IS FOR LAB / TEST ENVIRONMENTS ONLY                          ##
##  DO NOT RUN IN PRODUCTION                                                  ##
##                                                                            ##
##  This script intentionally:                                                ##
##    • Disables AD replication on a domain controller                        ##
##    • Creates replication conflicts in Group Policy Objects                 ##
##    • Modifies NTDS diagnostic registry keys on domain controllers          ##
##                                                                            ##
##  Running this in a production environment WILL cause:                      ##
##    • Authentication failures and service outages                           ##
##    • Data loss or corruption in Active Directory                           ##
##    • GPO inconsistencies affecting all domain-joined machines              ##
##                                                                            ##
##  The author accepts NO responsibility or liability whatsoever for          ##
##  any damage, data loss, or disruption caused by running this script,       ##
##  regardless of environment or circumstances.                               ##
##                                                                            ##
##  By running this script you confirm that you have read this disclaimer     ##
##  and accept full responsibility for the outcome.                           ##
##                                                                            ##
##  ⚠️  This script is 100% vibe coded.                                       ##
##     It was written with good intentions, questionable judgment,            ##
##     and an AI that was just going along with it.                           ##
##                                                                            ##
################################################################################
#>

Write-Warning "=========================================================="
Write-Warning "  LAB / TEST ENVIRONMENT ONLY — DO NOT RUN IN PRODUCTION"
Write-Warning "  The author accepts NO responsibility for any damage."
Write-Warning "  See the script header for the full disclaimer."
Write-Warning "=========================================================="

$consent = Read-Host "`n  Type 'YES I UNDERSTAND' to continue"
if ($consent -ne 'YES I UNDERSTAND') {
    Write-Host "`n  Execution aborted.`n" -ForegroundColor Red
    return
}
#endregion

function Invoke-GPOReplicationConflict {
    <#
    .SYNOPSIS
        Triggers a replication conflict in a GPO to produce CNF objects under
        CN=Machine and CN=User.

    .DESCRIPTION
        Deliberately creates an AD replication conflict for a target GPO by
        disabling replication on DC02, running Import-GPO against both DCs
        separately (producing different objectGUIDs), then re-enabling
        replication so AD must resolve the conflict.

        After the conflict window the function verifies:
          • CNF objects under both CN=Machine and CN=User
          • Event 1083 in the Directory Service log on both DCs

        Diagnostic logging for '5 Replication Events' is temporarily raised
        to level 2 on both DCs to guarantee event capture, then restored.

        Run in lab environments only. Disabling replication in production
        can cause data loss and authentication failures.

    .PARAMETER GPOName
        Name of the GPO to use for the conflict test.

    .PARAMETER DC1
        FQDN of the primary domain controller (Import-GPO source and
        verification target).

    .PARAMETER DC2
        FQDN of the secondary domain controller (replication is disabled
        here during the conflict window).

    .PARAMETER BackupPath
        Local path on the machine running this function where the GPO
        backup will be stored before being copied to DC02.

    .PARAMETER Force
        Continues execution even if individual Import-GPO operations fail.

    .EXAMPLE
        Invoke-GPOReplicationConflict `
            -GPOName    "TEST-APP01-Audit" `
            -DC1        "DC01.colliander.xyz" `
            -DC2        "DC02.colliander.xyz" `
            -BackupPath "C:\temp\GPOBackup"

        Runs the full conflict test and reports results interactively.

    .EXAMPLE
        Invoke-GPOReplicationConflict `
            -GPOName    "TEST-APP01-Audit" `
            -DC1        "DC01.colliander.xyz" `
            -DC2        "DC02.colliander.xyz" `
            -BackupPath "C:\temp\GPOBackup" `
            -Force

        Continues past non-fatal Import-GPO errors.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        PSCustomObject
        Returns a summary object with CNF detection results and event log hits
        per DC and per child container (Machine / User).

    .NOTES
        Function Name : Invoke-GPOReplicationConflict
        Author        : Edwin Colliander
        Created       : 2025-01-01
        Last Modified : 2025-01-01
        Version       : 1.0

    .LINK
        https://docs.microsoft.com/en-us/troubleshoot/windows-server/active-directory/replication-conflicts
    #>

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High'
    )]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$GPOName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DC1,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DC2,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BackupPath,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        Write-Verbose "=== BEGIN: Invoke-GPOReplicationConflict ==="

        Set-StrictMode -Version Latest

        #region Internal helpers
        function Write-Step {
            param([int]$Number, [string]$Text)
            Write-Host "`n══════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "  STEP $Number — $Text" -ForegroundColor Cyan
            Write-Host "══════════════════════════════════════════════" -ForegroundColor Cyan
        }

        function Write-Ok   { param([string]$Text) Write-Host "  [OK]   $Text" -ForegroundColor Green  }
        function Write-Warn { param([string]$Text) Write-Host "  [WARN] $Text" -ForegroundColor Yellow }
        function Write-Fail { param([string]$Text) Write-Host "  [FAIL] $Text" -ForegroundColor Red    }
        function Write-Info { param([string]$Text) Write-Host "  [INFO] $Text" -ForegroundColor Gray   }

        function Get-ChildGUID {
            param(
                [string]$GPOGuid,
                [string]$ChildCN,
                [string]$Server,
                [string]$DomainDN
            )
            $dn = "CN=$ChildCN,CN={$GPOGuid},CN=Policies,CN=System,$DomainDN"
            try {
                $obj = Get-ADObject -Identity $dn -Server $Server -Properties objectGUID -ErrorAction Stop
                return $obj.objectGUID
            } catch {
                return $null
            }
        }

        function Get-DiagnosticLevel {
            param([string]$ComputerName, [string]$ValueName)
            $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Diagnostics'
            Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                (Get-ItemProperty -Path $using:regPath -Name $using:ValueName -ErrorAction SilentlyContinue).$using:ValueName
            }
        }

        function Set-DiagnosticLevel {
            param([string]$ComputerName, [string]$ValueName, [int]$Level)
            $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Diagnostics'
            Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                Set-ItemProperty -Path $using:regPath -Name $using:ValueName -Value $using:Level -Type DWord
            }
        }

        function Find-Event1083 {
            param([string]$ComputerName, [datetime]$Since)
            # Get-WinEvent -ComputerName uses RPC/DCOM which may be blocked.
            # Running via Invoke-Command uses WinRM (port 5985/5986) instead.
            try {
                Invoke-Command -ComputerName $ComputerName -ErrorAction Stop -ScriptBlock {
                    Get-WinEvent -LogName 'Directory Service' -ErrorAction SilentlyContinue |
                        Where-Object { $_.Id -eq 1083 -and $_.TimeCreated -gt $using:Since }
                }
            } catch {
                Write-Warn "Could not query event log on $ComputerName via WinRM: $_"
                return $null
            }
        }
        #endregion

        try {
            Write-Verbose "Initializing — domain detection and GPO lookup"

            $dc1Short = $DC1.Split('.')[0]
            $dc2Short = $DC2.Split('.')[0]

            $domain    = Get-ADDomain -Server $DC1 -ErrorAction Stop
            $domainDN  = $domain.DistinguishedName
            $domainDNS = $domain.DNSRoot

            Write-Verbose "Domain: $domainDNS  ($domainDN)"

            $gpo     = Get-GPO -Name $GPOName -Server $DC1 -ErrorAction Stop
            $gpoGuid = $gpo.Id.ToString()

            Write-Verbose "GPO: $GPOName  ($gpoGuid)"

            New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null

            $childContainers  = @('Machine', 'User')
            $diagKey          = '5 Replication Events'
            $diagTargetLevel  = 2
            $originalDiagLevels = @{}

            # Result scaffold — populated in process / end
            $Result = [PSCustomObject]@{
                GPOName          = $GPOName
                GPOGuid          = $gpoGuid
                Domain           = $domainDNS
                BackupId         = $null
                GUIDsMatch       = @{}
                CNFFound         = @{}
                Event1083        = @{}
                ConflictSuccess  = $false
            }

            Write-Verbose "Initialization complete"
        }
        catch {
            Write-Error "Initialization failed: $($_.Exception.Message)"
            throw
        }
    }

    process {
        #region Step 1 — Backup
        Write-Step 1 "Backup GPO from $DC1"

        if ($PSCmdlet.ShouldProcess($GPOName, "Backup GPO and trigger replication conflict")) {
            try {
                $backup        = Backup-GPO -Name $GPOName -Path $BackupPath -Server $DC1 -ErrorAction Stop
                $backupId      = $backup.Id.ToString()
                $Result.BackupId = $backupId

                Write-Ok "Backup created : $backupId"
                Write-Ok "Path           : $BackupPath\{$backupId}"

                $dc2BackupPath = "\\$dc2Short\C$\temp\GPOBackup"
                New-Item -ItemType Directory -Path $dc2BackupPath -Force | Out-Null
                Copy-Item -Path "$BackupPath\{$backupId}" -Destination $dc2BackupPath -Recurse -Force
                Write-Ok "Backup copied to $dc2BackupPath"
            }
            catch {
                Write-Fail "Backup failed: $_"
                throw
            }
        }
        #endregion

        #region Step 2 — Disable replication on DC02
        Write-Step 2 "Disable replication on $dc2Short"

        try {
            repadmin /options $dc2Short +DISABLE_INBOUND_REPL  | Out-Null
            repadmin /options $dc2Short +DISABLE_OUTBOUND_REPL | Out-Null
            Start-Sleep -Seconds 3

            $replStatus = repadmin /options $dc2Short
            if ($replStatus -match 'DISABLE_INBOUND_REPL' -and $replStatus -match 'DISABLE_OUTBOUND_REPL') {
                Write-Ok "Replication disabled on $dc2Short"
            } else {
                Write-Warn "Could not verify replication is disabled — proceeding anyway"
            }
        }
        catch {
            Write-Fail "Failed to disable replication: $_"
            throw
        }
        #endregion

        #region Step 3 — Import-GPO against both DCs
        Write-Step 3 "Import-GPO against $DC1 and $DC2 separately"

        try {
            Import-GPO `
                -BackupId   $backupId `
                -Path       $BackupPath `
                -TargetName $GPOName `
                -Server     $DC1 `
                -ErrorAction Stop | Out-Null
            Write-Ok "Import-GPO complete on $DC1"
        }
        catch {
            Write-Fail "Import against $DC1 failed: $_"
            if (-not $Force) { throw } else { Write-Warn "Continuing (Force)" }
        }

        Start-Sleep -Seconds 2

        try {
            Invoke-Command -ComputerName $dc2Short -ScriptBlock {
                Import-GPO `
                    -BackupId   $using:backupId `
                    -Path       'C:\temp\GPOBackup' `
                    -TargetName $using:GPOName `
                    -Server     $using:DC2 `
                    -ErrorAction Stop | Out-Null
            }
            Write-Ok "Import-GPO complete on $DC2"
        }
        catch {
            Write-Fail "Import against $DC2 failed: $_"
            if (-not $Force) { throw } else { Write-Warn "Continuing (Force)" }
        }
        #endregion

        #region Step 4 — Verify different GUIDs
        Write-Step 4 "Verify CN=Machine and CN=User have different objectGUIDs per DC"

        Start-Sleep -Seconds 3

        foreach ($child in $childContainers) {
            $g1 = Get-ChildGUID -GPOGuid $gpoGuid -ChildCN $child -Server $DC1 -DomainDN $domainDN
            $g2 = Get-ChildGUID -GPOGuid $gpoGuid -ChildCN $child -Server $DC2 -DomainDN $domainDN

            Write-Host "`n  CN=$child"
            Write-Host "    $DC1 : $g1"
            Write-Host "    $DC2 : $g2"

            if ($null -ne $g1 -and $null -ne $g2 -and $g1 -ne $g2) {
                Write-Ok "GUIDs differ — conflict will occur for CN=$child"
                $Result.GUIDsMatch[$child] = $false
            } elseif ($g1 -eq $g2) {
                Write-Warn "GUIDs are IDENTICAL for CN=$child — conflict may not occur"
                $Result.GUIDsMatch[$child] = $true
            } else {
                Write-Warn "Could not retrieve one or both GUIDs for CN=$child"
                $Result.GUIDsMatch[$child] = $null
            }
        }
        #endregion

        #region Step 5 — Resume replication
        Write-Step 5 "Resume replication and force sync"

        $conflictStartTime = Get-Date

        repadmin /options $dc2Short -DISABLE_INBOUND_REPL  | Out-Null
        repadmin /options $dc2Short -DISABLE_OUTBOUND_REPL | Out-Null
        Write-Ok "Replication re-enabled on $dc2Short"

        repadmin /syncall /AdeP | Out-Null
        Write-Ok "Forced full replication (syncall /AdeP)"

        Write-Info "Waiting 20 seconds for AD to resolve the conflict..."
        Start-Sleep -Seconds 20
        #endregion

        #region Step 6 — Verify CNF objects
        Write-Step 6 "Verify CNF objects under CN=Machine and CN=User"

        $gpoBase = "CN={$gpoGuid},CN=Policies,CN=System,$domainDN"

        try {
            $allChildren = Get-ADObject `
                -SearchBase  $gpoBase `
                -Filter      * `
                -SearchScope OneLevel `
                -Server      $DC1 `
                -Properties  name, objectGUID, whenCreated |
                Select-Object name, objectGUID, whenCreated

            Write-Host "`n  Objects under GPO root on $DC1 :`n"
            $allChildren | Format-Table name, objectGUID, whenCreated -AutoSize

            foreach ($child in $childContainers) {
                $cnfObj = $allChildren | Where-Object { $_.name -match 'CNF' -and $_.name -match $child }
                $Result.CNFFound[$child] = [bool]$cnfObj

                if ($cnfObj) {
                    Write-Ok "CNF object found for CN=$child"
                    $cnfObj | Format-List name, objectGUID, whenCreated
                } else {
                    Write-Warn "No CNF object found yet for CN=$child"
                }
            }

            $Result.ConflictSuccess = $Result.CNFFound.Values -contains $true
        }
        catch {
            Write-Fail "CNF verification failed: $_"
            if (-not $Force) { throw } else { Write-Warn "Continuing (Force)" }
        }

        if (-not $Result.ConflictSuccess) {
            Write-Host "`n  If no CNF appeared yet, wait ~30 s and run manually:" -ForegroundColor Gray
            Write-Host @"

    Get-ADObject ``
        -SearchBase "$gpoBase" ``
        -Filter * ``
        -SearchScope OneLevel ``
        -Server $DC1 ``
        -Properties name, objectGUID |
        Format-Table name, objectGUID -AutoSize
"@ -ForegroundColor Gray
        }
        #endregion

        #region Step 7 — Event 1083 on both DCs
        Write-Step 7 "Check event 1083 in Directory Service log on both DCs"

        <#
            Event 1083 is written at diagnostic level 0 by default, but only
            when AD flushes the conflict record during the logging interval.
            Fast conflicts can be missed entirely at level 0.
            Raising '5 Replication Events' to level 2 ensures sub-events and
            timing-sensitive conflicts are captured. The original level is
            always restored in the finally block below.
        #>

        foreach ($dc in @($dc1Short, $dc2Short)) {
            $originalDiagLevels[$dc] = Get-DiagnosticLevel -ComputerName $dc -ValueName $diagKey
            $currentLevel = if ($null -ne $originalDiagLevels[$dc]) { $originalDiagLevels[$dc] } else { 0 }
            Write-Info "$dc — current '$diagKey' level: $currentLevel"
        }

        try {
            foreach ($dc in @($dc1Short, $dc2Short)) {
                Set-DiagnosticLevel -ComputerName $dc -ValueName $diagKey -Level $diagTargetLevel
                Write-Ok "$dc — diagnostic level raised to $diagTargetLevel"
            }

            Write-Info "Waiting 5 seconds for diagnostics to take effect..."
            Start-Sleep -Seconds 5

            foreach ($dc in @($dc1Short, $dc2Short)) {
                Write-Host "`n  Searching event 1083 on $dc (since $($conflictStartTime.ToString('HH:mm:ss')))..." -ForegroundColor Gray

                $events = Find-Event1083 -ComputerName $dc -Since $conflictStartTime
                $Result.Event1083[$dc] = [bool]$events

                if ($events) {
                    Write-Ok "Event 1083 found on $dc — AD confirms replication conflict"
                    $events | Select-Object TimeCreated, Message | Format-List
                } else {
                    Write-Warn "No event 1083 on $dc within the time window"
                    Write-Info "Possible reasons:"
                    Write-Info "  • Conflict resolved before log flush"
                    Write-Info "  • Directory Service log rolled (increase MaxSize)"
                    Write-Info "  • Diagnostic level was below 1 before this run — re-run to capture fresh events"
                }
            }
        }
        catch {
            Write-Fail "Event log check failed: $_"
            if (-not $Force) { throw } else { Write-Warn "Continuing (Force)" }
        }
        finally {
            foreach ($dc in @($dc1Short, $dc2Short)) {
                $restoreLevel = if ($null -ne $originalDiagLevels[$dc]) { $originalDiagLevels[$dc] } else { 0 }
                Set-DiagnosticLevel -ComputerName $dc -ValueName $diagKey -Level $restoreLevel
                Write-Ok "$dc — '$diagKey' restored to level $restoreLevel"
            }
        }
        #endregion
    }

    end {
        try {
            Write-Verbose "=== END: Finalizing Invoke-GPOReplicationConflict ==="

            Write-Host "`n══════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "  SUMMARY" -ForegroundColor Cyan
            Write-Host "══════════════════════════════════════════════" -ForegroundColor Cyan

            foreach ($child in $childContainers) {
                $cnfStatus   = if ($Result.CNFFound[$child])   { 'YES' } else { 'NO' }
                Write-Host "  CN=$child CNF found : $cnfStatus"
            }
            foreach ($dc in @($dc1Short, $dc2Short)) {
                $eventStatus = if ($Result.Event1083[$dc]) { 'YES' } else { 'NO' }
                Write-Host "  Event 1083 on $dc   : $eventStatus"
            }

            Write-Host "`n  Run gpupdate on a client and inspect gpsvc.log to observe the CNF effect.`n" -ForegroundColor Cyan

            Write-Output $Result
        }
        catch {
            Write-Error "Error during finalization: $($_.Exception.Message)"
            throw
        }
        finally {
            Write-Verbose "Cleanup complete"
        }
    }
}
