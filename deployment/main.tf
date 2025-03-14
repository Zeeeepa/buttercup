terraform {
  required_version = ">=1.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "2.0.1"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.12.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
  }
}


provider "azurerm" {
  features {}
  # Use ambient Azure CLI credentials from az login
  # Not specifying client_id/client_secret when using Azure CLI authentication
}

#resource for random prefixes, helps with unique names and identifiers
resource "random_pet" "ssh_key_name" {
  prefix    = "ssh"
  separator = ""
}
#azapi_resource_action resource is used to perform specific actions on an Azure resource, such as starting or stopping a virtual machine. Here we're generating ssh keys
resource "azapi_resource_action" "ssh_public_key_gen" {
  type        = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  resource_id = azapi_resource.ssh_public_key.id
  action      = "generateKeyPair"
  method      = "POST"

  response_export_values = ["publicKey", "privateKey"]
}

resource "azapi_resource" "ssh_public_key" {
  type      = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  name      = random_pet.ssh_key_name.id
  location  = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id
}

output "key_data" {
  value = azapi_resource_action.ssh_public_key_gen.output.publicKey
}


# Generate random resource group name
resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  #ts:skip=AC_AZURE_0389 Locks not required
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

# Optional: Adds resource lock to prevent deletion of the RG. Requires additional configuration
#resource "azurerm_management_lock" "resource-group-level" {
#  name       = "resource-group-cannotdelete-lock"
#  scope      = azurerm_resource_group.rg.id
#  lock_level = "CanNotDelete"
#  notes      = "This Resource Group is set to CanNotDelete to prevent accidental deletion."
#}


resource "random_pet" "azurerm_kubernetes_cluster_name" {
  prefix = "cluster"
}

resource "random_pet" "azurerm_kubernetes_cluster_dns_prefix" {
  prefix = "dns"
}

resource "azurerm_kubernetes_cluster" "primary" {
  location            = azurerm_resource_group.rg.location
  name                = random_pet.azurerm_kubernetes_cluster_name.id
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = random_pet.azurerm_kubernetes_cluster_dns_prefix.id

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                         = "sys"
    vm_size                      = "Standard_D5_v2"
    max_pods                     = 100
    temporary_name_for_rotation  = "tempnodepool"
    only_critical_addons_enabled = true
    node_count                   = var.sys_node_count
    upgrade_settings {
      max_surge = "10%"
    }
  }

  linux_profile {
    admin_username = var.username

    ssh_key {
      key_data = azapi_resource_action.ssh_public_key_gen.output.publicKey
    }
  }
  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }
  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.aks_logs.id
    msi_auth_for_monitoring_enabled = true
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "usr"
  mode                  = "User"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.primary.id
  vm_size               = "Standard_D5_v2"
  max_pods              = 100
  node_count            = var.usr_node_count
  upgrade_settings {
    max_surge = "10%"
  }
}

#Monitoring Log Anayltics
resource "azurerm_log_analytics_workspace" "aks_logs" {
  name                = "${random_pet.rg_name.id}-logs"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

#
# Kubernetes Resources
#

data "azurerm_kubernetes_cluster" "primary" {
  name                = azurerm_kubernetes_cluster.primary.name
  resource_group_name = azurerm_kubernetes_cluster.primary.resource_group_name
}

# NOTE: The data block above is used to configure the kubernetes provider
# correctly, by adding a layer of indirectness. This is because of:
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs#stacking-with-managed-kubernetes-cluster-resources

# Configure both the Kubernetes and Helm providers to use the same AKS cluster credentials
provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.primary.kube_config[0].host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.primary.kube_config[0].client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.primary.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.primary.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.primary.kube_config[0].host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.primary.kube_config[0].client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.primary.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.primary.kube_config[0].cluster_ca_certificate)
  }
}

resource "kubernetes_namespace" "crs-ns" {
  metadata {
    name = "crs"
  }
  depends_on = [null_resource.setup_kubectl]
}

resource "kubernetes_secret" "ghcr_auth" {
  metadata {
    name      = "ghcr-auth"
    namespace = kubernetes_namespace.crs-ns.metadata.0.name
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      "auths" = {
        "https://ghcr.io" = {
          "auth" : base64encode("${var.github_username}:${var.github_pat}")
        }
      }
    })
  }
}


# Get AKS credentials and verify connectivity
resource "null_resource" "setup_kubectl" {
  depends_on = [azurerm_kubernetes_cluster.primary]

  provisioner "local-exec" {
    command = <<-EOT
      # Get credentials and verify connectivity
      echo "Getting AKS credentials..."
      az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.primary.name} --overwrite-existing
      
      echo "Verifying Kubernetes connectivity..."
      for i in {1..12}; do
        if kubectl cluster-info; then
          echo "Kubernetes cluster connectivity verified"
          exit 0
        fi
        echo "Waiting for Kubernetes API to become available... attempt $i"
        sleep 10
      done
      echo "Failed to connect to Kubernetes API after multiple attempts"
      exit 1
    EOT
  }
}


# TODO: Consider if we should use Azure Application Gateway for TLS Termination with AKS instead (remove Let's Encrypt)
# NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.crs-ns.metadata[0].name
  depends_on = [null_resource.setup_kubectl]

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-dns-label-name"
    value = "bc-test"
  }
  
  # Configure Azure Load Balancer to use the built-in /healthz endpoint
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }
  
  # Enable TLS termination in NGINX but allow HTTP for ACME challenges
  set {
    name  = "controller.config.ssl-redirect"
    value = "false"
  }
  
  # Add annotations to allow HTTP01 challenge
  set {
    name  = "controller.config.annotation-value-word-blocklist"
    value = ""
  }
}



# Install cert-manager for Let's Encrypt certificate handling
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = kubernetes_namespace.crs-ns.metadata[0].name
  depends_on = [null_resource.setup_kubectl]
  version    = "v1.14.4"

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# Wait for cert-manager to be fully deployed and CRDs to be established
resource "null_resource" "wait_for_cert_manager" {
  depends_on = [helm_release.cert_manager]
  
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for cert-manager deployments
      echo "Waiting for cert-manager deployments..."
      kubectl wait --for=condition=Available deployment/cert-manager -n ${kubernetes_namespace.crs-ns.metadata[0].name} --timeout=180s
      kubectl wait --for=condition=Available deployment/cert-manager-webhook -n ${kubernetes_namespace.crs-ns.metadata[0].name} --timeout=180s
      kubectl wait --for=condition=Available deployment/cert-manager-cainjector -n ${kubernetes_namespace.crs-ns.metadata[0].name} --timeout=180s
      
      # Wait for critical CRDs
      echo "Waiting for cert-manager CRDs..."
      kubectl wait --for=condition=established crd/clusterissuers.cert-manager.io --timeout=60s
      kubectl wait --for=condition=established crd/certificates.cert-manager.io --timeout=60s
    EOT
  }
}

# Create the appropriate ClusterIssuer based on the environment variable
resource "null_resource" "create_cluster_issuer" {
  depends_on = [null_resource.wait_for_cert_manager]
  
  provisioner "local-exec" {
    command = <<-EOT
      # Create the selected ClusterIssuer
      cat << EOF | kubectl apply -f -
      apiVersion: cert-manager.io/v1
      kind: ClusterIssuer
      metadata:
        name: ${local.cluster_issuer_name}
      spec:
        acme:
          server: ${var.use_production_certificates ? "https://acme-v02.api.letsencrypt.org/directory" : "https://acme-staging-v02.api.letsencrypt.org/directory"}
          email: ${var.email_address}
          privateKeySecretRef:
            name: ${local.cluster_issuer_name}-account-key
          solvers:
          - http01:
              ingress:
                class: nginx
      EOF
      
      # Wait for the ClusterIssuer to be ready
      echo "Waiting for ClusterIssuer ${local.cluster_issuer_name} to be ready..."
      kubectl wait --for=condition=Ready clusterissuer/${local.cluster_issuer_name} --timeout=60s
    EOT
  }
}

# Set local variables for certificate configuration
locals {
  cluster_issuer_name = var.use_production_certificates ? "letsencrypt-production" : "letsencrypt-staging"
  certificate_domain = "bc-test.${azurerm_resource_group.rg.location}.cloudapp.azure.com"
}


resource "kubernetes_ingress_v1" "app_ingress" {
  metadata {
    name = "bc-test-ingress"
    namespace = kubernetes_namespace.crs-ns.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/cluster-issuer" = local.cluster_issuer_name
      "nginx.ingress.kubernetes.io/ssl-redirect" = "false"
    }
  }

  spec {
    tls {
      hosts = [local.certificate_domain]
      secret_name = "bc-test-tls-secret"
    }
    
    rule {
      host = local.certificate_domain
      http {
        path {
          path = "/"
          path_type = "Prefix"
          
          backend {
            service {
              name = "task-server"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.nginx_ingress,
    helm_release.buttercup,
    null_resource.create_cluster_issuer
  ]
}

