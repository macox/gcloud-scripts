#!/usr/bin/env bash

# BOSH CLI version
export bosh_cli_version=2.0.26
export bosh_cli=bosh-cli-${bosh_cli_version}-linux-amd64

# Download and install the BOSH CLI
sudo curl -k -o /usr/local/bin/bosh https://s3.amazonaws.com/bosh-cli-artifacts/${bosh_cli}
sudo chmod +x /usr/local/bin/bosh

# Install BOSH dependencies
sudo yum -y install \
    git \
    gcc \
    gcc-c++ \
    libxml2-devel \
    libxslt-devel \
    mysql-devel \
    openssl \
    patch \
    postgresql-devel \
    postgresql-libs \
    ruby \
    ruby-devel \
    sqlite-devel

gem install yajl-ruby

# Demonstrate the BOSH CLI has installed correctly
bosh -version
