# Custom Chat Copilot SK Base

This project demonstrates the use of Azure AI services to build a chat application and Azure Open AI Services.

# Architecture Overview

![Architecture Overview](docs/images/architecture_overview.png)

**Solution**

- [Azure Container Apps](https://azure.microsoft.com/en-us/services/container-apps/) - The chat application hosting service.
- [Azure Blob Storage](https://azure.microsoft.com/en-us/products/storage/blobs/) - Target storage account where monitoring applications saves new files.
- [CosmosDB](https://azure.microsoft.com/en-us/services/cosmos-db/) - Chat History NoSQL database.
- [Azure AI Search](https://azure.microsoft.com/en-us/products/ai-services/ai-search/) - Vector Database for AI Search.
- [Docker](https://docs.docker.com/desktop/install/windows-install/) - Run the application in a container.

**DevOps**

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) - Provisioning, managing and deploying the application to Azure.
- [GitHub Actions](https://github.com/features/actions) - The CI/CD pipelines.
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/overview) - The CI/CD pipelines.

**Developer tools**

- [Visual Studio Code](https://code.visualstudio.com/) - The local IDE experience.
- [Git Client](https://git-scm.com/download/win)
- [GitHub Codespaces](https://github.com/features/codespaces) - The cloud IDE experience.
- [DevContainer](https://code.visualstudio.com/docs/remote/containers) - The containerized development environment.

# Quick Start

Get started using the chat app.

- Fork or Clone this project and configure .env settings
- Create System Identities
- Configure GitHub
- Run GitHub Actions
- Run Application

## Clone Project

```bash
# clone project
git clone "https://github.com/${GITHUB_ORG}/${GITHUB_REPO}.git"

# Navigate to Project
cd custom-chat-copilot-sk-base

# Open Project
code .

# Configure the environment variables. Copy `example.env` to `.env` and update the values
cp example.env .env
```

## Create System Identities

The solution uses two system identities.

| System Identities         | Authentication                                             | Authorization                   | Purpose                                                                        |
| ------------------------- | ---------------------------------------------------------- | ------------------------------- | ------------------------------------------------------------------------------ |
| `env.CICD_CLIENT_NAME`    | OpenId Connect (OIDC) based Federated Identity Credentials | Subscription Contributor access | Deploy cloud resources: <ul><li>core infrastructure</li><li>chat app</li></ul> |
| `env.CHATAPP_CLIENT_NAME` | ClientID and Client Secret                                 | TBD                             | TBD                                                                            |

```bash
# load .env vars (optional)
[ -f .env ] && while IFS= read -r line; do [[ $line =~ ^[^#]*= ]] && eval "export $line"; done < .env

# Login to az. Only required once per install.
az login --tenant $AZURE_TENANT_ID

# Create CICD system identity
./script/devops.sh create_cicd_sp --name $CICD_CLIENT_NAME --org $GITHUB_ORG --repo $GITHUB_REPO --subscription $AZURE_SUBSCRIPTION_ID
# Adds CICD_CLIENT_ID=$created_clientid to .env

# Create webapp system identity
./script/devops.sh create_sp --name $CHATAPP_CLIENT_NAME --subscription $AZURE_SUBSCRIPTION_ID
# Adds CHAT_APP_CLIENT_ID=$created_clientid to .env
# Adds CHAT_APP_CLIENT_SECRET=$created_secret to .env
```

## Configure GitHub

Create GitHub secrets for storing Azure configuration.

Open your GitHub repository and go to Settings.
Select Secrets and then New Secret.
Create secrets with values from `.env` for:

- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `CICD_CLIENT_ID`
- `CHAT_APP_CLIENT_ID`

## Provision Infrastructure

```bash
# load .env vars (optional)
[ -f .env ] && while IFS= read -r line; do [[ $line =~ ^[^#]*= ]] && eval "export $line"; done < .env

# Provision Core Infrastructure
./script/devops.sh provision --app_name "$APP_NAME" --rg_region "$RG_REGION"
```

## Deployment App

```bash
# Build
cd ./app
docker build . -t custom-chat-copilot-sk-base/chat-app

# Upload image to Registry
docker login <ACRNAME>.azurecr.io
docker tag custom-chat-copilot-sk-base/chat-app <ACRNAME>.azurecr.io/custom-chat-copilot-sk-base/chat-app:<VERSION>
docker push <ACRNAME>.azurecr.io/custom-chat-copilot-sk-base/chat-app:<VERSION>

# Deploy to Azure Container Apps
az containerapp update --name <APPLICATION_NAME> --resource-group <RESOURCE_GROUP_NAME> --image <IMAGE_NAME>
```

## Local Development

**_appsettings.Development.json_**

```bash
{
  "AzureSearchContentIndex": "",
  "AzureSearchServiceEndpoint": "",
  "AzureSearchServiceKey": "",
  "AzureStorageAccountEndpoint": "",
  "AzureStorageContainer": "content",
  "AzureStorageAccountConnectionString": "",
  "AOAIPremiumServiceEndpoint": "",
  "AOAIPremiumServiceKey": "",
  "AOAIPremiumChatGptDeployment": "",
  "AOAIStandardServiceEndpoint": "",
  "AOAIStandardServiceKey": "",
  "AOAIStandardChatGptDeployment": "",
  "AOAIEmbeddingsDeployment": "",
  "CosmosDBConnectionString": ""
}
```

# References

- https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-vscode
- https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep
