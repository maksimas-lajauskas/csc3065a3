#!/bin/bash

############### start vars and config capture

#vars - common
provider=""
varfile="deploymentvars.tf"
tfpath=""

#vars - gcp
gcp_proj_id=""
gcp_region=""
gcp_key_json=""

#build config from args
while (( "$#" )); do
    case "$1" in

        "--help")
            #!!!TODO!!!: help text
            #gcp deployment
            echo "GCP:"
            echo "- have an existing projet on GCP"
            echo "- have an existing service account or use ' gcloud iam service-accounts create [SA-NAME] --description \"[SA-DESCRIPTION]\" --display-name \"[SA-DISPLAY-NAME]\" ' to create"
            echo "- have a valid service key json file or visit 'https://console.cloud.google.com/apis/credentials/serviceaccountkey' to create"
            echo "usage: './deploy.sh --provider gcp --project-id [project id] --region [project region] --creds-file [credentials json]'"
            echo "up to date region list can be found here: 'https://cloud.google.com/compute/docs/regions-zones/'"
            #aws deployment
            echo "AWS: deployment under development"
            #azure deployment
            echo "AZURE: deployment under development"
            exit 0
            ;;

        "--provider")
            case "$2" in

                    "gcp")
                        provider="$2"
                        ;;

                    "aws")
                        provider="$2"
                        ;;

                    "azure")
                        provider="$2"
                        ;;

                    *)
                        echo "provider $2 not recognised"
                        exit 1
                        ;;

            esac
            ;;

        "--project-id")
            gcp_proj_id="$2"
            ;;

        "--region")
            gcp_region="$2"
            ;;

        "--creds-file")
            gcp_key_json="$2"
            ;;

        *)
            echo "argument $1 not recognised, try running with '--help' option"
            exit 1
            ;;

    esac
shift 2
done

############### end vars and config capture
#!!!TODO: VALIDATE THE LOT !!!
############### start main flow
echo "provider: $provider"
echo "project id: $gcp_proj_id"
echo "region: $gcp_region"
echo "keyfile: $gcp_key_json"


#!!!TODO!!!: test && terraform files
if [[ "$provider" = "gcp"  ]]
then
#do gcp set up
    #on specified project now?
    if [[ "$(gcloud config get-value project)" != "$gcp_proj_id" ]] #if not...
    then
        gcloud config set project "$gcp_proj_id"
    fi

    #then verify
    if [[ "$(gcloud config get-value project)" != "$gcp_proj_id" ]]
    then
        echo "Error accessing project $gcp_proj_id, aborting. Please verifiy project id and/or access"
        exit 1
    fi

    #credentials for service account - no keys?
    if  ([[ "$gcp_key_json" = "" ]])
    then
        echo "Please specify json key file. Can create gcp key file using 'https://console.cloud.google.com/apis/credentials/serviceaccountkey'"
        exit 1

    fi

    #api's enabled?
    if [[ $(gcloud services list --enabled | grep -c "container.googleapis.com") -eq 0 ]]
    then
        gcloud services enable container.googleapis.com
    fi

        #set up path and copy json
        deployment_id="$(date +%d)_$(date +%m)_$(date +%Y)_$(date +%H)_$(date +%M)_$(date +%S)"
        tfpath="$(pwd)/tf-$provider"
        key_name="keys_$deployment_id.json"
        cp "$gcp_key_json" "$tfpath/$key_name"

        #write project name variable
        echo "variable \"gcp_proj_id\"{" >> "$tfpath/$varfile"
        echo -e "\tdefault = \"$gcp_proj_id\"" >> "$tfpath/$varfile"
        echo "}" >> "$tfpath/$varfile"

        #write credentials file variable
        echo "variable \"gcp_key_json\"{" >> "$tfpath/$varfile"
        echo -e "\tdefault = \"$key_name\"" >> "$tfpath/$varfile"
        echo "}" >> "$tfpath/$varfile"

        #write region variable
        echo "variable \"gcp_region\"{" >> "$tfpath/$varfile"
        echo -e "\tdefault = \"$gcp_region\"" >> "$tfpath/$varfile"
        echo "}" >> "$tfpath/$varfile"

        #setup done, initialise terraform in $tfpath and kick off engine
        cd "$tfpath" && terraform init  && terraform plan -out="qsedeployplan_$deployment_id.out" && terraform apply

#finish gcp set up

elif [[ "$provider" = "aws" ]]
then
#do aws set up
    echo "aws not implemented"
#finish aws set up

elif [[ "$provider" = "azure" ]]
then
#do azure set up
    echo "azure not implemented"
#finish azure set up

fi
############### end main flow

