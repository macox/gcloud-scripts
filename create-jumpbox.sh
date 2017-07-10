#!/usr/bin/env bash

# Get the project and zone
export project=$(gcloud config list 2> /dev/null | grep project | sed -e 's/project = //g')
export zone=$(gcloud config list 2> /dev/null | grep zone | sed -e 's/zone = //g')

# Define the vm name
export vm_name=jumpbox

# Create the VM 
gcloud compute \
  --project "${project}" \
  instances create ${vm_name} \
    --zone "${zone}" \
    --machine-type "g1-small" \
    --subnet "default" \
    --maintenance-policy "MIGRATE" \
    --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
    --image "centos-7-v20170620" \
    --image-project "centos-cloud" \
    --boot-disk-size "10" \
    --boot-disk-type "pd-standard" \
    --boot-disk-device-name ${vm_name}

