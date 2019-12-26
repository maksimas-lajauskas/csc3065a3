#!/bin/bash

#expected args count
num_args=2

#args count check
if [[ $# -lt "$num_args" ]]
then
    echo "Not enough args man"
    exit 1
fi

#vars
gcp-proj-id=""


#build config from args
case "$1" in

    "--provider")
        case "$2" in

                "gcp")
                    echo "provider: gcp"
                    ;;

                "aws")
                    echo "provider: aws"
                    ;;

                "azure")
                    echo "provider: azure"
                    ;;

                *)
                    echo "provider $2 not recognised"
                    exit 1
                    ;;

        esac
        ;;

    "--project-id")
        echo "project id: $2"
        proj-id="$2"
        ;;

    *)
        echo "argument $1 not recognised, try running with '--help' option"
        exit 1
        ;;

esac

#todo: check if gcloud project exists else create
