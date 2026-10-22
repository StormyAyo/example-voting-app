output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.voting.name
}

output "cluster_endpoint" {
  description = "EKS Kubernetes API endpoint"
  value       = aws_eks_cluster.voting.endpoint
}

output "aws_region" {
  description = "AWS region hosting the cluster"
  value       = var.aws_region
}

output "vpc_id" {
  description = "Default VPC used by the cluster"
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "Subnets used by the cluster"
  value       = data.aws_subnets.default.ids
}