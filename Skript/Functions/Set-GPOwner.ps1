function Set-GPOwner {
    <#
    .SYNOPSIS
        This function assigns a new owner to a Group Policy Object (GPO).
    
    .DESCRIPTION
        This function assigns a new owner to a Group Policy Object (GPO).
    
    .PARAMETER Name
        Name of target GPO. Does not accept pipeline input.
    
    .PARAMETER User
        UserName of new GPO owner.

    .EXAMPLE
        Set-GPOwner -TargetName "MSB 2025" -User "Edwin"
        Sets user "Edwin" as owner of gpo "MSB 2025"
    
    .OUTPUTS
        System.Object
        Returns an object with results
    
    .NOTES
        Function Name : Set-GPOwner
        Author        : Edwin Colliander
        Created       : 2025-11-17
        Last Modified : 2026-01-17
        Version       : 1.0.1
        
    #>
    
    param(
        # Param 1 - Target GPO
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $false
        )]
        [ValidateNotNullOrEmpty()]
        [object]  $Name,

        # Param 2 - User
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $false
        )]
        [ValidateNotNullOrEmpty()]
        [object]  $User


    )
    
    begin {
        # Set error action preference
        $ErrorActionPreference = "Stop"

        # Check: required modules
        if (!(Get-Module -Name ActiveDirectory)) { Import-Module -Name ActiveDirectory }
        if (!(Get-Module -Name GroupPolicy)) { Import-Module -Name GroupPolicy }
        
        # Check: Param 1 - Target GPO
        if ($Name -eq [Microsoft.GroupPolicy.Gpo]) {
            $targetGPO = $Name
        }
        elseif ($Name -is [string]) {
            Write-Verbose "Retriving Group Policy Object $Name"
            $targetGPO = Get-GPO -Name $Name
        }

        # Check: Param 2 - User
        if ($User -eq [Microsoft.ActiveDirectory.Management.ADAccount]) {
            $targetUser = $User
        }
        elseif ($User -is [string]) {
            Write-Verbose "Retriving AD-user: $User"
            $targetUser = Get-ADUser -Identity $User
        }
    }
    
    process {
        # Retrive Group Policy Container
        $filterGUID = "{" + $targetGPO.Id + "}"
        $searchBase = "CN=Policies,$((Get-ADDomain).SystemsContainer)"
        $gpc = (Get-ADObject -Filter { name -like $filterGUID } -SearchBase $searchBase).DistinguishedName

        # Assign new owner
        $acl = Get-Acl -Path "AD:\$gpc"
        $acl.SetOwner([System.Security.Principal.SecurityIdentifier] $targetUser.SID)
        $acl | Set-Acl -AclObject $acl
    }
    
    end {
        Get-GPO -Name $Name
    }
}
