# ------------------------------------------------------------------------------
# LAUNCH A POSTGRES CLUSTER WITH HA AND READ REPLICAS
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# CONFIGURE OUR GCP CONNECTION
# ------------------------------------------------------------------------------

provider "google-beta" {
  version     = "~> 2.7.0"
  credentials = file("creds.json")
  project     = var.project
  region      = var.region
}


provider "google" {
  credentials = file("creds.json")
  project     = var.project
  region      = var.region
}


terraform {
  # The modules used in this example have been updated with 0.12 syntax, which means the example is no longer
  # compatible with any versions below 0.12.
  required_version = ">= 0.12"
}

# ------------------------------------------------------------------------------
# CREATE A RANDOM SUFFIX AND PREPARE RESOURCE NAMES
# ------------------------------------------------------------------------------

resource "random_id" "name" {
  byte_length = 2
}

locals {
  # If name_override is specified, use that - otherwise use the name_prefix with a random string
  instance_name        = var.name_override == null ? format("%s-%s", var.name_prefix, random_id.name.hex) : var.name_override
  private_network_name = "private-network-${random_id.name.hex}"
  private_ip_name      = "private-ip-${random_id.name.hex}"
}

# ------------------------------------------------------------------------------
# CREATE COMPUTE NETWORKS
# ------------------------------------------------------------------------------

# Simple network, auto-creates subnetworks
resource "google_compute_network" "private_network" {
  provider = "google-beta"
  name     = local.private_network_name
}

# Reserve global internal address range for the peering
resource "google_compute_global_address" "private_ip_address" {
  provider      = "google-beta"
  name          = local.private_ip_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.private_network.self_link
}

# Establish VPC network peering connection using the reserved address range
resource "google_service_networking_connection" "private_vpc_connection" {
  provider                = "google-beta"
  network                 = google_compute_network.private_network.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# ------------------------------------------------------------------------------
# CREATE DATABASE CLUSTER WITH PRIVATE IP
# ------------------------------------------------------------------------------

module "postgres" {

  source = "./modules/cloud-sql-postgres"

  project = var.project
  region  = var.region
  name    = local.instance_name
  db_name = var.db_name

  engine       = var.postgres_version
  machine_type = var.machine_type

  master_zone = var.master_zone

  enable_public_internet_access = false

  # Indicate that we want to create a failover replica
  enable_failover_replica = true

  # Indicate we want read replicas to be created
  num_read_replicas  = var.num_read_replicas
  read_replica_zones = var.read_replica_zones

  # These together will construct the master_user privileges, i.e.
  # 'master_user_name' IDENTIFIED BY 'master_user_password'.
  # These should typically be set as the environment variable TF_VAR_master_user_password, etc.
  # so you don't check these into source control."
  master_user_password = var.master_user_password
  master_user_name     = var.master_user_name

  # Pass the private network link to the module
  private_network = google_compute_network.private_network.self_link

  # Wait for the vpc connection to complete
  dependencies = [google_service_networking_connection.private_vpc_connection.network]


  custom_labels = {
    test-id = "postgres-replicas-example"
  }
}