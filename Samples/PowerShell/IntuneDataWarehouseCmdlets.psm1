<#
 
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.

#>

<#
.SYNOPSIS
    This function is used to authenticate with the Azure Active Directory using ADAL
.DESCRIPTION
    The function authenticates with Azure Active Directory with a UserPrincipalName
.EXAMPLE
    Connect-IntuneDataWarehouse  -ApplicationId ee6e1234-5655-4321-83f4-ef4fd36ce1c2 -User user@tenant.onmicrosoft.com
    Authenticates you to a specific Application ID within Azure Active Directory with the users UPN
.NOTES
    NAME: Connect-IntuneDataWarehouse
#>
function Connect-IntuneDataWarehouse {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $ApplicationId,
        [Parameter(Mandatory=$true)]
        $User,
        [Parameter(Mandatory=$true)]
        $DataWarehouseURL,
        $CredentialsFile,
        $RedirectUri='urn:ietf:wg:oauth:2.0:oob'
    )

    if (Test-IntuneDataWarehouseAuthentication -User $User) {
        Write-Host "User is already authenticated."
        return
    }

    $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User
    $tenant = $userUpn.Host

    # Finding the AzureAD cmdlets that can be used for authentication.
    $AadModule = Get-Module -Name "AzureAD" -ListAvailable

    if ($AadModule -eq $null) {
        Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
        $AadModule = Get-Module -Name "AzureADPreview" -ListAvailable
    }

    if ($AadModule -eq $null) {
        throw "AzureAD Powershell module not installed...Install by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt"
    }

    # Getting path to Active Directory Assemblies
    # If the module count is greater than 1 find the latest version
    if ($AadModule.count -gt 1) {

        $Latest_Version = ($AadModule | select version | Sort-Object)[-1]
        $aadModule = $AadModule | ? { $_.version -eq $Latest_Version.version }

        # Checking if there are multiple versions of the same module found
        if ($AadModule.count -gt 1) {
            $aadModule = $AadModule | select -Unique
        }

        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    }
    else {
        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    }

    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null

    $resourceAppIdURI = "https://api.manage.microsoft.com/"
    $authority = "https://login.windows.net/$Tenant"

    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority

    # https://msdn.microsoft.com/en-us/library/azure/microsoft.identitymodel.clients.activedirectory.promptbehavior.aspx
    # Change the prompt behaviour to force credentials each time: Auto, Always, Never, RefreshSession
    $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"
    $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")

    if ($CredentialsFile -eq $null){
        $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI,$ApplicationId,$RedirectUri,$platformParameters,$userId).Result
    }
    else {
        if (test-path "$CredentialsFile") {
            $UserPassword = Get-Content "$CredentialsFile" | ConvertTo-SecureString
            $userCredentials = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.UserPasswordCredential -ArgumentList $userUPN,$UserPassword
            $authResult = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContextIntegratedAuthExtensions]::AcquireTokenAsync($authContext, $resourceAppIdURI, $ApplicationId, $userCredentials).Result;
        }
        else {
            throw "Path to Password file $Password doesn't exist, please specify a valid path..."
        }
    }

    if ($authResult.AccessToken) {
        $global:intuneWarehouseAuthResult = $authResult;
        $global:intuneWarehouseAuthUser = $User;
        $global:intuneWarehouseURL = $DataWarehouseURL;
    }
    else {
        throw "Authorization Access Token is null, please re-run authentication..."
    }
}

<#
.SYNOPSIS
    This function is used to get all the Intune Data Warehouse Collection Name
.DESCRIPTION
    The function connects to the Data Warehouse URL and returns all Collection Name
.EXAMPLE
    Get-IntuneDataWarehouseCollectionNames
    Returns all Data Warehouse Collection names
.NOTES
    NAME: Get-IntuneDataWarehouseCollectionNames
#>
function Get-IntuneDataWarehouseCollectionNames {
    [cmdletbinding()]
    param
    (
    )

    if (!$global:intuneWarehouseAuthResult) {
        throw "No authentication context. Authenticate first by running 'Connect-IntuneDataWarehouse'"
    }

    $headers = @{
                'Content-Type'='application/json'
                'Authorization'="Bearer " + $global:intuneWarehouseAuthResult.AccessToken
                'ExpiresOn'= $global:intuneWarehouseAuthResult.ExpiresOn
                };
    $Collections = Invoke-WebRequest -Uri $global:intuneWarehouseURL -Method Get -Headers $headers
    $AllCollections = ($Collections.content | ConvertFrom-Json).value.name | sort
    return $AllCollections
}

<#
.SYNOPSIS
    This function is used to get a collection of data from the Intune Data Warehouse
.DESCRIPTION
    The function connects to the Data Warehouse URL and returns a collection of data
.EXAMPLE
    Get-IntuneDataWarehouseCollection -CollectionName devices
    Returns all devices from the Data Warehouse
.NOTES
    NAME: Get-IntuneDataWarehouseCollection
#>
function Get-IntuneDataWarehouseCollection {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [String]   $CollectionName,
        [Int]      $Skip=0,
        [Int]      $Top=10000,
        [String[]] $PropertyList,
        [Switch]   $All
    )

    function Invoke-DataWarehouseRequest {
        param
        (
            [Parameter(Mandatory=$True)]
            $Url
        )

        $clientRequestId = [Guid]::NewGuid()
        $headers = @{
            'Content-Type'='application/json'
            'Authorization'="Bearer " + $global:intuneWarehouseAuthResult.AccessToken
            'ExpiresOn'= $global:intuneWarehouseAuthResult.ExpiresOn
            'client-request-id'=$clientRequestId
        }

        Write-Verbose "Request URL = $URL"
        Write-Verbose "Client request ID = $clientRequestId"

        $Response = Invoke-WebRequest -Uri $URL -Method Get -Headers $headers
        return $Response.content | ConvertFrom-Json
    }

    if (!$global:intuneWarehouseAuthResult) {
        throw "No authentication context. Authenticate first by running 'Connect-IntuneDataWarehouse'"
    }

    # Verify that the request collection exists in the warehouse
    $validCollectionNames = Get-IntuneDataWarehouseCollectionNames

    if (!($validCollectionNames).contains("$CollectionName")) {
        throw "Collection Name $CollectionName doesn't exist."
    }
    else {
        $URL = $global:intuneWarehouseURL.Insert($global:intuneWarehouseURL.IndexOf("?"), "/$collectionName")
        if ($All -eq $False) {
            $URL = "$URL&`$skip=$Skip&`$top=$Top"
        }
        if ($PropertyList.Count -gt 0) {
            $URL = "$URL&`$select=$($PropertyList -join ',')"
        }

        do {
            $response = Invoke-DataWarehouseRequest -Url $URL
            Write-Output $response.value
            $URL = $response.'@odata.nextLink'
        }
        while ($URL)
    }
}

<#
.SYNOPSIS
    Tests whether or not the current authentication context is valid.
.DESCRIPTION
    The function tests whether or not the current authentication context is valid
    Optionally pass a user to scope it down further. If this returns $False, then
    Connect-IntuneDataWarehouse should be run.
.EXAMPLE
    Test-IntuneDataWarehouseAuthentication
    Test-IntuneDataWarehouseAuthentication -User nick@example.com
.NOTES
    NAME: Test-IntuneDataWarehouseAuthentication
#>
function Test-IntuneDataWarehouseAuthentication {
    [cmdletbinding()]
    param
    (
        $User
    )

    $isAuthValid = $False

    if ($global:intuneWarehouseAuthResult) {
        # Setting DateTime to Universal time to work in all timezones
        $DateTime = (Get-Date).ToUniversalTime()

        # If the authToken exists checking when it expires
        $TokenExpires = ($global:intuneWarehouseAuthResult.ExpiresOn.datetime - $DateTime).Minutes

        if ($TokenExpires -gt 0 -and (!$User -or $User -eq $global:intuneWarehouseAuthUser)) {
            $isAuthValid = $True
        }
    }
    return $isAuthValid
}

