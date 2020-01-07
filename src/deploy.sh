
#!/bin/bash

deployment_id(){
echo "$(date +%d)-$(date +%m)-$(date +%Y)-$(date +%H)-$(date +%M)-$(date +%S)"
}
############### start vars and config capture

#vars - common
src_dir=$(pwd)
provider=""
num_crawlers=""
default_num_crawlers=1
num_search_pods=""
default_num_search_pods=1
num_ads_pods=""
default_num_ads_pods=1
varfile="deploymentvars.tf"
tfpath=""
common_page_content_column_name="pagetext"
common_max_ads_per_page="3"
common_image_file_persist_seconds="30"
common_ads_image_column_name="imgbytes"
common_ads_image_height_column_name="imgheight"
common_ads_image_width_column_name="imgwidth"
common_ads_image_mode_column_name="imgmode"
common_ads_keywords_list_column_name="adkeywords"
build_containers="false"
deploy_pods="false"
sync_cluster="false"

#container image vars
crawler_image_build_id=""
crawler_image_build_sha=""
full_crawler_image_tag=""
search_image_build_id=""
search_image_build_sha=""
full_search_image_tag=""
ads_image_build_id=""
ads_image_build_sha=""
full_ads_image_tag=""

#vars - gcp
gcp_proj_id=""
gcp_region=""
gcp_key_json=""
gcp_service_account=""
gcp_service_account_email=""
gcp_bigtable_instance="qse-bigtable"
gcp_bigtable_index_table="qse-index"
gcp_bigtable_ads_table="qse-ads"
gcp_bigtable_column_family="index" #do not change without also modifying gcp main.tf
gcp_bigtable_ads_column_family="ads" #do not change without also modifying gcp main.tf
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
            shift
            ;;

        "--project-id")
            gcp_proj_id="$2"
            shift
            ;;

        "--region")
            gcp_region="$2"
            shift
            ;;

        "--zone")
            gcp_zones+=("$2")
            shift
            ;;

        "--creds-file")
            gcp_key_json="$2"
            shift
            ;;

        "--num-crawlers")
            num_crawlers="$2"
            shift
            ;;

        "--num-search-pods")
            num_search_pods="$2"
            shift
            ;;

        "--num-ads-pods")
            num_ads_pods="$2"
            shift
            ;;

        "--build-containers")
            build_containers="true"
            ;;

        "--deploy-pods")
            deploy_pods="true"
            ;;

        "--sync-cluster")
            sync_cluster="true"
            ;;

        *)
            echo "argument $1 not recognised, try running with '--help' option"
            exit 1
            ;;

    esac
shift
done

############### end vars and config capture
############### start main flow

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

    #set up path and copy json
    tfpath="$(pwd)/tf-$provider"
    key_name="keys_$(deployment_id).json"
    cp "$gcp_key_json" "$tfpath/$key_name"

    if [[ "$build_containers" = "true" ]]
    then
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
                cd $src_dir/crawler/GCP
                cp ../crawler.py ./crawler.py
                cp "$gcp_key_json" ./gcp_keys.json
                crawler_image_build_id="crawler-gcp-$(deployment_id)"
                docker build -t="$crawler_image_build_id" .
                cd "$src_dir"

                echo "tagging and pushing crawler image to project repository..."
                full_crawler_image_tag="gcr.io/$gcp_proj_id/$crawler_image_build_id"
                docker tag "$crawler_image_build_id" "$full_crawler_image_tag:latest"
                gcloud docker -- push "$full_crawler_image_tag:latest"
                crawler_image_build_sha=$(docker images --digests| grep "$full_crawler_image_tag" | grep -Po "sha256.[[:alnum:]]+")

                #search
                echo "building search pod image with provided keys..."
                cd $src_dir/search/GCP
                cp -r ../templates/ . #todo: tie this in after ads service tests out with dynamic image load
                cp ../search.py ./search.py
                cp "$gcp_key_json" ./gcp_keys.json
                search_image_build_id="search-gcp-$(deployment_id)"
                docker build -t="$search_image_build_id" .
                cd "$src_dir"

                echo "tagging and pushing search pod image to project repository..."
                full_search_image_tag="gcr.io/$gcp_proj_id/$search_image_build_id"
                docker tag "$search_image_build_id" "$full_search_image_tag:latest"
                gcloud docker -- push "$full_search_image_tag:latest"
                search_image_build_sha=$(docker images --digests| grep "$full_search_image_tag" | grep -Po "sha256.[[:alnum:]]+")

                #ads
                echo "building ads pod image with provided keys..."
                cd $(pwd)/ads/GCP
                cp -r ../templates/ .
                cp ../ads.py ./ads.py
                cp "$gcp_key_json" ./gcp_keys.json
                ads_image_build_id="ads-gcp-$(deployment_id)"
                docker build -t="$ads_image_build_id" .
                cd "$src_dir"

                echo "tagging and pushing ads pod image to project repository..."
                full_ads_image_tag="gcr.io/$gcp_proj_id/$ads_image_build_id"
                docker tag "$ads_image_build_id" "$full_ads_image_tag:latest"
                gcloud docker -- push "$full_ads_image_tag:latest"
                ads_image_build_sha=$(docker images --digests| grep "$full_ads_image_tag" | grep -Po "sha256.[[:alnum:]]+")

            else #infer latest tag id's from docker report
                
                imagelist=$(docker images | grep -P "gcr\.io/$gcp_proj_id/[[:alnum:]]+-gcp-[[:digit:]]+-[[:digit:]]+-[[:digit:]]+-[[:digit:]]+-[[:digit:]]+-[[:digit:]]+")
                echo "$imagelist"
                full_crawler_image_tag=$(echo "$imagelist" | grep crawler | head -n1 | grep -Po "gcr\.io/$gcp_proj_id/[[:alnum:]]+-gcp-[[:digit:]]+-[[:digit:]]+-[[:digit:]]+-[[:digit:]]+-[[:digit:]]+-[[:digit:]]+")
                echo "$full_crawler_image_tag"
                full_search_image_tag=$(echo "$imagelist" | grep search | head -n1 | grep -Po "gcr\.io/$gcp_proj_id/[[:alnum:]]+-gcp-[[:digit:]]+-[[:digit:]]+-[[:digit:]]+-[[:digit:]]+-[[:digit:]]+-[[:digit:]]+")
                echo "$full_search_image_tag"
                full_ads_image_tag=$(echo "$imagelist" | grep ads | head -n1 | grep -Po "gcr\.io/$gcp_proj_id/[[:alnum:]]+-gcp-[[:digit:]]+-[[:digit:]]+-[[:digit:]]+-[[:digit:]]+-[[:digit:]]+-[[:digit:]]+")
                echo "$full_ads_image_tag"
                
                if [[ "$full_crawler_image_tag" = "" ]]
                then
                    echo "[ERROR]: docker has no crawler image tag, please re-run with '--build-containers' option"
                    exit 1

                elif [[ "$full_search_image_tag" = "" ]]
                then
                    echo "[ERROR]: docker has no search image tag, please re-run with '--build-containers' option"
                    exit 1

                elif [[ "$full_ads_image_tag" = "" ]]
                then
                    echo "[ERROR]: docker has no ads image tag, please re-run with '--build-containers' option"
                    exit 1
                fi

                crawler_image_build_sha=$(docker images --digests| grep "$full_crawler_image_tag" | grep -Po "sha256.[[:alnum:]]+")
                search_image_build_sha=$(docker images --digests| grep "$full_search_image_tag" | grep -Po "sha256.[[:alnum:]]+")
                ads_image_build_sha=$(docker images --digests| grep "$full_ads_image_tag" | grep -Po "sha256.[[:alnum:]]+")


        fi

    if [[ "$sync_cluster" = "true" ]]
    then
        echo "clearing additional bigtable clusters..."
        first_existing_zone=$(grep -n1 "default = \[" tf-gcp/deploymentvars.tf | egrep -v "variable \"gcp_zones\"{|default = \[" | grep -Po "([-[:alnum:]])+" | tail -n1)
        cleardown_list=($(gcloud bigtable clusters list | egrep -v "$first_existing_zone" | grep -Po "$gcp_proj_id-btc-[[:alnum:]-]+"))

        for cluster in "${cleardown_list[@]}"; do
            gcloud bigtable clusters delete "$cluster" --instance "$gcp_bigtable_instance" --quiet
        done

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
        echo "" > services.tf


        echo "attempting initial terraform apply to create cluster, no pods will be deployed this round"
        plan="qsedeployplan_$(deployment_id).out"
        terraform plan -out="$plan" && terraform apply "$plan"

        #configure kubectl and run plan + apply again to deploy workload (appears to be a dependency for terraform to deploy k8s pods)
        echo "configuring kubectl to talk to cluster to allow deployment of pods"
        gcloud container clusters get-credentials "$gcp_proj_id-cluster" --region "$gcp_region" --project "$gcp_proj_id"
    fi

    if [[ "$deploy_pods" = "true" ]]
    then
        #setup almost done, initialise terraform in $tfpath and create cluster (will fail on pod creation at this point if not split up)
        echo "initialising terraform in deployment directory $tfpath"
        cd "$tfpath" && terraform init
        #clear old kubernetes pod definitions
            echo "" > pods.tf
            echo "" > services.tf
        #write out pod resources now, todo...
            echo "writing pod definitions file..."
            #CRAWLER
                #revert to default value
                if [[ "$num_crawlers" = "" ]]
                then
                    num_crawlers="$default_num_crawlers"
                fi
            echo "resource \"kubernetes_deployment\" \"qse-crawler\" {" >> pods.tf
            echo "    metadata {" >> pods.tf
            echo "        name = \"qse-crawler\"" >> pods.tf
            echo "        labels = {" >> pods.tf
            echo "            App = \"qse-crawler\"" >> pods.tf
            echo "        }" >> pods.tf
            echo "    }" >> pods.tf
            echo "    spec {" >> pods.tf
            echo "        replicas = $num_crawlers" >> pods.tf
            echo "        strategy {" >> pods.tf
            echo "            type = \"RollingUpdate\"" >> pods.tf
            echo "            rolling_update {" >> pods.tf
            echo "                max_surge = $(( $num_crawlers + 1 ))" >> pods.tf
            echo "                max_unavailable = $num_crawlers" >> pods.tf
            echo "            }" >> pods.tf
            echo "        }" >> pods.tf
            echo "        selector {" >> pods.tf
            echo "            match_labels = {" >> pods.tf
            echo "                App = \"qse-crawler\"" >> pods.tf
            echo "            }" >> pods.tf
            echo "        }" >> pods.tf
            echo "        template {" >> pods.tf
            echo "            metadata{" >> pods.tf
            echo "                labels = {" >> pods.tf
            echo "                    App = \"qse-crawler\"" >> pods.tf
            echo "                }" >> pods.tf
            echo "            }" >> pods.tf
            echo "            spec {" >> pods.tf
            echo "                container {" >> pods.tf
            echo "                    image = \"$full_crawler_image_tag@$crawler_image_build_sha\"" >> pods.tf
            echo "                    name  = \"qse-crawler\"" >> pods.tf
            echo "                    resources {" >> pods.tf
            echo "                                limits {" >> pods.tf
            echo "                                  cpu    = \"0.5\"" >> pods.tf
            echo "                                  memory = \"256Mi\"" >> pods.tf
            echo "                                }" >> pods.tf
            echo "                                requests {" >> pods.tf
            echo "                                  cpu    = \"250m\"" >> pods.tf
            echo "                                  memory = \"50Mi\"" >> pods.tf
            echo "                                }" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"QSEPROVIDER\"" >> pods.tf
            echo "                          value = \"GCP\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GCP_PROJECT_ID\"" >> pods.tf
            echo "                          value = \"$gcp_proj_id\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GOOGLE_APPLICATION_CREDENTIALS\"" >> pods.tf
            echo "                          value = \"/keys.json\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GCP_BIGTABLE_INSTANCE\"" >> pods.tf
            echo "                          value = \"$gcp_bigtable_instance\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GCP_BIGTABLE_INDEX_TABLE\"" >> pods.tf
            echo "                          value = \"$gcp_bigtable_index_table\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GCP_BIGTABLE_COLUMN_FAMILY\"" >> pods.tf
            echo "                          value = \"$gcp_bigtable_column_family\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"COMMON_PAGE_CONTENT_COLUMN_NAME\"" >> pods.tf
            echo "                          value = \"$common_page_content_column_name\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    port {" >> pods.tf
            echo "                        container_port = 80" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                }" >> pods.tf
            echo "            }" >> pods.tf
            echo "        }" >> pods.tf
            echo "    }" >> pods.tf
            echo "}" >> pods.tf

            #SEARCH
                #revert to default value
                if [[ "$num_search_pods" = "" ]]
                then
                    num_search_pods="$default_num_search_pods"
                fi
            echo "resource \"kubernetes_deployment\" \"qse-search\" {" >> pods.tf
            echo "    metadata {" >> pods.tf
            echo "        name = \"qse-search\"" >> pods.tf
            echo "        labels = {" >> pods.tf
            echo "            App = \"qse-search\"" >> pods.tf
            echo "        }" >> pods.tf
            echo "    }" >> pods.tf
            echo "    spec {" >> pods.tf
            echo "        replicas = $num_search_pods" >> pods.tf
            echo "        strategy {" >> pods.tf
            echo "            type = \"RollingUpdate\"" >> pods.tf
            echo "            rolling_update {" >> pods.tf
            echo "                max_surge = $(( $num_search_pods + 1 ))" >> pods.tf
            echo "                max_unavailable = $num_search_pods" >> pods.tf
            echo "            }" >> pods.tf
            echo "        }" >> pods.tf
            echo "        selector {" >> pods.tf
            echo "            match_labels = {" >> pods.tf
            echo "                App = \"qse-search\"" >> pods.tf
            echo "            }" >> pods.tf
            echo "        }" >> pods.tf
            echo "        template {" >> pods.tf
            echo "            metadata{" >> pods.tf
            echo "                labels = {" >> pods.tf
            echo "                    App = \"qse-search\"" >> pods.tf
            echo "                }" >> pods.tf
            echo "            }" >> pods.tf
            echo "            spec {" >> pods.tf
            echo "                container {" >> pods.tf
            echo "                    image = \"$full_search_image_tag@$search_image_build_sha\"" >> pods.tf
            echo "                    name  = \"qse-search\"" >> pods.tf
            echo "                    resources {" >> pods.tf
            echo "                                limits {" >> pods.tf
            echo "                                  cpu    = \"0.5\"" >> pods.tf
            echo "                                  memory = \"256Mi\"" >> pods.tf
            echo "                                }" >> pods.tf
            echo "                                requests {" >> pods.tf
            echo "                                  cpu    = \"250m\"" >> pods.tf
            echo "                                  memory = \"50Mi\"" >> pods.tf
            echo "                                }" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"QSEPROVIDER\"" >> pods.tf
            echo "                          value = \"GCP\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GCP_PROJECT_ID\"" >> pods.tf
            echo "                          value = \"$gcp_proj_id\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GOOGLE_APPLICATION_CREDENTIALS\"" >> pods.tf
            echo "                          value = \"/keys.json\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GCP_BIGTABLE_INSTANCE\"" >> pods.tf
            echo "                          value = \"$gcp_bigtable_instance\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GCP_BIGTABLE_INDEX_TABLE\"" >> pods.tf
            echo "                          value = \"$gcp_bigtable_index_table\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GCP_BIGTABLE_COLUMN_FAMILY\"" >> pods.tf
            echo "                          value = \"$gcp_bigtable_column_family\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"COMMON_PAGE_CONTENT_COLUMN_NAME\"" >> pods.tf
            echo "                          value = \"$common_page_content_column_name\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GCP_BIGTABLE_ADS_TABLE\"" >> pods.tf
            echo "                          value = \"$gcp_bigtable_ads_table\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GCP_BIGTABLE_ADS_COLUMN_FAMILY\"" >> pods.tf
            echo "                          value = \"$gcp_bigtable_ads_column_family\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"COMMON_ADS_KEYWORDS_LIST_COLUMN_NAME\"" >> pods.tf
            echo "                          value = \"$common_ads_keywords_list_column_name\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"COMMON_ADS_IMAGE_COLUMN_NAME\"" >> pods.tf
            echo "                          value = \"$common_ads_image_column_name\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"COMMON_ADS_IMAGE_HEIGHT_COLUMN_NAME\"" >> pods.tf
            echo "                          value = \"$common_ads_image_height_column_name\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"COMMON_ADS_IMAGE_WIDTH_COLUMN_NAME\"" >> pods.tf
            echo "                          value = \"$common_ads_image_width_column_name\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"COMMON_ADS_IMAGE_MODE_COLUMN_NAME\"" >> pods.tf
            echo "                          value = \"$common_ads_image_mode_column_name\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"COMMON_IMAGE_FILE_PERSIST_SECONDS\"" >> pods.tf
            echo "                          value = \"$common_image_file_persist_seconds\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"COMMON_MAX_ADS_PER_PAGE\"" >> pods.tf
            echo "                          value = \"$common_max_ads_per_page\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    port {" >> pods.tf
            echo "                        container_port = 80" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                }" >> pods.tf
            echo "            }" >> pods.tf
            echo "        }" >> pods.tf
            echo "    }" >> pods.tf
            echo "}" >> pods.tf

            #registering LB for search
            echo "resource "kubernetes_service" "search_service" {" >> services.tf
            echo "  metadata {" >> services.tf
            echo "    name = \"search-service\"" >> services.tf
            echo "  }" >> services.tf
            echo "  spec {" >> services.tf
            echo "    selector = {" >> services.tf
            echo "      App = kubernetes_deployment.qse-search.spec.0.template.0.metadata[0].labels.App" >> services.tf
            echo "    }" >> services.tf
            echo "    port {" >> services.tf
            echo "      port        = 80" >> services.tf
            echo "      target_port = 80" >> services.tf
            echo "    }" >> services.tf
            echo "    type = \"LoadBalancer\"" >> services.tf
            echo "  }" >> services.tf
            echo "}" >> services.tf

            echo "output \"lb_ip_search\" {" >> services.tf
            echo "value = kubernetes_service.search_service.load_balancer_ingress[0]" >> services.tf
            echo "}" >> services.tf

            #ADS
                #revert to default value
                if [[ "$num_ads_pods" = "" ]]
                then
                    num_ads_pods="$default_num_ads_pods"
                fi
            echo "resource \"kubernetes_deployment\" \"qse-ads\" {" >> pods.tf
            echo "    metadata {" >> pods.tf
            echo "        name = \"qse-ads\"" >> pods.tf
            echo "        labels = {" >> pods.tf
            echo "            App = \"qse-ads\"" >> pods.tf
            echo "        }" >> pods.tf
            echo "    }" >> pods.tf
            echo "    spec {" >> pods.tf
            echo "        replicas = $num_ads_pods" >> pods.tf
            echo "        strategy {" >> pods.tf
            echo "            type = \"RollingUpdate\"" >> pods.tf
            echo "            rolling_update {" >> pods.tf
            echo "                max_surge = $(( $num_ads_pods + 1 ))" >> pods.tf
            echo "                max_unavailable = $num_ads_pods" >> pods.tf
            echo "            }" >> pods.tf
            echo "        }" >> pods.tf
            echo "        selector {" >> pods.tf
            echo "            match_labels = {" >> pods.tf
            echo "                App = \"qse-ads\"" >> pods.tf
            echo "            }" >> pods.tf
            echo "        }" >> pods.tf
            echo "        template {" >> pods.tf
            echo "            metadata{" >> pods.tf
            echo "                labels = {" >> pods.tf
            echo "                    App = \"qse-ads\"" >> pods.tf
            echo "                }" >> pods.tf
            echo "            }" >> pods.tf
            echo "            spec {" >> pods.tf
            echo "                container {" >> pods.tf
            echo "                    image = \"$full_ads_image_tag@$ads_image_build_sha\"" >> pods.tf
            echo "                    name  = \"qse-ads\"" >> pods.tf
            echo "                    resources {" >> pods.tf
            echo "                                limits {" >> pods.tf
            echo "                                  cpu    = \"0.5\"" >> pods.tf
            echo "                                  memory = \"256Mi\"" >> pods.tf
            echo "                                }" >> pods.tf
            echo "                                requests {" >> pods.tf
            echo "                                  cpu    = \"250m\"" >> pods.tf
            echo "                                  memory = \"50Mi\"" >> pods.tf
            echo "                                }" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"QSEPROVIDER\"" >> pods.tf
            echo "                          value = \"GCP\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GCP_PROJECT_ID\"" >> pods.tf
            echo "                          value = \"$gcp_proj_id\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GOOGLE_APPLICATION_CREDENTIALS\"" >> pods.tf
            echo "                          value = \"/keys.json\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GCP_BIGTABLE_INSTANCE\"" >> pods.tf
            echo "                          value = \"$gcp_bigtable_instance\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GCP_BIGTABLE_ADS_TABLE\"" >> pods.tf
            echo "                          value = \"$gcp_bigtable_ads_table\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"GCP_BIGTABLE_ADS_COLUMN_FAMILY\"" >> pods.tf
            echo "                          value = \"$gcp_bigtable_ads_column_family\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"COMMON_ADS_KEYWORDS_LIST_COLUMN_NAME\"" >> pods.tf
            echo "                          value = \"$common_ads_keywords_list_column_name\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"COMMON_ADS_IMAGE_COLUMN_NAME\"" >> pods.tf
            echo "                          value = \"$common_ads_image_column_name\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"COMMON_ADS_IMAGE_HEIGHT_COLUMN_NAME\"" >> pods.tf
            echo "                          value = \"$common_ads_image_height_column_name\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"COMMON_ADS_IMAGE_WIDTH_COLUMN_NAME\"" >> pods.tf
            echo "                          value = \"$common_ads_image_width_column_name\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"COMMON_ADS_IMAGE_MODE_COLUMN_NAME\"" >> pods.tf
            echo "                          value = \"$common_ads_image_mode_column_name\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"COMMON_IMAGE_FILE_PERSIST_SECONDS\"" >> pods.tf
            echo "                          value = \"$common_image_file_persist_seconds\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    env {" >> pods.tf
            echo "                          name = \"COMMON_MAX_ADS_PER_PAGE\"" >> pods.tf
            echo "                          value = \"$common_max_ads_per_page\"" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                    port {" >> pods.tf
            echo "                        container_port = 80" >> pods.tf
            echo "                    }" >> pods.tf
            echo "                }" >> pods.tf
            echo "            }" >> pods.tf
            echo "        }" >> pods.tf
            echo "    }" >> pods.tf
            echo "}" >> pods.tf

            #registering LB for ads
            echo "resource "kubernetes_service" "ads_service" {" >> services.tf
            echo "  metadata {" >> services.tf
            echo "    name = \"ads-service\"" >> services.tf
            echo "  }" >> services.tf
            echo "  spec {" >> services.tf
            echo "    selector = {" >> services.tf
            echo "      App = kubernetes_deployment.qse-ads.spec.0.template.0.metadata[0].labels.App" >> services.tf
            echo "    }" >> services.tf
            echo "    port {" >> services.tf
            echo "      port        = 80" >> services.tf
            echo "      target_port = 80" >> services.tf
            echo "    }" >> services.tf
            echo "    type = \"LoadBalancer\"" >> services.tf
            echo "  }" >> services.tf
            echo "}" >> services.tf
            echo "output \"lb_ip_ads\" {" >> services.tf
            echo "value = kubernetes_service.ads_service.load_balancer_ingress[0]" >> services.tf
            echo "}" >> services.tf


        echo "updating service account permissions to deploy from project's container image repository"
        gsutil iam ch serviceAccount:"$gcp_service_account@$gcp_proj_id.iam.gserviceaccount.com:objectViewer" "gs://artifacts.$gcp_proj_id.appspot.com"

        echo "attempting final apply to deploy pods as defined in pods.tf file"
        plan="qsedeployplan_$(deployment_id).out"

        if [[ "$sync_cluster" = "true" ]]
        then
            echo "waiting for resources to finish deleting after cluster sync..."
            sleep 60
        fi

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
