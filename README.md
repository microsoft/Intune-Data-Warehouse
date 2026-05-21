# Intune Data Warehouse — Authentication Samples

> **2026 modernization** — these samples now use **MSAL** for AAD token
> acquisition. The deprecated **ADAL** library and the **Resource Owner
> Password Credentials (ROPC)** flow have been removed. The Power BI
> template files that previously lived in this repo have also been
> removed; install the Power BI apps from
> [Microsoft AppSource](https://appsource.microsoft.com/en-us) instead.

This repo demonstrates how to authenticate to the **Intune Data Warehouse**
OData endpoint from C# and PowerShell.

## What's here

| Path | What it shows |
| --- | --- |
| `Samples/CSharp/` | .NET 8 console sample using **MSAL.NET** (`Microsoft.Identity.Client`). Three flows: client credentials (app-only), interactive browser, device code. |
| `Samples/PowerShell/` | PowerShell module using **MSAL.PS** for the same three concerns (user-side interactive and device-code; an inline example shows app-only). |

## Supported authentication flows

| Flow | Use when | C# entry point | PowerShell entry point |
| --- | --- | --- | --- |
| **Client credentials** (app-only) | Unattended / daemon / cron / Azure-hosted scripts. **Recommended replacement for ROPC.** | `AppAuthenticationSample.RunAsync()` | `Get-MsalToken -ClientSecret …` (see PS README) |
| **Interactive browser** | Desktop / developer workstation with a browser. | `UserAuthenticationSample.RunInteractiveAsync()` | `Connect-IntuneDataWarehouse` (default) |
| **Device code** | Terminal / SSH / headless host. | `UserAuthenticationSample.RunDeviceCodeAsync()` | `Connect-IntuneDataWarehouse -DeviceCode` |

ROPC (plaintext user-password flow) is **not** supported. See
[`Samples/PowerShell/README.md`](Samples/PowerShell/README.md#why-ropc-was-removed)
for migration guidance.

## Token audience

All samples acquire tokens with the MSAL scope
`<INTUNE-DWH-APP-ID>/.default`, where `<INTUNE-DWH-APP-ID>` is the Intune
Data Warehouse first-party AAD application ID. The resulting access token's
`aud` claim is this GUID — which is what the Intune Data Warehouse gateway
expects. (Older samples in this repo emitted
`https://api.manage.microsoft.com/` as the resource, which is no longer
recommended.) The constant is populated in
`Samples/CSharp/IntuneDwhConfig.cs` and
`Samples/PowerShell/IntuneDataWarehouseCmdlets.psm1`; you do not need to
edit it.

## Quick start (PowerShell)

```powershell
Install-Module -Name MSAL.PS -Scope CurrentUser

Import-Module .\Samples\PowerShell\IntuneDataWarehouseCmdlets.psm1

Connect-IntuneDataWarehouse `
    -ApplicationId    '<your-app-id>' `
    -User             'user@contoso.com' `
    -DataWarehouseURL 'https://fef.msua01.manage.microsoft.com/ReportingService/DataWarehouseFEService?api-version=v1.0'

Get-IntuneDataWarehouseCollectionNames
Get-IntuneDataWarehouseCollection -CollectionName devices -Top 10
```

## Quick start (C#)

The C# sample reads configuration from environment variables — no source
edits required.

```powershell
# Required for all modes:
$env:INTUNE_DWH_APP_ID    = '<your-app-id>'
$env:INTUNE_DWH_TENANT_ID = '<your-tenant-id-or-domain>'
$env:INTUNE_DWH_URL       = 'https://fef.msua01.manage.microsoft.com/ReportingService/DataWarehouseFEService?api-version=v1.0'

cd Samples/CSharp

# App-only (also requires the client secret):
$env:INTUNE_DWH_CLIENT_SECRET = '<your-app-secret>'
dotnet run -- --mode app

# Interactive browser:
dotnet run -- --mode interactive

# Device code:
dotnet run -- --mode devicecode
```

> **Production guidance:** never embed client secrets in source or
> long-lived environment variables. Use Azure Key Vault, a Managed
> Identity, or workload-identity federation.

## Further reading

- [Microsoft Authentication Library (MSAL) overview](https://learn.microsoft.com/azure/active-directory/develop/msal-overview)
- [MSAL.NET reference](https://learn.microsoft.com/dotnet/api/microsoft.identity.client)
- [Intune Data Warehouse documentation](https://learn.microsoft.com/mem/intune/developer/reports-nav-intune-data-warehouse)

---

# Contributing

This project welcomes contributions and suggestions. Most contributions
require you to agree to a Contributor License Agreement (CLA) declaring
that you have the right to, and actually do, grant us the rights to use
your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine
whether you need to provide a CLA and decorate the PR appropriately (e.g.,
label, comment). Simply follow the instructions provided by the bot. You
will only need to do this once across all repos using our CLA.

This project has adopted the
[Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the
[Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/)
or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with
any additional questions or comments.
