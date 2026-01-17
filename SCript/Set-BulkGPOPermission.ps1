<#
.DESCRIPTION
  Detta script itererar genom alla Group Policy Objects från Inputfilen och tilldelar 
  specificerade behörigheter till ett konto/tjänstekonto/dator/grupp. 
  
  Användningsfall: När ett tjänstekonto behöver läs- eller redigeringsåtkomst 
  till GPO:er och ärvda behörigheter inte kan användas.
  
  Scriptet loggar framgång/misslyckanden för varje GPO och ger en tydlig överblick 
  av resultatet.

.NOTES
    Filnamn      : Set-BulkGPOPermission.ps1
    Författare   : Edwin Colliander
    Skapad       : 2026-01-08
    Senast ändrad: 2026-01-12
    Version      : 1.0
#>

# --- Nödvändig modul ---
Import-Module GroupPolicy

# --- Konfiguration ---
$InputFile = Import-Csv "C:\temp\Lista.csv" -Delimiter ";" -Encoding UTF8        # Input fil med GPOer som ska modifieras. Viktigt att ID och DisplayName finns med och angivna som propertys
$TargetName = "DOMAIN\account$"                                                  # Ange konto/tjänstekonto/dator/grupp
$TargetType = "User"                                                             # Ange kontotyp: User, Group, Computer
$PermissionLevel = "GpoEditDeleteModifySecurity"                                 # Ange behörighet
$Log = "C:\temp\log.txt"                                                         # Ange sökväg till loggfil

# --- Utförande ---
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
