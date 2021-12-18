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



resource "google_compute_backend_service" "game-server-backend-service" {
  provider = google-beta
  project = var.project_id
  name                            = "game-server-backend-service"
  enable_cdn                      = true
  connection_draining_timeout_sec = 10

  backend {
  group = "projects/${var.project_id}/regions/asia-southeast1/networkEndpointGroups/game-server-asia-neg"
  }

  backend {
  group = "projects/${var.project_id}/regions/us-central1/networkEndpointGroups/game-server-us-neg"
  }


}

resource "google_compute_backend_service" "game-client-backend-service" {
  provider = google-beta
  project = var.project_id
  name                            = "game-client-backend-service"
  enable_cdn                      = true
  connection_draining_timeout_sec = 10

  backend {
    group = "projects/${var.project_id}/regions/asia-southeast1/networkEndpointGroups/game-client-asia-neg"
  }

  backend {
    group = "projects/${var.project_id}/regions/us-central1/networkEndpointGroups/game-client-us-neg"
  }
}



resource "google_compute_url_map" "http" {
  name            = "test"
  default_service = google_compute_backend_service.game-client-backend-service.id

  host_rule {
    hosts        = ["dronega.ga"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.game-client-backend-service.id

    path_rule {
      paths   = ["/client"]
      service = google_compute_backend_service.game-client-backend-service.id
    }

        path_rule {
      paths   = ["/server"]
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
}

resource "google_compute_global_forwarding_rule" "https-forwarding-rule" {
  name       = "https-forwarding-rule"
  target     = google_compute_target_https_proxy.default.id
  port_range = "443"
}

resource "google_compute_target_http_proxy" "default" {
  name        = "http-target-proxy"
  url_map     = google_compute_url_map.http.id
}

resource "google_compute_target_https_proxy" "default" {
  name             = "test-proxy"
  url_map          = google_compute_url_map.http.id
  ssl_certificates = [google_compute_ssl_certificate.default.id]
}

resource "google_compute_managed_ssl_certificate" "default" {
  name = "ssl-cert-dronega"

  managed {
    domains = ["dronega.ga"]
  }
}