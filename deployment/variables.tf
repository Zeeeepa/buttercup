variable "github_username" {
  type        = string
  description = "The username for the GitHub account."
  default     = "USERNAME"
  sensitive   = true
}

variable "github_pat" {
  type        = string
  description = "The personal access token (PAT) for the GitHub account."
  sensitive   = true
}

variable "resource_group_location" {
  type        = string
  default     = "eastus"
  description = "Location of the resource group."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "example"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "sys_node_count" {
  type        = number
  description = "The initial quantity of nodes for the node pool."
  default     = 2
}

variable "usr_node_count" {
  type        = number
  description = "The initial quantity of nodes for the node pool."
  default     = 3
}

variable "username" {
  type        = string
  description = "The admin username for the new cluster."
  default     = "azureadmin"
}

variable "litellm_master_key" {
  type        = string
  description = "The master key for LiteLLM"
  sensitive   = true
}

variable "openai_api_key" {
  type        = string
  description = "The API key for OpenAI"
  sensitive   = true
}

variable "anthropic_api_key" {
  type        = string
  description = "The API key for Anthropic"
  sensitive   = true
}

variable "azure_openai_api_key" {
  type        = string
  description = "The API key for Azure OpenAI"
  sensitive   = true
}

variable "azure_openai_api_base" {
  type        = string
  description = "The API base URL for Azure OpenAI"
  sensitive   = true
}

variable "langfuse_enabled" {
  type        = bool
  description = "Whether to enable Langfuse integration"
  default     = false
}

variable "langfuse_host" {
  type        = string
  description = "The host URL for Langfuse"
  default     = "https://langfuse.gateway.trailofbits.com/"
}

variable "langfuse_public_key" {
  type        = string
  description = "The public key for Langfuse"
  sensitive   = true
  default     = ""
}

variable "langfuse_secret_key" {
  type        = string
  description = "The secret key for Langfuse"
  sensitive   = true
  default     = ""
}

variable "task_server_loadbalancer_source_ranges" {
  type        = list(string)
  description = "List of CIDR blocks that can access the task server"
  default     = []
}
