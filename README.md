# gcp-terraform-postgres

## Example postgres terraform module in gcp

Created a postgres instance with different setting in gcp's Cloud SQL.
Postgres module can be configured to be standalone, HA, with read replication, with private ot public network.

In this example we create the private network outside the module.

# Setup

## Create server account for terraform

    gcloud iam service-accounts create <SERVICE_ACCOUNT_NAME>

### Assigned roles - these are a general set of roles


    gcloud projects add-iam-policy-binding <PROJECT_NAME> --member "serviceAccount:<SERVICE_ACCOUNT_NAME>@<PROJECT_NAME>.iam.gserviceaccount.com" --role "roles/compute.instanceAdmin.v1"
    
    gcloud projects add-iam-policy-binding <PROJECT_NAME> --member "serviceAccount:<SERVICE_ACCOUNT_NAME>@<PROJECT_NAME>.iam.gserviceaccount.com" --role "roles/compute.networkAdmin"
    
    gcloud projects add-iam-policy-binding <PROJECT_NAME> --member "serviceAccount:<SERVICE_ACCOUNT_NAME>@<PROJECT_NAME>.iam.gserviceaccount.com" --role "roles/compute.securityAdmin"
    
    gcloud projects add-iam-policy-binding <PROJECT_NAME> --member "serviceAccount:<SERVICE_ACCOUNT_NAME>@<PROJECT_NAME>.iam.gserviceaccount.com" --role "roles/compute.storageAdmin"
    
    gcloud projects add-iam-policy-binding <PROJECT_NAME> --member "serviceAccount:<SERVICE_ACCOUNT_NAME>@<PROJECT_NAME>.iam.gserviceaccount.com" --role "roles/iam.serviceAccountAdmin"
    
    gcloud projects add-iam-policy-binding <PROJECT_NAME> --member "serviceAccount:<SERVICE_ACCOUNT_NAME>@<PROJECT_NAME>.iam.gserviceaccount.com" --role "roles/resourcemanager.projectIamAdmin"
    
    gcloud projects add-iam-policy-binding <PROJECT_NAME> --member "serviceAccount:<SERVICE_ACCOUNT_NAME>@<PROJECT_NAME>.iam.gserviceaccount.com" --role "roles/storage.admin"
    
    gcloud projects add-iam-policy-binding <PROJECT_NAME> --member "serviceAccount:<SERVICE_ACCOUNT_NAME>@<PROJECT_NAME>.iam.gserviceaccount.com" --role "roles/cloudsql.admin"


### To run locally simply get the credentials for the service account

    gcloud iam service-accounts keys create ./creds.json --iam-account <SERVICE_ACCOUNT_NAME>@<PROJECT_NAME>.iam.gserviceaccount.com

### Create a tfvars file and populate required variables

###  Run terraform init -> plan -> apply 

Enjoy :) 

