# Access the Intune Data Warehouse with PowerShell

Sample PowerShell module and example script for querying the Intune Data
Warehouse OData endpoint.

> **2026 modernization** — this module now uses **MSAL.PS** for token
> acquisition. The deprecated ADAL library and the Resource Owner Password
> Credentials (ROPC) flow have been **removed**. See the
> [Why ROPC was removed](#why-ropc-was-removed) section below for the
> migration path if you were using `-CredentialsFile`.

## Prerequisites

- PowerShell 5.1 or PowerShell 7+
- The [`MSAL.PS`](https://www.powershellgallery.com/packages/MSAL.PS) module
  from the PowerShell Gallery:
  ```powershell
  Install-Module -Name MSAL.PS -Scope CurrentUser
  ```
- An AAD app registration in your tenant with permission to read the Intune
  Data Warehouse API. For interactive sign-in the app must be a **Public
  client** with `http://localhost` registered as a redirect URI.

## Quick start

```powershell
Import-Module .\IntuneDataWarehouseCmdlets.psm1

Connect-IntuneDataWarehouse `
    -ApplicationId 'ee6e1234-5655-4321-83f4-ef4fd36ce1c2' `
    -User          'user@contoso.com' `
    -DataWarehouseURL 'https://fef.msua01.manage.microsoft.com/ReportingService/DataWarehouseFEService?api-version=v1.0'

Get-IntuneDataWarehouseCollectionNames
Get-IntuneDataWarehouseCollection -CollectionName devices -Top 100
```

To sign in from a terminal where a browser is not available, add
`-DeviceCode`:

```powershell
Connect-IntuneDataWarehouse -ApplicationId '…' -User '…' -DataWarehouseURL '…' -DeviceCode
```

For an end-to-end walkthrough, see **`ExampleCmdletsUsage.ps1`**.

## Cmdlets

### Connect-IntuneDataWarehouse

Acquires an MSAL access token and caches it for use by subsequent cmdlets.

| Parameter | Required | Description |
| --- | --- | --- |
| `ApplicationId` | Yes | Client ID of your AAD app registration. |
| `User` | Yes | UPN to authenticate as. Used as MSAL `-LoginHint` and (when `-TenantId` is omitted) as the source of the tenant routing domain. |
| `DataWarehouseURL` | Yes | The Intune Data Warehouse URL from the Azure portal. |
| `TenantId` | No | AAD tenant ID or verified domain. Override when the user's UPN domain does not match the tenant (B2B, guest, vanity domains). |
| `DeviceCode` | No | Switch. Use device-code flow instead of interactive browser sign-in. |

### Test-IntuneDataWarehouseAuthentication

Returns `$true` when a non-expired token is cached, optionally scoped to a
specific UPN. Returns `$false` otherwise — in which case
`Connect-IntuneDataWarehouse` should be re-run.

### Get-IntuneDataWarehouseCollectionNames

Returns the sorted list of available collection names.

### Get-IntuneDataWarehouseCollection

Queries a single collection.

| Parameter | Description |
| --- | --- |
| `CollectionName` | Required. The collection to query. |
| `Skip` | Optional. Number of entities to skip. Default 0. |
| `Top` | Optional. Maximum number of entities to return. Default 10000. |
| `PropertyList` | Optional. Project specific columns. |
| `All` | Switch. Follow `@odata.nextLink` and emit all pages. When set, `Skip`/`Top` are ignored. |

## Why ROPC was removed

Previous versions of this module accepted a `-CredentialsFile` parameter that
loaded an encrypted password and submitted it to AAD using the **Resource
Owner Password Credentials (ROPC)** grant. ROPC has been removed because:

- It is incompatible with **multi-factor authentication**.
- It is incompatible with **Conditional Access** (device compliance, named
  locations, sign-in risk).
- It cannot authenticate **passwordless / FIDO2 / Windows Hello** users.
- It requires customer code to handle plaintext user passwords, which is an
  anti-pattern.

**If you were using `-CredentialsFile`**, migrate to one of the following:

- **App-only auth (recommended for unattended scripts)** — see
  `Samples/CSharp/AppAuthenticationSample.cs` for the C# equivalent, or
  call MSAL.PS yourself:
  ```powershell
  $token = Get-MsalToken -ClientId $appId -TenantId $tenantId `
      -ClientSecret (ConvertTo-SecureString $secret -AsPlainText -Force) `
      -Scopes "<INTUNE-DWH-APP-ID>/.default"
  ```
  In production, source the secret from Azure Key Vault or use a Managed
  Identity instead of an env-var / file.
- **Managed Identity** — if the script runs in Azure-hosted compute.
- **Interactive or device-code** — if the workflow is genuinely
  user-driven, use the default flow or `-DeviceCode`.

## Downloading data to CSV

Same pattern as before — pipe `Get-IntuneDataWarehouseCollection -All` into
`ConvertTo-Csv`:

```powershell
Get-IntuneDataWarehouseCollection -CollectionName users -All -Verbose |
    ConvertTo-Csv -NoTypeInformation > users.csv
```

To dump every collection to its own CSV:

```powershell
Get-IntuneDataWarehouseCollectionNames | ForEach-Object {
    Get-IntuneDataWarehouseCollection -CollectionName $_ -All -Verbose |
        ConvertTo-Csv -NoTypeInformation > "$_.csv"
}
```

As with any security-related script, review the code with your security
team before deploying.
