<#
.DESCRIPTION
  This script iterates through all Group Policy Objects from the input file and assigns 
  specified permissions to an account/service account/computer/group. 
  
  Use case: When a service account needs read or edit access 
  to GPOs and inherited permissions cannot be used.
  
  The script logs success/failures for each GPO and provides a clear overview 
  of the results.

.NOTES
    Filename     : Set-BulkGPOPermission.ps1
    Author       : Edwin Colliander
    Created      : 2026-01-08
    Last modified: 2026-01-18
    Version      : 1.0.1
#>

# --- Required module ---
Import-Module GroupPolicy

# --- Configuration ---
$InputFile = Import-Csv "C:\temp\list.csv" -Delimiter ";" -Encoding UTF8        # Input file with GPOs to be modified. Important that ID and DisplayName are included and specified as properties
$TargetName = "DOMAIN\account$"                                                 # Specify account/service account/computer/group
$TargetType = "User"                                                            # Specify account type: User, Group, Computer
$PermissionLevel = "GpoEditDeleteModifySecurity"                                # Specify permission level
$Log = "C:\temp\log.txt"                                                        # Specify path to log file

# --- Execution ---
Add-Content -Path $Log -Value "###############################################"
Add-Content -Path $Log -Value "Start: $(Get-Date -Format "yyyy-MM-dd: HH:mm:ss")"
foreach ($gpo in $InputFile) {
    try {
        Set-GPPermission -Guid $gpo.id -TargetName $TargetName -TargetType $TargetType -PermissionLevel $PermissionLevel -Confirm:$false -whatif
        #Write-Host "OK: $($gpo.DisplayName)" -ForegroundColor Green
        Add-Content -Path $Log -Value "OK: $($gpo.DisplayName)"
    }
    catch {
        #Write-Host "ERROR: $($gpo.DisplayName) - $($_.Exception.Message)" -ForegroundColor Red
        Add-Content -Path $Log -Value "ERROR: $($gpo.DisplayName) - $($_.Exception.Message)"
    }
}
Add-Content -Path $Log -Value "End: $(Get-Date -Format "yyyy-MM-dd: HH:mm:ss")"
Add-Content -Path $Log -Value "###############################################"
