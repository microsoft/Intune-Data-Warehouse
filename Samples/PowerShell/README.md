# Access the Intune Data Warehouse with PowerShell

Provided are some example PowerShell scripts and a module to help you get started with accessing the Intune Data Warehouse with PowerShell.

## PowerShell Module

The IntuneDataWarehouseCmdlets.psm1 PowerShell module exposes a few functions to provide basic access to the Intune Data Warehouse API. For an example of how to use the module, take a look at **ExampleCmdletsUsage.ps1**.

The module exposes 3 basic cmdlets which should cover all of the interaction with the API that are needed.

### Connect-IntuneDataWarehouse
This cmdlet establishes a connection to the Intune Data Warehouse by authenticating and caching information that will be needed in subsequent requests. These include:

| Parameter     | Description           | Example  |
| ------------- |-------------| -----|
| User               | The UPN of the user for authentication | nick@example.com |
| ApplicationId      | The application Id of an application in AzureAD with authorization to get data warehouse information from the Microsoft Intune API | 4184c61a-e324-4f51-83d7-022b6a82b991 |
| DataWarehouseURL   | The Intune Data Warehouse URL for your tenant. This can be found in the Azure portal. | https://fef.msua04.manage.microsoft.com/ReportingService/DataWarehouseFEService?api-version=beta |
| CredentialsFile    | A path to a file that contains your user's credentials as a secure string. See below for more information. Optional, default behavior is interactive auth. | c:\credentials\creds.txt |
| RedirectUri        | A valid redirect URI for the application setup in Azure AD represented by the ApplicationId parameter. Optional, default is "urn:ietf:wg:oauth:2.0:oob"      | https://localhost |

### Test-IntuneDataWarehouseAuthentication
This cmdlet determines whether or not the current authentication context is valid. This can be scoped to any user or a particular user. The return is $True if it is valid, $False if it is not. If $False is returned, Connect-IntuneDataWarehouse will need to be run before accessing any collections.

| Parameter     | Description           | Example  |
| ------------- |-------------| -----|
| User | Optional, checks if the provided user is logged in | nick@example.com |

### Get-IntuneDataWarehouseCollectionNames

This cmdlet takes no parameters. It will simply call the Intune Data Warehouse API and return back the list of available collections.

### Get-IntuneDataWarehouseCollection

This cmdlet queries the Intune Data Warehouse API and gets data for a single collection. To page data from the API, utilize the Skip and Top parameters.

| Parameter     | Description           | Example  |
| ------------- |-------------| -----|
| CollectionName | The name of the collection to query | users |
| Skip           | The number of entities to skip. Optional, default is 0 | 15 |
| Top            | The number of entities to get from the API. Optional, default is 1000 | 100 |
| All            | This is a switch parameter. If used, all of the collection data will be downloaded and written to pipeline in batches. When this switch is used, any Skip and Top parameters provided will be ignored. | N/A

## Authenticating with a Credentials File

Instead of using interactive authentication for each session, the Connect-IntuneDataWarehouse cmdlet also accepts a credential file to authenticate the user.

To create a credential file, simply run this command:

```
Read-Host -Prompt "Enter your tenant password" -AsSecureString | ConvertFrom-SecureString | Out-File "c:\temp\IntuneExport\credentials.txt"
```

When calling Connect-IntuneDataWarehouse, pass "c:\temp\IntuneExport\credentials.txt" as the value to the -CredentialsFile parameter.

**Note:**

The password file that is generated is only valid for use in the authentication PowerShell script on the computer that was used to generate the file. It cannot be transferred or used on any other computer.

As with any security-related script, ensure that you review the code and the code behavior with your company's security department or security representative to ensure it complies with your security policy.

## Downloading Data to a CSV

To download an entire collection to a CSV file, use ```Get-IntuneDataWarehouseCollection``` with the ```-All``` switch. This will write data to the pipeline in batches. You can then pipe each batch into a CSV conversion function and write it to a file. The reason for batching is to keep the memory usage low, since some of these collections can contain tens of millions of entities.

Here is a simple of downloading the ```users``` collection to a CSV file:
```
Get-IntuneDataWarehouseCollection -CollectionName users -All -Verbose | ConvertTo-Csv -NoTypeInformation > users.csv
```
* Note that ```-Verbose``` is not needed, but will write debug output to the PowerShell window. This can help you see the progress being made.

Here is a more general example of downloading all of your Data Warehouse collections to CSV files, one per collection:

```
Get-IntuneDataWarehouseCollectionNames | ForEach-Object {
     Get-IntuneDataWarehouseCollection -CollectionName $_ -All -Verbose  | ConvertTo-Csv -NoTypeInformation > "$_.csv"
}
```
