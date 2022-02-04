
variable "profile" {
  default = "datacoral"
}
variable "aws_region" {
  default = "us-west-2"
}
variable "vpc_name" {
  default = "datacoral-app-eks-vpc"
  type    = string
}
variable "eks_cluster_name" {
  default = "datacoral-app"
  type    = string
}