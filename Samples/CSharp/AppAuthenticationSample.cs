namespace IntuneDataWarehouseSamples
{
    using System;
    using System.Net.Http;
    using System.Net.Http.Headers;
    using System.Security;
    using Microsoft.IdentityModel.Clients.ActiveDirectory;

    public class AppAuthenticationSample
    {
        public static void Run()
        {
            /**
             * TODO: Replace the below values with your own.
             * 
             * Documentation for setting up an AAD app:
             * https://docs.microsoft.com/en-us/intune/data-warehouse-app-only-auth
             *
             * applicationId - The application ID of the web app that was created in AAD.
             *
             * applicationSecret - The application secret of the web app that was created in AAD.
             *
             * warehouseUrl   - The data warehouse URL for your tenant. This can be found in 
             *                  the Azure portal.
             *
             * tenantDomain - The domain of your AAD tenant. For example, for user john@contoso.com, the
             *                 tenant domain would be "contoso.com"
             * 
             * collectionName - The name of the warehouse entity collection you would like to 
             *                  access.
             */
            var applicationId = "8d699e29-3b54-4c6a-91cc-e537b4680fed";
            var applicationSecret = "secret_for(8d699e29-3b54-4c6a-91cc-e537b4680fed)";
            var tenantDomain = "yourcompany.com";
            var warehouseUrl =
                "https://fef.msua01.manage.microsoft.com/ReportingService/DataWarehouseFEService?api-version=beta";
            var collectionName = "dates";

            var adalContext =
                new AuthenticationContext("https://login.windows.net/" + tenantDomain + "/oauth2/token");
            AuthenticationResult authResult = adalContext.AcquireTokenAsync(
                resource: "https://api.manage.microsoft.com/",
                clientCredential: new ClientCredential(
                    applicationId, 
                    new SecureClientSecret(ConvertToSecureStr(applicationSecret)))).Result;

            var httpClient = new HttpClient();
            httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
                "Bearer",
                authResult.AccessToken);

            var uriBuilder = new UriBuilder(warehouseUrl);
            uriBuilder.Path += "/" + collectionName;

            HttpResponseMessage response = httpClient.GetAsync(uriBuilder.Uri).Result;

            Console.Write(response.Content.ReadAsStringAsync().Result);
            Console.ReadKey();
        }

        private static SecureString ConvertToSecureStr(string str)
        {
            if (str == null)
                throw new ArgumentNullException("String must not be null.");

            var secure = new SecureString();

            foreach (char c in str)
                secure.AppendChar(c);

            secure.MakeReadOnly();
            return secure;
        }
    }
}
