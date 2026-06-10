// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT license. See LICENSE in the repository root.

namespace IntuneDataWarehouseSamples;

using System.Net.Http.Headers;
using Microsoft.Identity.Client;

/// <summary>
/// App-only (daemon / unattended) authentication against the Intune Data
/// Warehouse using the AAD client-credentials flow via MSAL.NET.
///
/// Configuration is read from environment variables. Set all four before
/// running:
///   INTUNE_DWH_APP_ID        - Client ID of your AAD app registration.
///   INTUNE_DWH_TENANT_ID     - Tenant ID (GUID) or verified domain.
///   INTUNE_DWH_URL           - The Intune Data Warehouse URL from the
///                              Azure portal.
///   INTUNE_DWH_CLIENT_SECRET - Client secret of the AAD app.
///
/// PRODUCTION GUIDANCE: do not embed secrets in source or long-lived
/// environment variables. Use Azure Key Vault, a Managed Identity, or
/// workload-identity federation instead.
/// </summary>
public static class AppAuthenticationSample
{
    public static async Task RunAsync()
    {
        var applicationId = IntuneDwhConfig.RequireEnv(IntuneDwhConfig.EnvAppId);
        var tenantId      = IntuneDwhConfig.RequireEnv(IntuneDwhConfig.EnvTenantId);
        var warehouseUrl  = IntuneDwhConfig.RequireEnv(IntuneDwhConfig.EnvWarehouseUrl);
        var clientSecret  = IntuneDwhConfig.RequireEnv(IntuneDwhConfig.EnvClientSecret);
        const string collectionName = "dates";

        var app = ConfidentialClientApplicationBuilder
            .Create(applicationId)
            .WithClientSecret(clientSecret)
            .WithAuthority($"{IntuneDwhConfig.AuthorityHost}/{tenantId}")
            .Build();

        // Scope = "{IntuneDwhAppId}/.default" causes AAD to issue a token
        // whose aud claim is the IDW first-party app GUID — matching what
        // the IDW gateway expects.
        AuthenticationResult authResult = await app
            .AcquireTokenForClient(IntuneDwhConfig.Scopes)
            .ExecuteAsync();

        using var httpClient = new HttpClient();
        httpClient.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", authResult.AccessToken);

        var uriBuilder = new UriBuilder(warehouseUrl);
        uriBuilder.Path += "/" + collectionName;

        HttpResponseMessage response = await httpClient.GetAsync(uriBuilder.Uri);
        Console.WriteLine($"HTTP {(int)response.StatusCode} {response.ReasonPhrase}");
        Console.WriteLine(await response.Content.ReadAsStringAsync());
    }
}

