Function Get-ADMemberOf {
<#
.SYNOPSIS
    Retrieves all Active Directory groups that an object is a member of.
 
 .DESCRIPTION
    The Get-ADMemberOf function retrieves all group memberships for Active Directory objects.
    It accepts various object types including users, groups, computers, and service accounts.
    
    The function can accept either:
    - Active Directory objects piped from other cmdlets (Get-ADUser, Get-ADGroup, etc.)
    - String values representing the Name or SamAccountName of an AD object
    
    When a string is provided, the function will automatically search for the object across
    users, groups, and computers to determine the correct object type.

.PARAMETER Identity
    Specifies the Active Directory object to query. This parameter accepts:
    - AD objects (ADUser, ADGroup, ADComputer, ADServiceAccount)
    - String values (Name or SamAccountName)
    
    This parameter is mandatory and accepts pipeline input.

.EXAMPLE
    Get-ADMemberOf -Identity "jdoe"
    
    Retrieves all groups that the user "jdoe" is a member of.

.NOTES
    Filename     : Get-ADMemberOf
    Author       : Edwin Colliander
    Created      : 2025-10-10
    Last Modified: 2026-02-07
    Version      : 1.0

    Prerequisites: 
    - Active Directory PowerShell modules
    
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
