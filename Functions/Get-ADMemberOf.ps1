Function Get-ADMemberOf {
<#
.SYNOPSIS
    Retrives an identitys memberof. Works for accounts, groups and computers
 
 
.NOTES
    Name: Get-ADMemberOf
    Author: Edwin
    Version: 1.0
    DateCreated: 2025-10-10
#>
 
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0
            )]
        [object]  $Identity
    )
    PROCESS {
        if($Identity -is [Microsoft.ActiveDirectory.Management.ADComputer]){
            $IdentityObj = $Identity | Get-ADComputer -Properties memberof
        }elseif($Identity -is [Microsoft.ActiveDirectory.Management.ADServiceAccount]){
            $IdentityObj = $Identity | Get-ADServiceAccount -Properties memberof
        }elseif($Identity -is [Microsoft.ActiveDirectory.Management.ADGroup]){
            $IdentityObj = $Identity | Get-ADGroup -Properties memberof
        }elseif($Identity -is [Microsoft.ActiveDirectory.Management.ADAccount]){
            $IdentityObj = $Identity | Get-ADUser -Properties memberof
        }elseif(Get-aduser -Filter {name -eq $Identity -or SamAccountName -eq $Identity}){
            $IdentityObj = Get-aduser -Filter {name -eq $Identity -or SamAccountName -eq $Identity} -Properties memberof
        }elseif (Get-ADGroup -Filter {name -eq $Identity -or SamAccountName -eq $Identity}){
            $IdentityObj = Get-ADGroup -Filter {name -eq $Identity -or SamAccountName -eq $Identity} -Properties memberof
        }elseif (Get-ADComputer -Filter {name -eq $Identity -or SamAccountName -eq "$Identity$"}) {
            $IdentityObj = Get-ADComputer -Filter {name -eq $Identity -or SamAccountName -eq "$Identity$"} -Properties memberof
        }

        $result = [System.Collections.Generic.List[object]]::new()
        foreach($obj in $IdentityObj.memberof){
            $result.add((Get-ADGroup -Identity $obj))
        }
    }
    END {
    $result
    }
}
