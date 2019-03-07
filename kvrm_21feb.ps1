param(
 [Parameter(Mandatory=$True)]
 [string]
 $resourceGroupName,

  [Parameter(Mandatory=$True)]
 [string]
 $resourceGroupLocation,

 [Parameter(Mandatory=$True)]
 [string]
 $keyvaultName,

 [Parameter(Mandatory=$True)]
 [string]
 $userPrincipalName,

 [Parameter(Mandatory=$True)]
 [string]
 $secretfileLocation

)

#******************************************************************************
# Script body
# Execution begins here for creating Resource Group, creating Key Vault,
# configuring access policy, parsing the secrets file and adding secrets to vault
#******************************************************************************

# Login to Azure
# Login-AzAccount

# Create a Resource Group
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. Creating new Resource Group";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}

# Create a Key Vault
$resourcekv = Get-AzureRmResource -Name $keyvaultName -ErrorAction SilentlyContinue
if(!$resourcekv)
{
Write-Host "Resource '$keyvaultName' does not exist. Creating new resource";
New-AzKeyVault -Name $keyvaultName -ResourceGroupName $resourceGroupName -Location $resourceGroupLocation
}
else
{
	Write-Host "Using existing Key Vault '$keyvaultName'";
}

# set key vault Access policy
Write-Host "Setting up access policy on key vault"; 
Set-AzureRmKeyVaultAccessPolicy -VaultName $keyvaultName -UserPrincipalName $userPrincipalName -PermissionsToSecrets set,get -PassThru

 Write-Host "parsing the file for secrets and adding it to Key Vault";
(Get-Content $secretfileLocation) -match("=") | % { $_ -replace " ", "" } | % { $_ -replace """", "" } | set-content $secretfileLocation

foreach($line in Get-Content $secretfileLocation) 
	{
		$k = $line.substring(0,$line.IndexOf('=')) 
		if($line.substring($line.IndexOf('=')+1).length -eq 0) 
		{ 
			$v=" "
		}
		else
		{
			$v = $line.substring($line.IndexOf('=')+1)
		}
		
		$avalue = ConvertTo-SecureString $v -AsPlainText -Force
		$secret = Set-AzKeyVaultSecret -VaultName $keyvaultName -Name $k -SecretValue $avalue
		$sec = (Get-AzKeyVaultSecret -vaultName $keyvaultName -name $k).SecretValueText
		write-host "getting secret value for '$k' is '$sec'"
	}
	
remove-item $secretfileLocation
