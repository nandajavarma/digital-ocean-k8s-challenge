# Deploy the actual Kubernetes cluster
resource "digitalocean_kubernetes_cluster" "kubernetes_cluster" {
  name    = "do-challenge-cluster"
  region  = "fra1"
  version = "1.21.5-do.0"

  tags = ["gitops-k8s-challenge"]

  node_pool {
    name       = "nodepool-k8s-challenge"
    size       = "s-2vcpu-2gb"
    auto_scale = true
    min_nodes  = 1
    max_nodes  = 4
    tags       = ["default-node-pool"]
    labels = {
      "app"      = "gitops"
      "priority" = "high"
    }
  }
}

output "kubeconfig" {
  value       = digitalocean_kubernetes_cluster.kubernetes_cluster.kube_config.0.raw_config
  sensitive   = true
  description = "Kubeconfig of the kubernetes cluster"
}
