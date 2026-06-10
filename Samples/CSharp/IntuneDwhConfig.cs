// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT license. See LICENSE in the repository root.

namespace IntuneDataWarehouseSamples;

/// <summary>
/// Shared configuration constants for the Intune Data Warehouse samples.
/// </summary>
internal static class IntuneDwhConfig
{
    /// <summary>
    /// The Intune Data Warehouse first-party AAD application ID. AAD issues
    /// tokens for this audience (the <c>aud</c> claim in the resulting JWT
    /// equals this GUID). All token-acquisition call sites in this project
    /// use <c>"{IntuneDwhAppId}/.default"</c> as the MSAL scope.
    /// </summary>
    public const string IntuneDwhAppId = "c161e42e-d4df-4a3d-9b42-e7a3c31f59d4";

    /// <summary>
    /// MSAL scope used when acquiring access tokens for the IDW endpoint.
    /// </summary>
    public static readonly string[] Scopes = { $"{IntuneDwhAppId}/.default" };

    /// <summary>
    /// AAD authority host. Override to a sovereign cloud host as needed.
    /// </summary>
    public const string AuthorityHost = "https://login.microsoftonline.com";

    // Environment variable names. Setting these before invoking the sample
    // avoids editing source for tenant-specific values.
    public const string EnvAppId        = "INTUNE_DWH_APP_ID";
    public const string EnvTenantId     = "INTUNE_DWH_TENANT_ID";
    public const string EnvWarehouseUrl = "INTUNE_DWH_URL";
    public const string EnvClientSecret = "INTUNE_DWH_CLIENT_SECRET";

    /// <summary>
    /// Reads a required environment variable and throws a friendly error
    /// (rather than letting the value default to a placeholder that AAD or
    /// the IDW endpoint later rejects with a cryptic message).
    /// </summary>
    public static string RequireEnv(string name)
    {
        var value = Environment.GetEnvironmentVariable(name);
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException(
                $"Required environment variable '{name}' is not set. " +
                $"Set it (PowerShell: $env:{name}='<value>'; bash: export {name}=<value>) and re-run.");
        }
        return value;
    }
}

