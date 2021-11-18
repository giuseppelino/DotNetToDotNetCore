#!/bin/bash
set -e

#
# This script will configure a GCP project to run the sample application
# by enabling the required APIs and permissions required.  It will also
# create an RSA key pair for JWT token signing and store as secrets.
#

PROJECT_ID=`gcloud config list --format 'value(core.project)' 2>/dev/null`
PROJECT_NUMBER=`gcloud projects describe $PROJECT_ID --format="value(projectNumber)"`
SA_NAME=eventssample-sa
SERVICE_ACCOUNT="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"
BUILD_SERVICE_ACCOUNT="$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"

# Ensure gcloud has run and configured access to a project.
[[ -z "$PROJECT_ID" ]] && { echo "ERROR: Please ensure gcloud init has run prior." ; exit 1; }

#
# Enable required cloud service apis
#
# //Tip: to get all available roles by 'name':
# gcloud iam roles list --format="value(name)"
#
echo 'Enabling required cloud apis...'
declare -a apis=("compute.googleapis.com"
    "cloudbuild.googleapis.com"
    "artifactregistry.googleapis.com"
    "secretmanager.googleapis.com"
    "run.googleapis.com"
    "pubsub.googleapis.com"
    "firestore.googleapis.com"
    )
for api in "${apis[@]}"
do
gcloud services enable $api
done

#
# Assign permissions required for the cloud build service account
#
echo 'Assigning roles to Cloud Build service account...'
declare -a build_roles=("roles/run.admin"
    "roles/artifactregistry.admin"
    )
for role in "${build_roles[@]}"
do
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:$BUILD_SERVICE_ACCOUNT \
    --role=$role
done

#
# Create a service account that will run the app and assign required permissions
#
echo 'Creating a service account to run the app...'
gcloud iam service-accounts create $SA_NAME

echo 'Assigning roles to the service account...'
declare -a sa_roles=("roles/secretmanager.secretAccessor"
    "roles/pubsub.editor"
    "roles/datastore.user"
    )
for role in "${sa_roles[@]}"
do
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:$SERVICE_ACCOUNT \
    --role=$role
done

#
# Create an RSA key pair and save as secrets.
# 
echo 'Creating an RSA key pair for JWT token signing...'
PRIVATE_KEY=private-key.pem
PUBLIC_KEY=public-key.pem

# generate a private key with the correct length
openssl genrsa -out $PRIVATE_KEY 3072

# generate corresponding public key
openssl rsa -in $PRIVATE_KEY -pubout -out $PUBLIC_KEY

# store in secret manager
echo 'Storing RSA key pair for JWT token signing in secret manager...'

gcloud secrets create PrivateJwtKey --data-file=$PRIVATE_KEY

gcloud secrets create PubilcJwtKey --data-file=$PUBLIC_KEY

echo 'DONE'