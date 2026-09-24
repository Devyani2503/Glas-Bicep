<#
.SYNOPSIS
    Deploy the App Service Plan, four Web Apps, and Key Vault with Bicep.

.EXAMPLE
    .\deploy.ps1 -ResourceGroup rg-costdetective -Location eastus
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [string]$Location = 'eastus',

    [string]$NamePrefix = 'costdet',

    [ValidateSet('dev', 'test', 'prod')]
    [string]$Environment = 'dev',

    [string]$ParameterFile = (Join-Path $PSScriptRoot 'parameters.dev.bicepparam')
)

$ErrorActionPreference = 'Stop'
$templateFile = Join-Path $PSScriptRoot 'main.bicep'

Write-Host "Creating resource group $ResourceGroup in $Location..."
az group create --name $ResourceGroup --location $Location --output none

$deployerObjectId = az ad signed-in-user show --query id --output tsv 2>$null
if (-not $deployerObjectId) {
    Write-Warning 'Could not resolve the signed-in user object ID. You can still deploy; add Key Vault secrets later with a user who has access.'
    $deployerObjectId = ''
}

Write-Host "Deploying Bicep template..."
az deployment group create `
    --resource-group $ResourceGroup `
    --template-file $templateFile `
    --parameters $ParameterFile `
    --parameters namePrefix=$NamePrefix environmentName=$Environment location=$Location deployerObjectId=$deployerObjectId `
    --query "properties.outputs" `
    --output json
