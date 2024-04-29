#!/usr/bin/env bash
#########################################################################
# Onboard and manage application on cloud infrastructure.
# Usage: devops.sh [COMMAND]
# Globals:
#
# Commands
#   provision       Provision common resources.
#   deploy          Prepare the app and deploy to cloud.
#   create_cicd_sp  Create service principal for CI/CD.
#   create_sp       Create system identity for the app.
#   delete          Delete the app from cloud.
# Params
#    -n, --name     Name
#    -s, --subscription Subscription ID
#        --org      GitHub organization
#        --repo     GitHub repository
#        --logAnalyticsWorkspaceName Log Analytics workspace name
#        --aoaiServiceEndpoint AOAI service endpoint
#        --aoaiServiceKey AOAI service key
#    -m, --message  Deployment message
#    -h, --help     Show this message and get help for a command.
#    -l, --location Resource location. Default westus3
#    -o, --oidc     Flag to indicate to use OIDC for authentication
#########################################################################

# Stop on errors
set -e

show_help() {
    echo "$0 : Onboard and manage application on cloud infrastructure." >&2
    echo "Usage: devops.sh [COMMAND]"
    echo "Globals"
    echo
    echo "Commands"
    echo "  create_sp   Create system identity for the app."
    echo "  create_cicd_sp  Create service principal for CI/CD."
    echo "  provision   Provision common resources."
    echo "  delete      Delete the app from cloud."
    echo "  deploy      Prepare the app and deploy to cloud."
    echo
    echo "Arguments"
    echo "   -n, --name             Name"
    echo "   -s, --subscription      Subscription ID"
    echo "       --org              GitHub organization"
    echo "       --repo             GitHub repository"
    echo "       --logAnalyticsWorkspaceName Log Analytics workspace name"
    echo "       --aoaiServiceEndpoint AOAI service endpoint"
    echo "       --aoaiServiceKey AOAI service key"
    echo "   -m, --message          Deployment message"
    echo "   -l, --location         Resource location. Default westus3"
    echo "   -h, --help             Show this message and get help for a command."
    echo "   -o, --oidc             Flag to indicate to use OIDC for authentication"
    echo
}

validate_parameters(){
    # Check command
    if [ -z "$1" ]
    then
        echo "COMMAND is required" >&2
        show_help
        exit 1
    fi

    # Validate create_cicd_sp params
    if [ "$1" == "create_cicd_sp" ]
    then
        if [ -z "$name" ]
        then
            echo "Name is required." >&2
            show_help
            exit 1
        fi

        if [ -z "$subscription_id" ]
        then
            echo "Subscription ID is required." >&2
            show_help
            exit 1
        fi

        if [ -z "$github_org" ]
        then
            echo "GitHub organization is required." >&2
            show_help
            exit 1
        fi

        if [ -z "$github_repo" ]
        then
            echo "GitHub repository is required." >&2
            show_help
            exit 1
        fi
    fi
}

provision_cicd_sp(){
    echo "Creating service principal for CICD."

    # shellcheck disable=SC2153
    app_client_id=$(create_cicd_sp "$name" "$subscription_id" "$github_org" "$github_repo")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo "Failed to create cicd sp" >&2
        exit 1
    fi

    # Save variables to .env
    echo "Save Azure variables to ${ENV_FILE}"
    {
        echo ""
        echo "# Script devops.provision_cicd_sp output variables."
        echo "# Generated on ${ISO_DATE_UTC} for subscription ${subscription_id}"
        echo "CICD_CLIENT_ID=$app_client_id"
    }>> "$ENV_FILE"

}

provision_sp(){
    echo "Creating service principal."

    # shellcheck disable=SC2153
    response="$(create_sp "$name" "$subscription_id")"
    if [[ ${PIPESTATUS[0]} -ne 0 ]] || [[ -z "$response" ]]; then
        echo "Failed to create sp" >&2
        exit 1
    else

        app_client_id=$(jq --raw-output .client_id <(echo "$response"))
        app_client_secret=$(jq --raw-output .client_secret <(echo "$response"))

        # Save variables to .env
        echo "Save Azure variables to ${ENV_FILE}"
        {
            echo ""
            echo "# Script devops.provision_sp output variables."
            echo "# Generated on ${ISO_DATE_UTC} for subscription ${subscription_id}"
            echo "CHAT_APP_CLIENT_ID=$app_client_id"
            echo "CHAT_APP_CLIENT_SECRET=$app_client_secret"
        }>> "$ENV_FILE"
    fi

}

replace_parameters(){

    # echo "Replace parameters with environment variables"
    additional_parameters=()
    if [ -n "$location" ]
    then
        additional_parameters+=("location=$location")
    fi
    if [ -n "$name" ]
    then
        additional_parameters+=("applicationName=$name")
    fi

    if [ -n "$log_analytics_workspace_name" ]
    then
        additional_parameters+=("logAnalyticsWorkspaceName=$log_analytics_workspace_name")
    fi

    if [ -n "$aoai_service_endpoint" ]
    then
        additional_parameters+=("aoaiServiceEndpoint=$aoai_service_endpoint")
    fi

    if [ -n "$aoai_service_key" ]
    then
        additional_parameters+=("aoaiServiceKey=$aoai_service_key")
    fi

    echo "${additional_parameters[@]}"

}

validate_deployment(){
    local location=$1
    local deployment_name="${PROJ_NAME}.validate_deployment-${run_date}"

    IFS=' ' read -ra additional_parameters <<< "$(replace_parameters)"


    echo "Validating ${deployment_name} with ${additional_parameters[*]}"

    result=$(az deployment sub validate \
        --no-prompt true \
        --name "${deployment_name}" \
        --location "$location" \
        --template-file "${INFRA_DIRECTORY}/main.bicep" \
        --parameters "${INFRA_DIRECTORY}/main.parameters.json" \
        --parameters "${additional_parameters[@]}")

    state=$(echo "$result" | jq -r '.properties.provisioningState')
    if [ "$state" != "Succeeded" ]
    then
        echo "Validation failed with state $state"
        echo "$result" | jq -r '.properties.error.details[]'
        exit 1
    fi

}

provision(){
    # Provision resources for the application.
    local location=$1
    local deployment_name="${PROJ_NAME}.provision-${run_date}"

    # Replace parameters
    IFS=' ' read -ra additional_parameters <<< "$(replace_parameters)"

    echo "Deploying ${deployment_name} with ${additional_parameters[*]}"

    result=$(az deployment sub create \
        --no-prompt true \
        --name "${deployment_name}" \
        --location "$location" \
        --template-file "${INFRA_DIRECTORY}/main.bicep" \
        --parameters "${INFRA_DIRECTORY}/main.parameters.json" \
        --parameters "${additional_parameters[@]}")

    echo "$result" >> "${PROJ_ROOT_PATH}/.azuredeploy.log"

    state=$(echo "$result" | jq -r '.properties.provisioningState')
    if [ "$state" != "Succeeded" ]
    then
        echo "Deployment failed with state $state"
        echo "$result" | jq -r '.properties.error.details[]'
        exit 1
    fi

    # Get the output variables from the deployment
    output_variables=$(az deployment sub show -n "${deployment_name}" --query 'properties.outputs' --output json)
    echo "Save deployment $deployment_name output variables to ${ENV_FILE}"
    {
        echo ""
        echo "# Deployment output variables"
        echo "# Generated on ${ISO_DATE_UTC}"
        echo "$output_variables" | jq -r 'to_entries[] | "\(.key | ascii_upcase )=\(.value.value)"'
    }>> "$ENV_FILE"

}

delete(){
    echo pass
}

deploy(){
    local source_folder="${PROJ_ROOT_PATH}/functions"
    local destination_dir="${PROJ_ROOT_PATH}/dist"
    local timestamp
    timestamp=$(date +'%Y%m%d%H%M%S')
    local zip_file_name="${app_name}_${timestamp}.zip"
    local zip_file_path="${destination_dir}/${zip_file_name}"

    echo "$0 : deploy $app_name" >&2

    # Ensure the source folder exists
    if [ ! -d "$source_folder" ]; then
        echo "Error: Source folder '$source_folder' does not exist."
        return 1
    fi

    # Create the destination directory if it doesn't exist
    mkdir -p "$(dirname "$zip_file_path")"

    # Create an array for exclusion patterns to zip based on .gitignore
    exclude_patterns=()
    while IFS= read -r pattern; do
        # Skip lines starting with '#' (comments)
        if [[ "$pattern" =~ ^[^#] ]]; then
            exclude_patterns+=("-x./$pattern")
        fi
    done < "${PROJ_ROOT_PATH}/.gitignore"
    exclude_patterns+=("-x./local.settings.*")
    exclude_patterns+=("-x./requirements_dev.txt")

    # Zip the folder to the specified location
    cd "$source_folder"
    zip -r "$zip_file_path" ./* "${exclude_patterns[@]}"

    func azure functionapp publish "$app_name"

    # az functionapp deployment source config-zip \
    #     --name "${functionapp_name}" \
    #     --resource-group "${resource_group}" \
    #     --src "${zip_file_path}"

    # Update environment variables to function app
    update_environment_variables

    echo "Cleaning up"
    rm "${zip_file_path}"

    echo "Done"
}

update_environment_variables(){
    echo pass
}

# Globals
PROJ_ROOT_PATH=$(cd "$(dirname "$0")"/..; pwd)
echo "Project root: $PROJ_ROOT_PATH"
PROJ_NAME=$(basename "$PROJ_ROOT_PATH")
SCRIPT_DIRECTORY="${PROJ_ROOT_PATH}/script"
INFRA_DIRECTORY="${PROJ_ROOT_PATH}/infrastructure"
ENV_FILE="${PROJ_ROOT_PATH}/.env"

# shellcheck source=common.sh
source "${SCRIPT_DIRECTORY}/common.sh"

# Argument/Options
LONGOPTS=name:,message:,resource-group:,location:,org:,repo:,subscription:,logAnalyticsWorkspaceName:,aoaiServiceEndpoint:,aoaiServiceKey:,jumpbox,help
OPTIONS=n:m:g:l:s:jh

# Variables
name=""
message=""
location="westus3"
subscription_id=""
github_org=""
github_repo=""
log_analytics_workspace_name=""
aoai_service_endpoint=""
aoai_service_key=""
run_date=$(date +%Y%m%dT%H%M%S)
# ISO_DATE_UTC=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

# Parse arguments
TEMP=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
eval set -- "$TEMP"
unset TEMP
while true; do
    case "$1" in
        -h|--help)
            show_help
            exit
            ;;
        -n|--name)
            name="$2"
            shift 2
            ;;
        -s|--subscription)
            subscription_id="$2"
            shift 2
            ;;
        --org)
            github_org="$2"
            shift 2
            ;;
        --repo)
            github_repo="$2"
            shift 2
            ;;
        --logAnalyticsWorkspaceName)
            log_analytics_workspace_name="$2"
            shift 2
            ;;
        --aoaiServiceEndpoint)
            aoai_service_endpoint="$2"
            shift 2
            ;;
        --aoaiServiceKey)
            aoai_service_key="$2"
            shift 2
            ;;
        -m|--message)
            message="$2"
            shift 2
            ;;
        -l|--location)
            location="$2"
            shift 2
            ;;

        --)
            shift
            break
            ;;
        *)
            echo "Unknown parameters."
            show_help
            exit 1
            ;;
    esac
done

validate_parameters "$@"
command=$1
case "$command" in
    create_sp)
        provision_sp
        exit 0
        ;;
    create_cicd_sp)
        provision_cicd_sp
        exit 0
        ;;
    provision)
        validate_deployment "$location"
        provision "$location"
        exit 0
        ;;
    delete)
        delete
        exit 0
        ;;
    deploy)
        deploy
        exit 0
        ;;
    update_env)
        update_environment_variables
        exit 0
        ;;
    *)
        echo "Unknown command."
        show_help
        exit 1
        ;;
esac
