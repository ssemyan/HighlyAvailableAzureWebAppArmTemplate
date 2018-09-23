<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .PARAMETER resourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER templateFilePath
    Optional, path to the template file. 

 .PARAMETER parametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. 
#>

param(
 [Parameter(Mandatory=$True)]
 [string]
 $resourceGroupName,

 [string]
 $templateFilePath = "template.json",

 [string]
 $parametersFilePath = "parameters.json"
)

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

# sign in and select subscription
#Write-Host "Logging in...";
#Login-AzureRmAccount -SubscriptionID $subscriptionId;

# load the parameters so we can use them in the script
$params = ConvertFrom-Json -InputObject (Gc $parametersFilePath -Raw)

# Check if the RG exists for the deployment
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
	$resourceGroupLocation = $params.parameters.deploy_location.value;
	Write-Host "Creating resource group '$resourceGroupName' in location $resourceGroupLocation";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation -Verbose 
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}

# Test
Write-Host "Testing deployment...";
$testResult = Test-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath -ErrorAction Stop;
if ($testResult.Count -gt 0)
{
	write-host ($testResult | ConvertTo-Json -Depth 5 | Out-String);
	write-output "Errors in template - Aborting";
	exit;
}

# Start the deploymentappServiceName
Write-Host "Starting deployment...";
$result = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath -Verbose;
Write-Host ($result | Format-List | Out-String)

# Check if the RG for Traffic Manager exists
$tmResourceGroupName = $params.parameters.trafficManagerResourceGroup.value;
$tmResourceGroupLocation = $params.parameters.trafficManagerResourceGroupLocation.value;
$resourceGroupTm = Get-AzureRmResourceGroup -Name $tmResourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroupTm)
{
    Write-Host "Creating resource group for Traffic Manager '$tmResourceGroupName' in location $tmResourceGroupLocation";
    New-AzureRmResourceGroup -Name $tmResourceGroupName -Location $tmResourceGroupLocation -Verbose 
}
else{
    Write-Host "Using existing resource group '$tmResourceGroupName' for Traffic Manager";
}

# Create Traffic Manager if it does not exist
$trafficManagerName = $params.parameters.trafficManagerName.value;
$trafficManager = Get-AzureRmTrafficManagerProfile -Name $trafficManagerName -ResourceGroupName $tmResourceGroupName -ErrorAction SilentlyContinue
if(!$trafficManager)
{
    Write-Host "Creating Traffic Manager '$trafficManagerName'";
	$trafficManager = New-AzureRmTrafficManagerProfile -Name $trafficManagerName -ResourceGroupName $tmResourceGroupName -TrafficRoutingMethod Performance -RelativeDnsName $trafficManagerName -Ttl 30 -MonitorProtocol HTTP -MonitorPort 80 -MonitorPath "/"
}
else{
    Write-Host "Using existing Traffic Manager '$trafficManagerName'";
}

# Add an endpoint to the Traffic Manager if it does not already exist
$appGatewayPublicIpName = $result.Outputs.appGatewayPublicIpName.Value;
$appGatewayPublicIp = Get-AzureRmPublicIpAddress -Name $appGatewayPublicIpName -ResourceGroupName $resourceGroupName
$endpointName = "$($params.parameters.regionName.value)-endpoint"
$endPoint = Get-AzureRmTrafficManagerEndpoint -Name $endpointName -ProfileName $trafficManagerName -Type AzureEndpoints -ResourceGroupName $tmResourceGroupName -ErrorAction SilentlyContinue
if(!$endPoint)
{
    Write-Host "Creating Traffic Manager Endpoint '$endpointName'";
	New-AzureRmTrafficManagerEndpoint -Name $endpointName -ProfileName $trafficManagerName -ResourceGroupName $tmResourceGroupName -Type AzureEndpoints -TargetResourceId $appGatewayPublicIp.Id -EndpointStatus Enabled
}
else{
    Write-Host "Using existing Traffic Manager Endpoint '$endpointName'";
	$endPoint.TargetResourceId = $appGatewayPublicIp.Id;
	Set-AzureRmTrafficManagerEndpoint -TrafficManagerEndpoint $endPoint;
}

Write-Host "Done."