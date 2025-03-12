# Terraform configuration for deploying Buttercup Helm chart to Kubernetes
# Uses the Kubernetes provider configuration from main.tf

# Helm release for the Buttercup application
resource "helm_release" "buttercup" {
  name       = "buttercup"
  chart      = "${path.module}/k8s"
  namespace  = kubernetes_namespace.crs-ns.metadata[0].name
  depends_on = [azurerm_kubernetes_cluster.primary]
  
  # Use values from the values.yaml file
  values = [
    file("${path.module}/k8s/values.yaml")
  ]
  
  # Global settings for all services
  set {
    name  = "global.environment"
    value = "azure"
  }
  
  # Langfuse configuration
  set {
    name  = "global.langfuse.enabled"
    value = var.langfuse_enabled
  }
  
  set {
    name  = "global.langfuse.host"
    value = var.langfuse_host
  }
  
  set {
    name  = "global.langfuse.publicKey"
    value = var.langfuse_public_key
  }
  
  set {
    name  = "global.langfuse.secretKey"
    value = var.langfuse_secret_key
  }
  
  # Task server configuration
  dynamic "set" {
    for_each = length(var.task_server_loadbalancer_source_ranges) > 0 ? [1] : []
    content {
      name  = "task-server.service.loadBalancerSourceRanges"
      value = "{${join(",", var.task_server_loadbalancer_source_ranges)}}"
    }
  }
  
  # LiteLLM configuration
  set {
    name  = "litellm.masterKey"
    value = var.litellm_master_key
  }
  
  set {
    name  = "litellm.openai.apiKey"
    value = var.openai_api_key
  }
  
  set {
    name  = "litellm.anthropic.apiKey"
    value = var.anthropic_api_key
  }
  
  set {
    name  = "litellm.azure.apiBase"
    value = var.azure_openai_api_base
  }
  
  set {
    name  = "litellm.azure.apiKey"
    value = var.azure_openai_api_key
  }
  
  # LiteLLM helm chart configuration
  set {
    name  = "litellm-helm.nameOverride"
    value = "litellm"
  }
  
  set {
    name  = "litellm-helm.volumes"
    value = "null"
  }
}