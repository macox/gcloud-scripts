#!/usr/bin/env bash

# Get the project and zone
export project=$(gcloud config list 2> /dev/null | grep project | sed -e 's/project = //g')
export zone=$(gcloud config list 2> /dev/null | grep zone | sed -e 's/zone = //g')

gcloud compute ssh --project ${project} --zone ${zone} "jumpbox"

