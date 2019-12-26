#!/bin/bash

terraform_type=""
terraform_class=""
terraform_log_name=""
output_file=""
started="False"

bad_exit(){
    echo "Error generating terraform object template via terrabuilder.sh"
    exit 1
}

case $1 in

    "--out"
        output_file="$2"
        ;;

    "--type")
        terraform_type="$2"
        ;;

    "--class")
        terraform_class="$2"
        ;;
    "--log-name")
        terraform_log_name="$2"
        ;;

    *)
        #use cases valid?
        if ([[ "$terraform_type" != "" ]] && [[ "$terraform_class" != "" ]] && [[ "$terraform_log_name" != "" ]]) || ([[ "$terraform_type" = "variable" ]] && [[ "$terraform_log_name" != "" ]])
        then
            #appending to already started job?
            if [[ "$started" = "True" ]]
            then
                #then...

            else
                #else...
                if [[ "$terraform_type" = "variable" ]] && [[ "$terraform_log_name" != "" ]]
                then
                    #then...

                else
                    #else...

            fi

        else
            #else...

        fi
