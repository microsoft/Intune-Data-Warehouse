<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the
MIT license. See LICENSE in the project root for license information.

.SYNOPSIS
PowerShell cmdlets for accessing the Intune Data Warehouse OData endpoint.

.DESCRIPTION
This module wraps MSAL.PS token acquisition and OData paging against the
Intune Data Warehouse. It demonstrates two supported auth flows:

  - Interactive browser sign-in (default)
  - Device code (terminal-friendly)

The Resource Owner Password Credentials (ROPC) flow and the
-CredentialsFile parameter that used it have been removed. ROPC is
incompatible with MFA and Conditional Access and is not safe to copy into
production. For unattended scenarios, use an app-only client-credentials
flow (see Samples/CSharp/AppAuthenticationSample.cs) or a Managed Identity.
#>

#Requires -Module MSAL.PS

# Intune Data Warehouse first-party AAD application ID. AAD issues tokens
# whose aud claim equals this GUID. All token-acquisition call sites in this
# module use "$script:IntuneDwhAppId/.default" as the MSAL scope.
$script:IntuneDwhAppId = 'c161e42e-d4df-4a3d-9b42-e7a3c31f59d4'

<#
.SYNOPSIS
    Connects to the Intune Data Warehouse and caches an MSAL access token.
.DESCRIPTION
    Acquires a user (delegated) access token via MSAL.PS and stores it for
    use by subsequent module cmdlets. Defaults to interactive browser
    sign-in; pass -DeviceCode for a terminal-friendly flow.
.PARAMETER ApplicationId
    The application (client) ID of an AAD app registered in your tenant
    with permission to read the Intune Data Warehouse API. The app must
    be a Public client with http://localhost as a redirect URI when using
    the default interactive flow.
.PARAMETER User
    UPN of the user to authenticate as. Used as a login hint and, when
    -TenantId is not supplied, as the source of the tenant routing
    domain.
.PARAMETER DataWarehouseURL
    The Intune Data Warehouse URL for your tenant (visible in the Azure
    portal under Intune > Reports > Intune Data Warehouse).
.PARAMETER TenantId
    Optional. AAD tenant ID or verified domain. If omitted, the tenant is
    derived from the UPN's domain.
.PARAMETER DeviceCode
    Switch. Use device-code flow instead of interactive browser sign-in.
.EXAMPLE
    Connect-IntuneDataWarehouse -ApplicationId ee6e1234-5655-4321-83f4-ef4fd36ce1c2 `
                                -User user@tenant.onmicrosoft.com `
                                -DataWarehouseURL https://fef.msua01.manage.microsoft.com/...
.EXAMPLE
    Connect-IntuneDataWarehouse -ApplicationId ee6e... -User user@contoso.com `
                                -DataWarehouseURL https://... -DeviceCode
#>
function Connect-IntuneDataWarehouse {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$ApplicationId,

        [Parameter(Mandatory = $true)]
        [string]$User,

        [Parameter(Mandatory = $true)]
        [string]$DataWarehouseURL,

        [string]$TenantId,

        [switch]$DeviceCode
    )

    if (Test-IntuneDataWarehouseAuthentication -User $User) {
        Write-Host "User is already authenticated."
        return
    }

    if (-not $TenantId) {
        $userUpn = New-Object 'System.Net.Mail.MailAddress' -ArgumentList $User
        $TenantId = $userUpn.Host
    }

    $scope = "$script:IntuneDwhAppId/.default"

    $msalArgs = @{
        ClientId  = $ApplicationId
        TenantId  = $TenantId
        Scopes    = $scope
        LoginHint = $User
    }

    if ($DeviceCode) {
        $authResult = Get-MsalToken @msalArgs -DeviceCode
    }
    else {
        $authResult = Get-MsalToken @msalArgs -Interactive
    }

    if ($authResult -and $authResult.AccessToken) {
        $global:intuneWarehouseAuthResult = $authResult
        $global:intuneWarehouseAuthUser   = $User
        $global:intuneWarehouseURL        = $DataWarehouseURL
    }
    else {
        throw "Authorization access token is null; re-run Connect-IntuneDataWarehouse."
    }
}

<#
.SYNOPSIS
    Lists all available Intune Data Warehouse collections.
.DESCRIPTION
    Calls the service document on the configured Data Warehouse URL and
    returns the sorted list of collection names.
.EXAMPLE
    Get-IntuneDataWarehouseCollectionNames
#>
function Get-IntuneDataWarehouseCollectionNames {
    [cmdletbinding()]
    param ()

    if (-not $global:intuneWarehouseAuthResult) {
        throw "No authentication context. Authenticate first by running 'Connect-IntuneDataWarehouse'."
    }

    $headers = @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer $($global:intuneWarehouseAuthResult.AccessToken)"
    }
    $Collections = Invoke-WebRequest -Uri $global:intuneWarehouseURL -Method Get -Headers $headers -UseBasicParsing
    $AllCollections = ($Collections.Content | ConvertFrom-Json).value.name | Sort-Object
    return $AllCollections
}

<#
.SYNOPSIS
    Returns rows from a single Intune Data Warehouse collection.
.DESCRIPTION
    Queries the Data Warehouse for the named collection. Supports paging
    via -Skip / -Top, optional column projection via -PropertyList, and a
    -All switch that follows @odata.nextLink batches.
.EXAMPLE
    Get-IntuneDataWarehouseCollection -CollectionName devices
.EXAMPLE
    Get-IntuneDataWarehouseCollection -CollectionName users -All -Verbose
#>
function Get-IntuneDataWarehouseCollection {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]   $CollectionName,
        [int]      $Skip = 0,
        [int]      $Top = 10000,
        [string[]] $PropertyList,
        [switch]   $All
    )

    function Invoke-DataWarehouseRequest {
        param
        (
            [Parameter(Mandatory = $true)]
            [string]$Url
        )

        $clientRequestId = [Guid]::NewGuid()
        $headers = @{
            'Content-Type'      = 'application/json'
            'Authorization'     = "Bearer $($global:intuneWarehouseAuthResult.AccessToken)"
            'client-request-id' = $clientRequestId
        }

        Write-Verbose "Request URL = $Url"
        Write-Verbose "Client request ID = $clientRequestId"

        $Response = Invoke-WebRequest -Uri $Url -Method Get -Headers $headers -UseBasicParsing
        return $Response.Content | ConvertFrom-Json
    }

    if (-not $global:intuneWarehouseAuthResult) {
        throw "No authentication context. Authenticate first by running 'Connect-IntuneDataWarehouse'."
    }

    $validCollectionNames = Get-IntuneDataWarehouseCollectionNames

    if (-not ($validCollectionNames.Contains($CollectionName))) {
        throw "Collection name '$CollectionName' doesn't exist."
    }

    $URL = $global:intuneWarehouseURL.Insert($global:intuneWarehouseURL.IndexOf('?'), "/$CollectionName")
    if (-not $All) {
        $URL = "$URL&`$skip=$Skip&`$top=$Top"
    }
    if ($PropertyList -and $PropertyList.Count -gt 0) {
        $URL = "$URL&`$select=$($PropertyList -join ',')"
    }

    do {
        $response = Invoke-DataWarehouseRequest -Url $URL
        Write-Output $response.value
        $URL = $response.'@odata.nextLink'
    }
    while ($URL)
}

<#
.SYNOPSIS
    Tests whether the cached authentication context is valid.
.DESCRIPTION
    Returns $true when a non-expired MSAL access token is cached for the
    optionally specified user. Token expiry is computed against MSAL's
    ExpiresOn (a DateTimeOffset) using TotalMinutes to avoid the
    component-vs-total bug present in the previous ADAL-based module.
.EXAMPLE
    Test-IntuneDataWarehouseAuthentication
.EXAMPLE
    Test-IntuneDataWarehouseAuthentication -User user@contoso.com
#>
function Test-IntuneDataWarehouseAuthentication {
    [cmdletbinding()]
    param
    (
        [string]$User
    )

    if (-not $global:intuneWarehouseAuthResult) {
        return $false
    }

    $expiresOnUtc = $global:intuneWarehouseAuthResult.ExpiresOn.UtcDateTime
    $nowUtc       = (Get-Date).ToUniversalTime()
    $minutesLeft  = ($expiresOnUtc - $nowUtc).TotalMinutes

    if ($minutesLeft -le 0) {
        return $false
    }

    if ($User -and $User -ne $global:intuneWarehouseAuthUser) {
        return $false
    }

    return $true
}

Export-ModuleMember -Function `
    Connect-IntuneDataWarehouse, `
    Get-IntuneDataWarehouseCollectionNames, `
    Get-IntuneDataWarehouseCollection, `
    Test-IntuneDataWarehouseAuthentication
