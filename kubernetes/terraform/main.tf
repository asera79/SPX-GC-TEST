terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.31.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = "demo"
  }
}

resource "kubernetes_persistent_volume_claim" "this" {
  metadata {
    name = "spx-volume-claim"
    namespace = "demo"
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_secret" "openssh" {
  metadata {
    name = "openssh-secret"
    namespace = "demo"
    labels = {
      app = "openssh"
    }
  }

  data = {
    publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDKwvQ00IdvcL3C5XlT6ia8znKx9z0XAMB2uDOCJZfeodNVQMkUbv3AYn6uzoTuYGGUugjzLQTLaAFcqzrYO2BXGT6Oku5Brs7gIfuloSg85YtUT7DmSBMBYG1swf5QUMd5855UfEe4bZi19D778UkK2t3ULCdtG2DdOp16Ci1U4r5HAbo7gGeQai9P1dzA24CnIhU0EzrJTFf1gKl9qr+aX8kCTeD5HCVJrO1tFu8Izsm642YjLvG9BPd8WTNl6QsytUNL9+g+ezbD3GKx+zKMXrdaCTeyUFQszqaADNalssihUAKFLydVnTNeLAikquMh7d8OvIBvJqZDCbMV6ppNY5hb/rkJXa6XRE794eR2j8+PzUjoi9LN/UAm4rpA0WhYMY4FAz/iTR14EHGU0l0VAaL9nDSV3NMCw0pg8GwSF4F5Xocnsusxk9jNqtLa1ErzbU/RkcZJfX8muC79pJ2gQaQnmMZ64FBCmzZG0w1KtALPVhVruuVrDko8J7LceW8= asera@Sergeys-MacBook-Pro-2.local"
  }

  type = "Opaque"
}

resource "kubernetes_deployment" "this" {
  metadata {
    name = "spx-backend"
    namespace = "demo"
    labels = {
      app = "spx-backend"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "spx-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "spx-app"
        }
      }      

      spec {

        security_context {
          fs_group = 1000
        }

        container {
          name = "spxgc"
          image = "asera79/spxgc:latest"
          image_pull_policy = "Always"
          
          security_context {
            run_as_user = 1000
            run_as_group = 1000
          }
          
          port {
            container_port = 5656
          }

          volume_mount {
            name = "spx-volume"
            mount_path = "/usr/src/app/ASSETS"
            sub_path = "data/ASSETS"
          }

          volume_mount {
            name = "spx-volume"
            mount_path = "/usr/src/app/DATAROOT"
            sub_path = "data/DATAROOT"
          }
        }

        container {
          name = "openssh"
          image = "linuxserver/openssh-server:latest"
          image_pull_policy = "Always"
          port {
            container_port = 2222
          }
          env {
            name = "USER_NAME"
            value = "demo"
          }
          env {
            name = "PUID"
            value = "1000"
          }
          env {
            name = "PGID"
            value = "1000"
          }
          env {
            name = "PUBLIC_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.openssh.metadata[0].name
                key = "publicKey"
              }
            }
          }
          volume_mount {
            name = "spx-volume"
            mount_path = "/data"
            sub_path = "data"
          }
          volume_mount {
            name = "spx-volume"
            mount_path = "/config"
            sub_path = "openssh"
          }
        }

        volume {
          name = "spx-volume"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.this.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "spx_gc" {
  metadata {
    name = "spx-gc"
    namespace = "demo"
    annotations = {
      "cloud.google.com/neg" = "{\"exposed_ports\": { \"80\": { \"name\": \"spx-demo-neg\"} }}"
    }
  }

  spec {
    selector = {
      app = "spx-app"
    }

    port {
      port = 8080
      target_port = 5656
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_service" "openssh" {
  metadata {
    name = "openssh"
    namespace = "demo"
  }

  spec {
    selector = {
      app = "spx-app"
    }

    port {
      port = 2222
      target_port = 2222
    }

    type = "LoadBalancer"
  }
}