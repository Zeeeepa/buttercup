# Terraform configuration for deploying Buttercup Helm chart to Kubernetes
# Uses the Kubernetes provider configuration from main.tf

# Helm release for the Buttercup application
resource "helm_release" "buttercup" {
  name       = "buttercup"
  chart      = "${path.module}/k8s"
  namespace  = kubernetes_namespace.crs-ns.metadata[0].name
  depends_on = [null_resource.setup_kubectl]
  timeout    = 900  # 15 minutes timeout
  
  # Use values from the values.yaml file
  values = [
    file("${path.module}/k8s/values.yaml")
  ]
  
  # Scale up build-bot resources significantly
  set {
    name  = "build-bot.replicaCount"
    value = "8"
  }
  
  set {
    name  = "build-bot.resources.limits.cpu"
    value = "4000m"  # 4 vCPU cores
  }
  
  set {
    name  = "build-bot.resources.limits.memory"
    value = "8Gi"    # 8GB memory
  }
  
  set {
    name  = "build-bot.resources.requests.cpu"
    value = "1000m"  # 1 vCPU cores
  }
  
  set {
    name  = "build-bot.resources.requests.memory"
    value = "4Gi"    # 4GB memory
  }
  
  # Also increase resources for the Docker in Docker sidecar
  set {
    name  = "build-bot.dind.resources.limits.cpu"
    value = "8000m"  # 8 vCPU cores
  }
  
  set {
    name  = "build-bot.dind.resources.limits.memory"
    value = "8Gi"    # 8GB memory
  }
  
  set {
    name  = "build-bot.dind.resources.requests.cpu"
    value = "2000m"  # 2 vCPU cores
  }
  
  set {
    name  = "build-bot.dind.resources.requests.memory"
    value = "4Gi"    # 4GB memory
  }
  
  # Global settings for all services
  set {
    name  = "global.environment"
    value = "aks"
  }
  
  # Configure Azure storage classes for persistent volumes
  set {
    name  = "volumes.tasks_storage.storageClass"
    value = "azurefile-csi"
  }
  
  set {
    name  = "volumes.tasks_storage.size"
    value = "10Gi"
  }
  
  set {
    name  = "volumes.crs_scratch.storageClass"
    value = "azurefile-csi"
  }
  
  set {
    name  = "volumes.crs_scratch.size"
    value = "20Gi"
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
  
  # Scale up task-downloader
  set {
    name  = "task-downloader.replicaCount"
    value = "2"     # Increase from 1 to 2 instances
  }
  
  set {
    name  = "task-downloader.resources.limits.cpu"
    value = "2000m"  # 2 vCPU cores
  }
  
  set {
    name  = "task-downloader.resources.limits.memory"
    value = "3Gi"    # 3GB memory
  }
  
  set {
    name  = "task-downloader.resources.requests.cpu"
    value = "500m"   # Initial CPU request
  }
  
  set {
    name  = "task-downloader.resources.requests.memory"
    value = "1Gi"    # Initial memory request
  }
  
  # Scale fuzzer-bot resources based on available cluster capacity
  # Current cluster capacity can support about 8 fuzzer instances
  set {
    name  = "fuzzer-bot.replicaCount"
    value = "8"     # Reduced from 12 to prevent Pending pods
  }
  
  set {
    name  = "fuzzer-bot.resources.limits.cpu"
    value = "500m"   # 0.5 vCPU for orchestration
  }
  
  set {
    name  = "fuzzer-bot.resources.limits.memory"
    value = "1Gi"    # 1GB memory for orchestration
  }
  
  set {
    name  = "fuzzer-bot.resources.requests.cpu"
    value = "100m"   # Reduced to 0.1 vCPU baseline
  }
  
  set {
    name  = "fuzzer-bot.resources.requests.memory"
    value = "512Mi"  # 512MB baseline
  }
  
  # Allocate most resources to Docker-in-Docker sidecar where the actual fuzzing happens
  set {
    name  = "fuzzer-bot.dind.resources.limits.cpu"
    value = "3000m"  # 3 vCPU cores per instance for fuzzing
  }
  
  set {
    name  = "fuzzer-bot.dind.resources.limits.memory"
    value = "8Gi"    # 8GB memory per instance for fuzzing
  }
  
  set {
    name  = "fuzzer-bot.dind.resources.requests.cpu"
    value = "1200m"  # Reduced to 1.2 cores per instance
  }
  
  set {
    name  = "fuzzer-bot.dind.resources.requests.memory"
    value = "4Gi"    # Reserve 4GB memory per instance
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