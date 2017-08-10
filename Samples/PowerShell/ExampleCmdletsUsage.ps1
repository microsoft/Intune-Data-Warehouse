<#
 
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.

#>

$ModulePath = "$PSScriptRoot\IntuneDataWarehouseCmdlets.psm1"

if (Test-Path "$ModulePath") {
    Import-Module "$ModulePath"
}
else {
    Write-Host
    Write-Host "Module Path '$ModulePath' doesn't exist..." -ForegroundColor Red
    Write-Host
    break
}

if (!(Test-IntuneDataWarehouseAuthentication)) {

    Write-Host "To use the Intune Data Warehouse, you must first provide a few details..."
    $User = Read-Host "Enter the UPN of the user to authenticate as"
    $ApplicationId = Read-Host "Enter the application ID of an AzureAD app that has access to get data warehouse information from the Microsoft Intune API"
    $WarehouseURL = Read-Host "Enter the Intune Data Warehouse URL provided in the Azure portal"

    Write-Host
    Write-Host "Authenticating..."
    Connect-IntuneDataWarehouse -User $User -ApplicationId $ApplicationId -DataWarehouseURL $WarehouseURL
}

Write-Host
Write-Host "================================================="
Write-Host "Listing all of the available collections..."
Write-Host "================================================="
Write-Host

Get-IntuneDataWarehouseCollectionNames

Write-Host
Write-Host "This PowerShell script will get the first 1000 items of a collection."
Write-Host "To get more, page data using the -Skip and -Top parameters of the Get-IntuneDataWarehouseCollection cmdlet."
Write-Host
$CollectionName = Read-Host "Enter the collection you would like to get data from"

Get-IntuneDataWarehouseCollection -CollectionName $CollectionName -Skip 0 -Top 1000