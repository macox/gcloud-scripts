#!/usr/bin/env bash

# Bosh CLI
export bosh_cli_version=2.0.26
export bosh_cli=bosh-cli-${bosh_cli_version}-linux-amd64

# Get the project and zone
export project=$(gcloud config list 2> /dev/null | grep project | sed -e 's/project = //g')
export zone=$(gcloud config list 2> /dev/null | grep zone | sed -e 's/zone = //g')

# Define the service account and email
export service_account=bosh-director
export service_account_email=${service_account}@${project}.iam.gserviceaccount.com

# Install bosh cli
sudo curl -k -o /usr/local/bin/bosh https://s3.amazonaws.com/bosh-cli-artifacts/${bosh_cli}
sudo chmod +x /usr/local/bin/bosh

# Install bosh dependencies
sudo yum -y install git gcc gcc-c++ ruby ruby-devel mysql-devel postgresql-devel postgresql-libs sqlite-devel libxslt-devel libxml2-devel patch openssl
gem install yajl-ruby

# Create bosh director directory and clone bosh-deployment project
mkdir ${service_account} && cd ${service_account}
git clone https://github.com/cloudfoundry/bosh-deployment

# Create the service account
if [[ ! $(gcloud iam service-accounts list | grep ${service_account})  ]]; then
  gcloud iam service-accounts create ${service_account}
fi

# Assign necessary permissons to the bosh-user service account
if [[ ! -f ~/.ssh/${service_account} ]]; then
  gcloud projects add-iam-policy-binding ${project} \
    --member serviceAccount:${service_account_email} \
    --role roles/compute.instanceAdmin
  gcloud projects add-iam-policy-binding ${project} \
    --member serviceAccount:${service_account_email} \
    --role roles/compute.storageAdmin
  gcloud projects add-iam-policy-binding ${project} \
    --member serviceAccount:${service_account_email} \
    --role roles/storage.admin
  gcloud projects add-iam-policy-binding ${project} \
    --member serviceAccount:${service_account_email} \
    --role  roles/compute.networkAdmin
  gcloud projects add-iam-policy-binding ${project} \
    --member serviceAccount:${service_account_email} \
    --role roles/iam.serviceAccountActor

  ssh-keygen -t rsa -f ~/.ssh/${service_account} -C ${service_account}
  gcloud compute project-info add-metadata --metadata-from-file \
    sshKeys=<( gcloud compute project-info describe --format=json | jq -r '.commonInstanceMetadata.items[] | select(.key ==  "sshKeys") | .value' & echo "${service_account}:$(cat ~/.ssh/${service_account}.pub)" )
fi

# Get the key for the service account
if [ ! -f ${service_account_email}.key.json ]; then
  gcloud iam service-accounts keys create ${service_account_email}.key.json \
    --iam-account ${service_account_email}
fi

# Create bosh-director VM
bosh create-env bosh-deployment/bosh.yml \
    --state=director-state.json \
    --vars-store=creds.yml \
    -o bosh-deployment/gcp/cpi.yml \
    -v director_name=${service_account} \
    -v internal_cidr=10.0.0.0/24 \
    -v internal_gw=10.0.0.1 \
    -v internal_ip=10.0.0.6 \
    --var-file gcp_credentials_json=${service_account_email}.key.json \
    -v project_id=${project} \
    -v zone=${zone} \
    -v tags=[internal,no-ip] \
    -v network=default \
    -v subnetwork=default

