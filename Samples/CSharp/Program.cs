// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT license. See LICENSE in the repository root.

namespace IntuneDataWarehouseSamples;

internal static class Program
{
    private const string Usage =
        "Usage: IntuneDataWarehouseSamples --mode <app|interactive|devicecode>";

    public static async Task<int> Main(string[] args)
    {
        var mode = ParseMode(args);
        if (mode is null)
        {
            Console.Error.WriteLine(Usage);
            return 1;
        }

        try
        {
            switch (mode)
            {
                case "app":
                    await AppAuthenticationSample.RunAsync();
                    break;
                case "interactive":
                    await UserAuthenticationSample.RunInteractiveAsync();
                    break;
                case "devicecode":
                    await UserAuthenticationSample.RunDeviceCodeAsync();
                    break;
                default:
                    Console.Error.WriteLine(Usage);
                    return 1;
            }
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"ERROR: {ex.Message}");
            return 2;
        }
    }

    private static string? ParseMode(string[] args)
    {
        for (int i = 0; i < args.Length - 1; i++)
        {
            if (string.Equals(args[i], "--mode", StringComparison.OrdinalIgnoreCase))
            {
                return args[i + 1].ToLowerInvariant();
            }
        }
        return null;
    }
}
