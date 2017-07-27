# IntuneDataWarehouseSample.ps1
#
# This is a simple script to demonstrate how to get data from the Intune Data Warehouse
# using PowerShell.
#
# Prerequisites
#-----------------------------------------
# Install the Active Directory Authentication Library (ADAL) through NuGet here:
# https://www.nuget.org/packages/Microsoft.IdentityModel.Clients.ActiveDirectory/
#
# Replace the below values with your own.
#----------------------------------------
# adalPath      - The path to the Microsoft.IdentityModel.Clients.ActiveDirectory.dll 
#                 that was installed as a part of the prerequisite step.
#
# emailAddress  - The email address of the user that you will authenticate as.
#
# password      - The password for the above email address.
#                 This is inline only for simplicity in this sample. We do not 
#                 recommend storing passwords in plaintext.
#
# applicationId - The application ID of the native app that was created in AAD.
#                 For more details, refer to these docs: TODO: ## ADD DOC LINK ##
#
# warehouseUrl   - The data warehouse URL for your tenant. This can be found in 
#                  the Azure portal. TODO: ## ADD DOC LINK ##
# 
# collectionName - The name of the warehouse entity collection you would like to 
#                  access.

$adalPath       = "H:\publicdw\Intune-Data-Warehouse\Samples\CSharp\packages\Microsoft.IdentityModel.Clients.ActiveDirectory.3.14.2\lib\net45\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
$emailAddress   = "intuneadmin@yourcompany.com"
$password       = "password_of(intuneadmin@yourcompany.com)"
$applicationId  = "8d699e29-3b54-4c6a-91cc-e537b4680fed"
$warehouseUrl   = "https://fef.msua01.manage.microsoft.com/ReportingService/DataWarehouseFEService?api-version=beta"
$collectionName = "dates"

# Get an access token from Azure AD to access the Intune Data Warehouse
Add-Type -Path $adalPath
$authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList "https://login.windows.net/common/oauth2/token"
$userCredential = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserPasswordCredential" -ArgumentList $emailAddress,$password
$authResult = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContextIntegratedAuthExtensions]::AcquireTokenAsync($authContext, "https://api.manage.microsoft.com/", $applicationId, $userCredential).GetAwaiter().GetResult()
$userToken = $authResult.AccessToken

# Make a web request to get data
$warehouseUrl = $warehouseUrl.Insert($warehouseUrl.IndexOf("?"), "/$collectionName")
$response = Invoke-WebRequest -Uri $warehouseUrl -Method Get -Headers @{"Authorization"="Bearer $userToken"}

$response.Content