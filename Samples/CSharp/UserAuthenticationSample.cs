// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT license. See LICENSE in the repository root.

namespace IntuneDataWarehouseSamples;

using System.Net.Http.Headers;
using Microsoft.Identity.Client;

/// <summary>
/// User (delegated) authentication against the Intune Data Warehouse using
/// MSAL.NET public-client flows.
///
/// Two flows are demonstrated:
///   - Interactive (system-browser, suitable for desktop)
///   - Device code (terminal-friendly, suitable for headless / SSH)
///
/// Both flows are compatible with MFA, Conditional Access, and passwordless
/// authentication. NEITHER flow accepts a password as input — by design.
///
/// Configuration is read from environment variables. Set all three before
/// running:
///   INTUNE_DWH_APP_ID    - Client ID of your AAD app registration. The
///                          registration must be configured as a public
///                          client ("Allow public client flows = Yes") with
///                          a redirect URI of http://localhost when using
///                          the interactive flow.
///   INTUNE_DWH_TENANT_ID - Tenant ID (GUID) or verified domain.
///   INTUNE_DWH_URL       - The Intune Data Warehouse URL from the Azure
///                          portal.
///
/// IMPORTANT: this sample replaces a deprecated sample that used ADAL's
/// Resource Owner Password Credentials (ROPC) flow. ROPC is unsafe to copy
/// into production: it is incompatible with MFA and Conditional Access and
/// requires customer code to handle plaintext user passwords. Use one of the
/// flows below instead, or — for unattended scenarios — use
/// <see cref="AppAuthenticationSample"/> (client credentials) or a Managed
/// Identity if running in Azure-hosted compute.
/// </summary>
public static class UserAuthenticationSample
{
    public static async Task RunInteractiveAsync()
    {
        var applicationId = IntuneDwhConfig.RequireEnv(IntuneDwhConfig.EnvAppId);
        var tenantId      = IntuneDwhConfig.RequireEnv(IntuneDwhConfig.EnvTenantId);
        var warehouseUrl  = IntuneDwhConfig.RequireEnv(IntuneDwhConfig.EnvWarehouseUrl);

        var app = BuildPublicClient(applicationId, tenantId);
        AuthenticationResult authResult = await AcquireSilentOrInteractiveAsync(app);
        await CallWarehouseAsync(warehouseUrl, authResult.AccessToken);
    }

    public static async Task RunDeviceCodeAsync()
    {
        var applicationId = IntuneDwhConfig.RequireEnv(IntuneDwhConfig.EnvAppId);
        var tenantId      = IntuneDwhConfig.RequireEnv(IntuneDwhConfig.EnvTenantId);
        var warehouseUrl  = IntuneDwhConfig.RequireEnv(IntuneDwhConfig.EnvWarehouseUrl);

        var app = BuildPublicClient(applicationId, tenantId);
        AuthenticationResult authResult = await app
            .AcquireTokenWithDeviceCode(
                IntuneDwhConfig.Scopes,
                deviceCodeResult =>
                {
                    Console.WriteLine(deviceCodeResult.Message);
                    return Task.CompletedTask;
                })
            .ExecuteAsync();

        await CallWarehouseAsync(warehouseUrl, authResult.AccessToken);
    }

    private static IPublicClientApplication BuildPublicClient(string applicationId, string tenantId)
    {
        return PublicClientApplicationBuilder
            .Create(applicationId)
            .WithAuthority($"{IntuneDwhConfig.AuthorityHost}/{tenantId}")
            // WithDefaultRedirectUri picks http://localhost on .NET 8 (system
            // browser). Register the same redirect URI in the AAD app.
            .WithDefaultRedirectUri()
            .Build();
    }

    private static async Task<AuthenticationResult> AcquireSilentOrInteractiveAsync(IPublicClientApplication app)
    {
        // In-process MSAL cache means a second call within the same process
        // can refresh silently. Across process restarts the user is
        // re-prompted — a serialized cache is intentionally not configured
        // here to keep the sample minimal.
        var accounts = await app.GetAccountsAsync();
        var account = accounts.FirstOrDefault();
        try
        {
            if (account is not null)
            {
                return await app.AcquireTokenSilent(IntuneDwhConfig.Scopes, account).ExecuteAsync();
            }
        }
        catch (MsalUiRequiredException)
        {
            // Fall through to interactive.
        }

        return await app.AcquireTokenInteractive(IntuneDwhConfig.Scopes).ExecuteAsync();
    }

    private static async Task CallWarehouseAsync(string warehouseUrl, string accessToken)
    {
        const string collectionName = "dates";

        using var httpClient = new HttpClient();
        httpClient.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", accessToken);

        var uriBuilder = new UriBuilder(warehouseUrl);
        uriBuilder.Path += "/" + collectionName;

        HttpResponseMessage response = await httpClient.GetAsync(uriBuilder.Uri);
        Console.WriteLine($"HTTP {(int)response.StatusCode} {response.ReasonPhrase}");
        Console.WriteLine(await response.Content.ReadAsStringAsync());
    }
}

