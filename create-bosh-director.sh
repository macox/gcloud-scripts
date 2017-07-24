#!/usr/bin/env bash

# Assumes you're already logged into GCP and have initialized local config, i.e.
# gcloud auth login
# gcloud init

# Also assumes you've installed the BOSH CLI
# ./install-bosh-cli.sh

# Clone the bosh-deployment project
git clone https://github.com/cloudfoundry/bosh-deployment

# Get the name and username for the 'jumpbox' VM
DEFAULT_JUMPBOX="jumpbox"
read -p "Enter the name of the VM to use as a 'jumpbox' ($DEFAULT_JUMPBOX): " JUMPBOX
JUMPBOX=${JUMPBOX:-$DEFAULT_JUMPBOX}

# Get the GCP project and zone
PROJECT=$(gcloud config list 2> /dev/null | grep project | sed -e 's/project = //g')
ZONE=$(gcloud config list 2> /dev/null | grep zone | sed -e 's/zone = //g')

# Get the IP Address of the 'jumpbox' VM
JUMPBOX_IP=$(gcloud compute instances describe ${JUMPBOX} --zone=${ZONE} \
    | grep 'natIP:' \
    | sed -e 's/natIP://g' \
    | sed -e 's/^[[:space:]]*//' \
    | sed -e 's/[[:space:]]*$//')

# Add SSH config for the 'jumpbox' VM
sudo bash -c "echo '# Start ${JUMPBOX} SSH config
Host ${JUMPBOX}
  Hostname ${JUMPBOX_IP}
  IdentityFile /home/vagrant/.ssh/${JUMPBOX}
  ForwardAgent yes
  User ${JUMPBOX}
# End ${JUMPBOX} SSH config
' >> ~/.ssh/config"

cat ~/.ssh/config

# Launch a SOCKS proxy and verify it's running
ssh -D 5000 -fqCN ${JUMPBOX} && \
    ps -ef | grep ssh

# Tell BOSH to use the SOCKS proxy
export BOSH_ALL_PROXY=socks5://localhost:5000

# Define a GCP Service Account for BOSH
BOSH_SERVICE_ACCOUNT=bosh-director
BOSH_SERVICE_ACCOUNT_EMAIL=${BOSH_SERVICE_ACCOUNT}@${PROJECT}.iam.gserviceaccount.com

# Create the BOSH Service Account
if [[ ! $(gcloud iam service-accounts list | grep ${BOSH_SERVICE_ACCOUNT})  ]]; then
    gcloud iam service-accounts create ${BOSH_SERVICE_ACCOUNT} --display-name=${BOSH_SERVICE_ACCOUNT}
fi

# Assign the BOSH Service Account the 'Compute Instance Admin v1' (roles/compute.instanceAdmin.v1) and
# 'Service Account User' (roles/iam.serviceAccountUser) IAM roles
if [[ ! -f ~/.ssh/${BOSH_SERVICE_ACCOUNT} ]]; then
    gcloud projects add-iam-policy-binding ${PROJECT} \
        --member serviceAccount:${BOSH_SERVICE_ACCOUNT_EMAIL} \
        --role roles/compute.instanceAdmin.v1
    gcloud projects add-iam-policy-binding ${PROJECT} \
        --member serviceAccount:${BOSH_SERVICE_ACCOUNT_EMAIL} \
        --role roles/iam.serviceAccountUser

    ssh-keygen -t rsa -f ~/.ssh/${BOSH_SERVICE_ACCOUNT} -C ${BOSH_SERVICE_ACCOUNT} -q -N ""
    #gcloud compute project-info add-metadata --metadata-from-file \
    #    sshKeys=<( gcloud compute project-info describe --format=json | jq -r '.commonInstanceMetadata.items[] select(.key ==  "sshKeys") .value' & echo "${BOSH_SERVICE_ACCOUNT}:$(cat ~/.ssh/${BOSH_SERVICE_ACCOUNT}.pub)" )
fi

# Get the key for the BOSH Service Account
if [ ! -f ${BOSH_SERVICE_ACCOUNT_EMAIL}.key.json ]; then
    gcloud iam service-accounts keys create ${BOSH_SERVICE_ACCOUNT_EMAIL}.key.json \
        --iam-account ${BOSH_SERVICE_ACCOUNT_EMAIL}
fi

# Create the BOSH Director VM
bosh create-env bosh-deployment/bosh.yml \
  --state=state.json \
  --vars-store=creds.yml \
  -o bosh-deployment/gcp/cpi.yml \
  -o bosh-deployment/jumpbox-user.yml \
  -v director_name=bosh-director \
  -v internal_cidr=10.154.0.0/20 \
  -v internal_gw=10.154.0.1 \
  -v internal_ip=10.154.0.3 \
  --var-file gcp_credentials_json=./${BOSH_SERVICE_ACCOUNT_EMAIL}.key.json \
  -v project_id=${PROJECT} \
  -v zone=${ZONE} \
  -v tags=[internal] \
  -v network=default \
  -v subnetwork=default

export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh int ./creds.yml --path /admin_password`

bosh alias-env bosh-director -e 10.154.0.3 --ca-cert <(bosh int ./creds.yml --path /director_ssl/ca)

bosh -e bosh-director env
