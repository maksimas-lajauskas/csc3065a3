
#!/bin/bash

deployment_id(){
echo "$(date +%d)-$(date +%m)-$(date +%Y)-$(date +%H)-$(date +%M)-$(date +%S)"
}
############### start vars and config capture

#vars - common
provider=""
varfile="deploymentvars.tf"
tfpath=""

#vars - gcp
gcp_proj_id=""
gcp_region=""
gcp_key_json=""
gcp_service_account=""
gcp_service_account_email=""
gcp_bigtable_instance="qse-bigtable"
gcp_bigtable_index_table="qse-index"
gcp_bigtable_ads_table="qse-ads"
declare -a gcp_zones
declare -a gcp_zones_final

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
            echo "[service account must have sufficient privileges, e.g. roles/owner and roles/storage.objectViewer]"
            echo "usage: './deploy.sh --provider gcp --project-id [project id] --region [project region] [no --zone defaults to first available zone in region] --creds-file [credentials json]'"
            echo "usage: './deploy.sh --provider gcp --project-id [project id] --region [project region] --zone [zone one in region] ... --zone [zone n in region] --creds-file [credentials json]'"
            echo "up to date region list can be found here: 'https://cloud.google.com/compute/docs/regions-zones/'"
            echo "NOTE: using multiple zones is under development" #todo multiple zones support in main.tf
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

        "--zone")
            gcp_zones+=("$2")
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
############### start main flow
#define src dir
src_dir=$(pwd)

if [[ "$provider" = "gcp"  ]]
then
#do gcp set up
    echo "STARTING GCP DEPLOYMENT"
    #on specified project now?
    echo "checking project..."
    if [[ "$(gcloud config get-value project)" != "$gcp_proj_id" ]] #if not...
    then
        echo "attempting to set project in gcloud..."
        gcloud config set project "$gcp_proj_id"
    fi

    #then verify
    if [[ "$(gcloud config get-value project)" != "$gcp_proj_id" ]]
    then
        echo "Error accessing project $gcp_proj_id, aborting. Please verifiy project id and/or access"
        exit 1
    fi
    echo "project successfully set"

    #credentials for service account - no keys?
    echo "checking key file..."
    if  ([[ "$gcp_key_json" = "" ]])
    then
        echo "Please specify json key file. Can create gcp key file using 'https://console.cloud.google.com/apis/credentials/serviceaccountkey'"
        exit 1

    fi

    echo "key file exists, reading..."

    gcp_service_account_email=$(grep -Po [[:alnum:]-_]+@.+\.gserviceaccount\.com "$gcp_key_json")
    echo "set service account email to: $gcp_service_account_email"
    gcp_service_account=$(echo "$gcp_service_account_email" | grep -Po [[:alnum:]-_]+@ | grep -Po [[:alnum:]-_]+)
    echo "set service account to: $gcp_service_account"

    echo "creating a working copy of keyfile"
    cp "$gcp_key_json" "$(pwd)/keys"
    gcp_key_json="$(pwd)/keys"

    echo "checking APIs in project..."
    #api's enabled?
    if [[ $(gcloud services list --enabled | grep -c "container.googleapis.com") -eq 0 ]]
    then
        echo "attempting to enable container api..."
        gcloud services enable container.googleapis.com
    else
        echo "container api enabled"
    fi

    if [[ $(gcloud services list --enabled | grep -c "bigtableadmin.googleapis.com") -eq 0 ]]
    then
        echo "attempting to enable bigtableadmin api..."
        gcloud services enable bigtableadmin.googleapis.com
    else
        echo "bigtableadmin api enabled"
    fi

    if [[ $(gcloud services list --enabled | grep -c "bigtable.googleapis.com") -eq 0 ]]
    then
        echo "attempting to enable bigtable api"
        gcloud services enable bigtable.googleapis.com
    else
        echo "bigtable api enabled"
    fi

        echo "passing key data to container builder..."
        #set up path and copy json
        tfpath="$(pwd)/tf-$provider"
        key_name="keys_$(deployment_id).json"
        cp "$gcp_key_json" "$tfpath/$key_name"

            #build images
                echo "starting container build..."
                #setup docker & dockerd
                if [[ $(ps -e | grep -c dockerd) -eq 0 ]]
                then
                    echo "dockerd needs to be started in background to continue deployment"
                    dockerd & disown
                    sleep 30s
                    if [[ $(jobs | grep -c dockerd) -eq 0 ]]
                    then
                        echo "dockerd appears to need sudo permission on this machine"
                        sudo echo "Attempting to start dockerd..."
                        sudo dockerd &
                        disown
                    fi
                fi
                echo "authenticating docker to project"
                cat "$gcp_key_json" | docker login -u _json_key --password-stdin gcr.io/"$gcp_proj_id"

                #crawler
                echo "building crawler with provided keys..."
                cd $(pwd)/crawler/GCP
                cp "$gcp_key_json" ./gcp_keys.json
                crawlerID="crawler-gcp-$(deployment_id)"
                docker build -t="$crawlerID" .
                cd "$src_dir"

                echo "tagging and pushing crawler image to project repository..."
                crawler_gcr_tag="gcr.io/$gcp_proj_id/$crawlerID"
                docker tag "$crawlerID" "$crawler_gcr_tag:latest"
                gcloud docker -- push "$crawler_gcr_tag:latest"
                crawler_sha=$(docker images --digests| grep "$crawler_gcr_tag" | grep -Po "sha256.[[:alnum:]]+")

        echo "writing terraform variables file..."
        #write project name variable
        echo "variable \"gcp_proj_id\"{" > "$tfpath/$varfile" #clobbers varfile on redeploy
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

        #write zones variable
        echo "variable \"gcp_zones\"{" >> "$tfpath/$varfile"
        echo -e "\tdefault = [" >> "$tfpath/$varfile"
        if [[ "${#gcp_zones[@]}" -ge 1 ]]
        then
            for zone in "${gcp_zones[@]}"; do
                if [[ $(echo "$zone" | grep -c "$gcp_region") -gt 0 ]]
                then
                    echo -e "\t\t\"$zone\"," >> "$tfpath/$varfile"
                    gcp_zones_final+=("$zone")
                else
                    echo "Zone $zone not in region $gcp_region and is therefore ignored"
                fi
            done
        else
            echo "No zones passed in, defaulting to $gcp_region-a"
            echo -e "\t\t\"$gcp_region-a\"," >> "$tfpath/$varfile"
            gcp_zones_final+="$gcp_region-a"
        fi
        echo -e "\t\t]" >> "$tfpath/$varfile"
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
        echo "initialising terraform in deployment directory $tfpath"
        cd "$tfpath" && terraform init

        #clear old kubernetes pod definitions
        echo "" > pods.tf

        echo "attempting initial terraform apply to create cluster, no pods will be deployed this round"
        plan="qsedeployplan_$(deployment_id).out"
        terraform plan -out="$plan" && terraform apply "$plan"

        #configure kubectl and run plan + apply again to deploy workload (appears to be a dependency for terraform to deploy k8s pods)
        echo "configuring kubectl to talk to cluster to allow deployment of pods"
        gcloud container clusters get-credentials "$gcp_proj_id-cluster" --region "$gcp_region" --project "$gcp_proj_id"

        #write out pod resources now, todo...
            echo "writing pod definitions file..."
            #write out test pod
            echo "resource \"kubernetes_pod\" \"$crawlerID\" {" >> pods.tf
            echo "    metadata {" >> pods.tf
            echo "        name = \"$crawlerID\"" >> pods.tf
            echo "        labels = {" >> pods.tf
            echo "            App = \"$crawlerID\"" >> pods.tf
            echo "        }" >> pods.tf
            echo "    }" >> pods.tf
            echo "    spec {" >> pods.tf
            echo "        container {" >> pods.tf
            echo "            image = \"$crawler_gcr_tag@$crawler_sha\"" >> pods.tf
            echo "            name  = \"$crawlerID\"" >> pods.tf
            echo "            port {" >> pods.tf
            echo "                container_port = 80" >> pods.tf
            echo "            }" >> pods.tf
            echo "        }" >> pods.tf
            echo "    }" >> pods.tf
            echo "}" >> pods.tf

        echo "updating service account permissions to deploy from project's container image repository"
        gsutil iam ch serviceAccount:"$gcp_service_account@$gcp_proj_id.iam.gserviceaccount.com:objectViewer" "gs://artifacts.$gcp_proj_id.appspot.com"

        echo "attempting final apply to deploy pods as defined in pods.tf file"
        plan="qsedeployplan_$(deployment_id).out"
        terraform plan -out="$plan" && terraform apply "$plan" && echo "We done, yo. QSE on GCP/GKE deployed."

        echo "checking and growing bigtable clusters to match zone spec..."
        if [[ "${#gcp_zones_final[@]}" -gt 1 ]]
        then
            for z in "${gcp_zones_final[@]}"; do
                cluster_name="$gcp_proj_id-btc-$z"
                if [[ $(gcloud bigtable clusters list | grep -c "$cluster_name") -eq 0  ]]
                then
                    gcloud bigtable clusters create "$cluster_name" --instance="$gcp_bigtable_instance" --zone="$z"
                fi
            done
        else
            echo "no growing was necessary, cluster count matches spec"
        fi

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
