
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A CLOUD SQL POSTGRES CLUSTER 
# This module deploys a Cloud SQL Postgres cluster. The cluster is managed by Google and automatically handles leader
# election, replication, failover, backups, patching, and encryption.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

locals {
  # Calculate actuals, so we get expected behavior for each engine
  actual_availability_type      = var.enable_failover_replica ? "REGIONAL" : "ZONAL"
}

# ------------------------------------------------------------------------------
# CREATE THE MASTER INSTANCE
#
# NOTE: We have multiple google_sql_database_instance resources, based on
# HA and replication configuration options.
# ------------------------------------------------------------------------------

resource "google_sql_database_instance" "master" {
  depends_on = [null_resource.dependency_getter]

  provider         = "google-beta"
  name             = var.name
  project          = var.project
  region           = var.region
  database_version = var.engine

  settings {
    tier                        = var.machine_type
    activation_policy           = var.activation_policy
    authorized_gae_applications = var.authorized_gae_applications
    disk_autoresize             = var.disk_autoresize

    ip_configuration {
      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = lookup(authorized_networks.value, "name", null)
          value = authorized_networks.value.value
        }
      }

      ipv4_enabled    = var.enable_public_internet_access
      private_network = var.private_network
      require_ssl     = var.require_ssl
    }

    location_preference {
      follow_gae_application = var.follow_gae_application
      zone                   = var.master_zone
    }

    backup_configuration {
      binary_log_enabled = false
      enabled            = var.backup_enabled
      start_time         = var.backup_start_time
    }

    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = var.maintenance_track
    }

    disk_size         = var.disk_size
    disk_type         = var.disk_type
    availability_type = local.actual_availability_type

    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = database_flags.value.name
        value = database_flags.value.value
      }
    }

    user_labels = var.custom_labels
  }

  # Default timeouts are 10 minutes, which in most cases should be enough.
  # Sometimes the database creation can, however, take longer, so we
  # increase the timeouts slightly.
  timeouts {
    create = var.resource_timeout
    delete = var.resource_timeout
    update = var.resource_timeout
  }
}

# ------------------------------------------------------------------------------
# CREATE A DATABASE
# ------------------------------------------------------------------------------

resource "google_sql_database" "default" {
  depends_on = [google_sql_database_instance.master]

  name      = var.db_name
  project   = var.project
  instance  = google_sql_database_instance.master.name
  charset   = var.db_charset
  collation = var.db_collation
}

resource "google_sql_user" "default" {
  depends_on = [google_sql_database.default]

  project  = var.project
  name     = var.master_user_name
  instance = google_sql_database_instance.master.name
  host     = null
  password = var.master_user_password
}

# ------------------------------------------------------------------------------
# SET MODULE DEPENDENCY RESOURCE
# This works around a terraform limitation where we can not specify module dependencies natively.
# See https://github.com/hashicorp/terraform/issues/1178 for more discussion.
# By resolving and computing the dependencies list, we are able to make all the resources in this module depend on the
# resources backing the values in the dependencies list.
# ------------------------------------------------------------------------------

resource "null_resource" "dependency_getter" {
  provisioner "local-exec" {
    command = "echo ${length(var.dependencies)}"
  }
}

# ------------------------------------------------------------------------------
# CREATE THE READ REPLICAS
# ------------------------------------------------------------------------------

resource "google_sql_database_instance" "read_replica" {
  count = var.num_read_replicas

  depends_on = [
    google_sql_database_instance.master,
    google_sql_database.default,
    google_sql_user.default,
  ]

  provider         = "google-beta"
  name             = "${var.name}-read-${count.index}"
  project          = var.project
  region           = var.region
  database_version = var.engine

  # The name of the instance that will act as the master in the replication setup.
  master_instance_name = google_sql_database_instance.master.name

  replica_configuration {
    # Specifies that the replica is not the failover target.
    failover_target = false
  }

  settings {
    tier                        = var.machine_type
    authorized_gae_applications = var.authorized_gae_applications
    disk_autoresize             = var.disk_autoresize

    ip_configuration {
      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.value
        }
      }

      ipv4_enabled    = var.enable_public_internet_access
      private_network = var.private_network
      require_ssl     = var.require_ssl
    }

    location_preference {
      follow_gae_application = var.follow_gae_application
      zone                   = element(var.read_replica_zones, count.index)
    }

    disk_size = var.disk_size
    disk_type = var.disk_type

    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = database_flags.value.name
        value = database_flags.value.value
      }
    }

    user_labels = var.custom_labels
  }

  # Read replica creation is initiated concurrently, but the provider creates
  # the resources sequentially. Therefore we increase the timeouts considerably
  # to allow successful creation of multiple read replicas without having to
  # fear the operation timing out.
  timeouts {
    create = var.resource_timeout
    delete = var.resource_timeout
    update = var.resource_timeout
  }
}

# ------------------------------------------------------------------------------
# CREATE A TEMPLATE FILE TO SIGNAL ALL RESOURCES HAVE BEEN CREATED
# ------------------------------------------------------------------------------

data "template_file" "complete" {
  depends_on = [
    google_sql_database_instance.master,
    google_sql_database_instance.read_replica,
    google_sql_database.default,
    google_sql_user.default,
  ]

  template = true
}