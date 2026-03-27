function Test-LdapsConnection {
    <#
    .SYNOPSIS
        Tests an LDAPS connection against a server and displays certificate information.

    .DESCRIPTION
        Establishes an LDAPS connection against the specified server and port using
        System.DirectoryServices.Protocols. Verifies that the TLS handshake succeeds
        and displays information about the server certificate, including a warning if
        the certificate is approaching expiration.

    .PARAMETER Server
        Hostname or IP address of the LDAP server. Typically a domain controller.

    .PARAMETER Port
        TCP port to connect on. Default value is 636 (LDAPS).
        Use 3269 for LDAPS against the Global Catalog.

    .PARAMETER CertWarningDays
        Number of days before certificate expiration at which a warning is displayed.
        Default value is 30 days.

    .EXAMPLE
        Test-LdapsConnection -Server "dc01.colliander.xyz"
        Tests LDAPS on the default port 636 against dc01.colliander.xyz.

    .EXAMPLE
        Test-LdapsConnection -Server "dc01.colliander.xyz" -Port 3269
        Tests LDAPS against the Global Catalog port 3269.

    .EXAMPLE
        Test-LdapsConnection -Server "dc01.colliander.xyz" -CertWarningDays 60
        Tests LDAPS and warns if the certificate expires within 60 days.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        None. The function writes directly to host with color-coded output.

    .NOTES
        Function Name : Test-LdapsConnection
        Author        : Edwin Colliander
        Created       : 2026-03-10
        Last Modified : 2026-03-10
        Version       : 1.0

        Requires the .NET assembly System.DirectoryServices.Protocols.
        The connection is made anonymously - no credentials required.
        Client certificates are explicitly disabled to avoid PIN prompts.

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Server,

        [int]$Port = 636,

        [int]$CertWarningDays = 30
    )

    Add-Type -AssemblyName System.DirectoryServices.Protocols

    $script:ldapCert = $null

    $conn = New-Object System.DirectoryServices.Protocols.LdapConnection("${Server}:${Port}")
    $conn.SessionOptions.SecureSocketLayer = $true
    $conn.SessionOptions.VerifyServerCertificate = {
        param($conn, $cert)
        $script:ldapCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cert)
        $true
    }
    $conn.SessionOptions.QueryClientCertificate = { $null }
    $conn.AuthType = [System.DirectoryServices.Protocols.AuthType]::Anonymous

    try {
        $conn.Bind()
        Write-Host "LDAPS OK - ${Server}:${Port}" -ForegroundColor Green

        Write-Host "`nCertificate:"
        Write-Host "  Subject:    $($script:ldapCert.Subject)"
        Write-Host "  Issuer:     $($script:ldapCert.Issuer)"
        Write-Host "  Valid from: $($script:ldapCert.NotBefore)"
        Write-Host "  Valid to:   $($script:ldapCert.NotAfter)"
        Write-Host "  Thumbprint: $($script:ldapCert.Thumbprint)"

        $daysLeft = ($script:ldapCert.NotAfter - (Get-Date)).Days
        if ($daysLeft -lt $CertWarningDays) {
            Write-Host "  WARNING: Certificate expires in $daysLeft days!" -ForegroundColor Red
        } else {
            Write-Host "  Expires in: $daysLeft days" -ForegroundColor Green
        }
    } catch {
        Write-Host "LDAPS FAIL - ${Server}:${Port}: $_" -ForegroundColor Red
    }
}
