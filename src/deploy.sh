#!/bin/bash

#extracts service account email from keys json: grep -Po [[:alnum:]-_]+@.+\.gserviceaccount\.com [KEYS JSON FILE]
##!!! -> can push `docker tag`'ed images using `gcloud docker -- push [tag]`, will whine but will work first try, still deploying to test running images deployed this way"

deployment_id(){
echo "$(date +%d)_$(date +%m)_$(date +%Y)_$(date +%H)_$(date +%M)_$(date +%S)"
}
############### start vars and config capture

#vars - common
provider=""
varfile="deploymentvars.tf"
tfpath=""

#vars - gcp
gcp_proj_id=""
gcp_region=""
gcp_key_json="
gcp_service_account=""
gcp_bigtable_instance="qse-bigtable"
gcp_bigtable_index_table="qse-index"
gcp_bigtable_ads_table="qse-ads"
gcp_zone="" #todo make it fancy instead of just forcing a zone 'a'?

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
            echo "(service account must have sufficient privileges, e.g. roles/owner and roles/storage.objectViewer)"
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
            gcp_zone="$gcp_region-a" #todo find a better solution than just forcing zone 'a'
            ;;

        "--service-account")
            gcp_service_account="$2"
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
echo "service account: $gcp_service_account"

#!!!TODO!!!: test && terraform files

#define src dir
src_dir=$(pwd)
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

    if [[ $(gcloud services list --enabled | grep -c "bigtableadmin.googleapis.com") -eq 0 ]]
    then
        gcloud services enable bigtableadmin.googleapis.com
    fi

    if [[ $(gcloud services list --enabled | grep -c "bigtable.googleapis.com") -eq 0 ]]
    then
        gcloud services enable bigtable.googleapis.com
    fi

        #set up path and copy json
        tfpath="$(pwd)/tf-$provider"
        key_name="keys_$(deployment_id).json"
        cp "$gcp_key_json" "$tfpath/$key_name"

            #build images

                #setup docker
                cat "$key_name" | docker login -u _json_key --password-stdin gcr.io/"$gcp_proj_id"

                #crawler
                cd $(pwd)/crawler/GCP
                cp "$gcp_key_json" ./gcp_keys.json
                crawlerID="crawler-gcp-$(deployment_id)"
                docker build -t="$carwlerID" .
                cd "$src_dir"

                crawler_gcr_tag="gcr.io/$gcp_proj_id/$crawlerID:latest"
                docker tag "$crawlerID" "$crawler_gcr_tag"
                crawler_digest=$(gcloud docker -- push "$crawler_gcr_tag")
                echo "CRAWLER_DIGEST VARIABLE CONTENTS: $crawler_digest" #for testing

                #after pushing images, grant service account permissions to pull from gcr
                gsutil iam ch serviceAccount:"$gcp_service_account"@"$gcp_proj_id".iam.gserviceaccount.com:objectViewer gs://artifacts."$gcp_proj_id".appspot.com


        #write project name variable
        echo "variable \"gcp_proj_id\"{" > "$tfpath/$varfile" #clobbers tfvars on redeploy
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

        #write zone variable
        echo "variable \"gcp_zone\"{" >> "$tfpath/$varfile"
        echo -e "\tdefault = \"$gcp_zone\"" >> "$tfpath/$varfile"
        echo "}" >> "$tfpath/$varfile"

        #write bigtable instance name variable
        echo "variable \"gcp_bigtable_instance\"{" >> "$tfpath/$varfile"
        echo -e "\tdefault = \"$gcp_bigtable_instance\"" >> "$tfpath/$varfile"
        echo "}" >> "$tfpath/$varfile"

        #write bigtable index table name variable
        echo "variable \"gcp_bigtable_index_table\"{" >> "$tfpath/$varfile"
        echo -e "\tdefault = \"$gcp_bigtable_index_table\"" >> "$tfpath/$varfile"
        echo "}" >> "$tfpath/$varfile"

        #write bigtable ads table name variable
        echo "variable \"gcp_bigtable_ads_table\"{" >> "$tfpath/$varfile"
        echo -e "\tdefault = \"$gcp_bigtable_ads_table\"" >> "$tfpath/$varfile"
        echo "}" >> "$tfpath/$varfile"


        #setup almost done, initialise terraform in $tfpath and create cluster (will fail on pod creation at this point if not split up)
        cd "$tfpath" && terraform init
        plan="qsedeployplan_$(deployment_id).out"
        terraform plan -out="$plan" && terraform apply "$plan"

        #configure kubectl and run plan + apply again to deploy workload
        gcloud container clusters get-credentials "$gcp_proj_id-cluster" --region "$gcp_region-a" --project "$gcp_proj_id"

        #write out pod resources now, todo...

        #clear kubernetes pods from main.tf
        first_kubernetes_pod_mention=$(grep -n "kubernetes_pod" main.tf | grep -Po [[:digit:]]+\: | grep -Po [[:digit:]]+ | head -n1)
        cutoff_line_no=$(( $first_kubernetes_pod_mention - 1 ))
        head -n$cutoff_line_no main.tf > main.tf

        #write out test pod [0c7dbb8923de6ecd40ffb4de9c5969201fa85663bbee4a5052bd6cb491a05ef7 should be $test_digest]
        echo "resource \"kubernetes_pod\" \"pytest-cca3\" {" >> main.tf
        echo "    metadata {" >> main.tf
        echo "        name = \"pytest-cca3\"" >> main.tf
        echo "        labels = {" >> main.tf
        echo "            App = \"pytest-cca3\"" >> main.tf
        echo "        }" >> main.tf
        echo "    }" >> main.tf
        echo "    spec {" >> main.tf
        echo "        container {" >> main.tf
        echo "            image = \"gcr.io/cca3-263512/pytest-cca3@sha256:0c7dbb8923de6ecd40ffb4de9c5969201fa85663bbee4a5052bd6cb491a05ef7\"" >> main.tf #TODO dynamically retrieve digest sha256 code
        echo "            name  = \"pytest-cca3\"" >> main.tf
        echo "            port {" >> main.tf
        echo "                container_port = 80" >> main.tf
        echo "            }" >> main.tf
        echo "        }" >> main.tf
        echo "    }" >> main.tf
        echo "}" >> main.tf


        plan="qsedeployplan_$(deployment_id).out"
        terraform plan -out="$plan" && terraform apply "$plan"

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
