# Multi Region Highly Available Web App ARM Template
This is an Azure ARM Template and associated PowerShell deployment script to create a web app, CosmosDB, application gateway with 
Web Application Firewall, and Storage Account for logging.

The PowerShell deployment script also creates an endpoint for the new webapp in a Traffic Manager which is created if it does not already exist. 

You can use this script to replicate a web app's environment across several regions. The traffic manager will then direct requests to the most performant region (e.g. usually the 
closest region). If a region goes down, it will redirect requests to the next closest region, thus allowing for a highly available application.

The Traffic Manger should be the main entrypoint for the app (via DNS). 

## Architectural Diagram ##

![Architecture](https://github.com/ssemyan/HighlyAvailableAzureWebAppArmTemplate/raw/master/ArchitectureDiagram.gif)

 Note, this template creates regular Web Apps without an NSG. For web apps within a Network Security Group, you will need to use an 
 App Service Environment. 
 
## Parameters ##

- *regionName* - The name of the new region - this will form the base name of all the resources created. 
- *trafficManagerName* - The name of the Traffic Manager to create or use
- *trafficManagerResourceGroup* - The name of the resource group to create or use for the Traffic Manager
- *trafficManagerResourceGroupLocation* - The location for the Traffic Manager resource group
- *keyVaultOwnerId* - The ID of the user who should be given admin rights on the KeyVault
- *deploy_location* - the location to deploy the new region to

To look up user IDs with the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest): 

    az ad user show <username>

To use these files to create a region in a new or existing resource group, first log into the subscription you wish to use:

	Login-AzureRmAccount -SubscriptionName <name of subscription to use>

Then use the following command in a powershell prompt (where ResourceGroupName is the name of the resource group to use or create):

    .\deploy.ps1 -resourceGroupName [ResourceGroupName]
     
To run from a command prompt:

    powershell -f deploy.ps1 -resourceGroupName [ResourceGroupName]
