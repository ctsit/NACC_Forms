#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
REDCAP_ZIP=$1
SHARED_FOLDER=/vagrant

# Jessie's docroot 
# Note: Squeeze had it as /var/www
DOC_ROOT=/var/www/html

# import helper functions
. $SHARED_FOLDER/bootstrap_functions.sh

install_prereqs
install_redcap
check_redcap_status
install_utils

install_prereqs_project_creator
