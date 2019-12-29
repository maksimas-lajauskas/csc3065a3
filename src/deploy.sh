#!/bin/bash

#### FLOW - GCP ONLY:
#1. Collect and validate data
#2. Ensure gcloud is pointing to project id passed in the args or fail with message
#3. If asking for a new service account to be created create one, else use credentials given
#3.1. If creating -> create, verify with `gcloud list`, assign role and save credentials json
### account created by using:
#```
# gcloud iam service-accounts create [SA-NAME] \
#    --description "[SA-DESCRIPTION]" \
#        --display-name "[SA-DISPLAY-NAME]"
#```
# on success will output "Created service account [SA-NAME]"
### role is added by using (more likely):
#```
# gcloud projects add-iam-policy-binding $gcp_proj_id \
#  --member serviceAccount:$gcp_service_account_name@$gcp_proj_id.iam.gserviceaccount.com \
#    --role roles/$new_role
#```
### or role is added by using (less likely, probably this only assigns e.g. jane@example.com ownership of servAcc):
#```
# gcloud iam service-accounts add-iam-policy-binding \
#  my-sa-123@my-project-123.iam.gserviceaccount.com \
#    --member='user:jane@example.com' --role='roles/editor'
#```
#not sure which, if either or if both, first one to work sticks
### json is retrieved via gcloud as such (manually check json file if all works okay):
#```
# gcloud iam service-accounts get-iam-policy \
#  my-sa-123@my-project-123.iam.gserviceaccount.com \
#    --format json > policy.json
#````
# where policy.json is the expected output path&filename
### /FLOW

############### start vars and config capture
#vars - common
provider=""
varfile="tfvars.tf"
tfpath=""

#vars - gcp
gcp_proj_id=""
gcp_region=""
gcp_use_existing_key_json="False"
gcp_key_json=""
gcp_billing_account=""
gcp_try_create_project="False"
gcp_service_account_name=""

#build config from args
case "$1" in

    "--help")
        #!!!TODO!!!: help text
        echo "Sorry fam, you're on your own here lol"
        exit 0
        ;;

    "--provider")
        case "$2" in

                "gcp")
                    #echo "provider: gcp"
                    provider="$2"
                    ;;

                "aws")
                    #echo "provider: aws"
                    provider="$2"
                    ;;

                "azure")
                    #echo "provider: azure"
                    provider="$2"
                    ;;

                *)
                    echo "provider $2 not recognised"
                    exit 1
                    ;;

        esac
        ;;

    "--project-id")
        #echo "project id: $2"
        gcp_proj_id="$2"
        ;;

    "--project-name")
        #echo "project name: $2"
        gcp_proj_name="$2"
        ;;

    "--region")
        #echo "region: $2"
        gcp_region="$2"
        ;;

    "--billing-account")
        #echo "billing account: $2"
        gcp_billing_account="$2"
        ;;

    "--create-project")
        #echo "create project"
        gcp_try_create_project="True"
        ;;

    "--creds-file")
        gcp_use_existing_key_json="True"
        gcp_key_json="$2"
        ;;

    *)
        echo "argument $1 not recognised, try running with '--help' option"
        exit 1
        ;;

esac

#!!!TODO!!!: validate vars, DEPENDS ON: all vars (for at least one provider) being defined with expected values and combinations

############### end vars and config capture

############### start helper functions

#builds new gcp config and points config vars to file
make_new_gcp_creds(){
#!!!TODO!!!: figure out if feasible and do it, by this point project already exists, DEPENDS ON: research
}

############### end helper functions

############### start main flow
#!!!TODO!!!: onto building terraform

#!!!TODO!!!: ALL PROJECT SETUP FOR GCP, LOGIC INCOMPLETE AND MAY BE BROKEN AS IS SO MAY NEED FULL REWRITE. DEPENDS ON: R&D
#set up project
if [[ "$provider" = "gcp"  ]]
then
#do gcp set up
    #creating project resource and have billing account?
    if [[ "$gcp_try_create_project" = "True" ]] && [[ "$gcp_billing_account" != "" ]]
    then
        #create project ...

    #creating but no billing account? notify and exit
    elif [[ "$gcp_try_create_project" = "True" ]]
    then
        #!!!TODO!!!: move this clause out to validation section, DEPENDS ON: flow and vars being established
        echo "Create project $gcp_proj_id $gcp_proj_name  requested but no billing account given"
        exit 1

    #not creating - billing account irrelevant
    fi
        #set up path
        tfpath="$(pwd)/tf-$provider"

        #write project name variable
        echo "variable \"gcp_proj_id\"{" >> $tfpath/$varfile
        echo -e "\tdefault = $gcp_proj_id" >> $tfpath/$varfile
        echo "}" >> $tfpath/$varfile

        #write credentials file variable
            #using existing credentials? if not, call creds helper function
        if [[ "$gcp_use_existing_key_json" != "True" ]]
        #!!!TODO!!!: validate for case where no key given --> SET CREATE CREDS TO FIRE WHEN KEY NOT PASSED IN AND DROP CREATE CREDS BOOL VAR, DEPENDS ON: flow&vars
        then
            make_new_gcp_creds()

        fi

        echo "variable \"gcp_key_json\"{" >> $tfpath/$varfile
        echo -e "\tdefault = \${file(\"$gcp_key_json\")}" >> $tfpath/$varfile
        echo "}" >> $tfpath/$varfile

        #write region variable
        echo "variable \"gcp_region\"{" >> $tfpath/$varfile
        echo -e "\tdefault = $gcp_region" >> $tfpath/$varfile
        echo "}" >> $tfpath/$varfile

        #setup done, initialise terraform in $tfpath and kick off engine
        cd $tfpath && terraform init  && terraform plan -out=qsedeployplan.out && terraform apply

#finish gcp set up

elif [[ "$provider" = "aws" ]]
then
#do aws set up

#finish aws set up

elif [[ "$provider" = "azure" ]]
then
#do azure set up

#finish azure set up

fi
############### end main flow
