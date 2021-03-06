terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.53"
    }
  }

    backend "gcs" {
  }

}


provider "google" {
  project     = var.project_id
}


	

resource "google_compute_backend_service" "gke-backend-service" {
  provider = google-beta
  project = var.project_id
  name                            = "mci-n6lbuv-8080-zoneprinter-zone-mcs"
  enable_cdn                      = false
  connection_draining_timeout_sec = 10
  health_checks = ["projects/${var.project_id}/global/healthChecks/mci-n6lbuv-8080-zoneprinter-zone-mcs"]

  backend {
  group = "projects/${var.project_id}/zones/asia-southeast1-a/networkEndpointGroups/k8s1-4ffef35e-zoneprint-mci-zone-mcs-svc-lgq966x5m-808-e850700a"
  balancing_mode ="RATE"
  max_rate ="100"
  }

  backend {
  group = "projects/${var.project_id}/zones/us-central1-c/networkEndpointGroups/k8s1-a0e525b8-zoneprint-mci-zone-mcs-svc-lgq966x5m-808-d990f9ae"
  balancing_mode ="RATE"
  max_rate ="100"
  }

  security_policy = google_compute_security_policy.default.id
}


resource "google_compute_backend_service" "game-server-backend-service" {
  provider = google-beta
  project = var.project_id
  name                            = "game-server-backend-service"
  enable_cdn                      = false
  connection_draining_timeout_sec = 10

  backend {
  group = "projects/${var.project_id}/regions/asia-southeast1/networkEndpointGroups/game-server-asia-neg"
  }

  backend {
  group = "projects/${var.project_id}/regions/us-central1/networkEndpointGroups/game-server-us-neg"
  }

  custom_request_headers          = ["X-Client-Geo-Location: {client_region},{client_city}"]

  security_policy = google_compute_security_policy.default.id
}

resource "google_compute_backend_service" "game-client-backend-service" {
  provider = google-beta
  project = var.project_id
  name                            = "game-client-backend-service"
  enable_cdn                      = false
  connection_draining_timeout_sec = 10

  backend {
    group = "projects/${var.project_id}/regions/asia-southeast1/networkEndpointGroups/game-client-asia-neg"
  }

  backend {
    group = "projects/${var.project_id}/regions/us-central1/networkEndpointGroups/game-client-us-neg"
  }

  custom_request_headers          = ["X-Client-Geo-Location: {client_region},{client_city}"]

  security_policy = google_compute_security_policy.default.id
}

resource "google_compute_url_map" "http" {
  name            = "https-lb"
  default_service = google_compute_backend_service.gke-backend-service.id

  host_rule {
    hosts        = ["dronega.ga"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.gke-backend-service.id

    
      path_rule {
      paths   = ["/authServer"]
      service = google_compute_backend_service.game-server-backend-service.id
      
        route_action {
            url_rewrite {
            path_prefix_rewrite = "/server"
          }
        }
    
    }

          path_rule {
      paths   = ["/authServer/*"]
      service = google_compute_backend_service.game-server-backend-service.id
      
        route_action {
            url_rewrite {
            path_prefix_rewrite = "/server/"
          }
        }
    
    }

    path_rule {
      paths   = ["/client"]
      service = google_compute_backend_service.game-client-backend-service.id
      
    
    }

        path_rule {
      paths   = ["/client/*"]
      service = google_compute_backend_service.game-client-backend-service.id
      
    
    }

    path_rule {
      paths   = ["/server"]
      service = google_compute_backend_service.game-server-backend-service.id
      
        route_action {
            url_rewrite {
            path_prefix_rewrite = "/"
          }
        }
    
    }

    path_rule {
      paths   = ["/server/*"]
      service = google_compute_backend_service.game-server-backend-service.id
      
        route_action {
            url_rewrite {
            path_prefix_rewrite = "/"
          }
        }
    
    }

      path_rule {
      paths   = ["/test"]
      service = google_compute_backend_service.game-server-backend-service.id
    
    }




  }
}

# reserved ip

resource "google_compute_global_address" "static-ip" {
  provider = google-beta
  name = "dronegaga-static-ip"
}

resource "google_compute_global_forwarding_rule" "http-forwarding-rule" {
  name       = "http-forwarding-rule"
  target     = google_compute_target_http_proxy.default.id
  port_range = "80"
  ip_address = google_compute_global_address.static-ip.id
  load_balancing_scheme = "EXTERNAL"

}

resource "google_compute_global_forwarding_rule" "https-forwarding-rule" {
  name       = "https-forwarding-rule"
  target     = google_compute_target_https_proxy.default.id
  port_range = "443"
  ip_address = google_compute_global_address.static-ip.id
  load_balancing_scheme = "EXTERNAL"


}

resource "google_compute_target_http_proxy" "default" {
  name        = "http-target-proxy"
  url_map     = google_compute_url_map.http.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_https_proxy" "default" {
  name             = "https-target-proxy"
  url_map          = google_compute_url_map.http.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_managed_ssl_certificate" "default" {
  name = "ssl-cert-dronega"

  managed {
    domains = ["dronega.ga"]
  }
}



/* move to global infra only
resource "google_service_account" "cloudrun-sa" {
  account_id   = "cloudrun-sa"
  display_name = "cloudrun-sa"
}

resource "google_service_account_iam_member" "cloudrun-iam" {
  role               = "roles/run.serviceAgent"
  service_account_id = google_service_account.cloudrun-sa.name

  member = "serviceAccount:${google_service_account.cloudrun-sa.email}"
  
  depends_on = [google_service_account.cloudrun-sa]
}


*/

resource "google_compute_security_policy" "default" {
  name = "players-policy"

  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["223.25.71.191"]
      }
    }
  }

  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}