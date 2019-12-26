#!/bin/bash

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

#build config from args
case "$1" in

    "--help")
        #todo: help text
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

#todo: validate vars

############### end vars and config capture

############### start helper functions

#builds new gcp config and points config vars to file
make_new_gcp_creds(){
#TODO: figure out if feasible and do it, by this point project already exists
}

############### end helper functions

############### start main flow
#todo: onto building terraform

#TODO: ALL PROJECT SETUP FOR GCP, LOGIC INCOMPLETE AND MAY BE BROKEN AS IS SO MAY NEED FULL REWRITE
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
    then #TODO: move this clause out to validation section
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
        if [[ "$gcp_use_existing_key_json" != "True" ]] #TODO: validate for case where no key given --> SET CREATE CREDS TO FIRE WHEN KEY NOT PASSED IN AND DROP CREATE CREDS BOOL VAR
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
