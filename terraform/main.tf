# 1. Network Module
module "network" {
  source               = "./modules/network"
  env                  = "prod"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  availability_zones   = ["eu-west-1a", "eu-west-1b"]
}

# 2. Security Module
module "security" {
  source               = "./modules/security"
  env                  = "prod"
  vpc_id               = module.network.vpc_id
  allowed_inbound_cidr = "0.0.0.0/0"
}

# 3. Compute Module (Cross-Wired with Network & Security)
module "compute" {
  source                = "./modules/compute"
  env                   = "prod"
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  private_subnet_ids    = module.network.private_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  ec2_security_group_id = module.security.ec2_security_group_id
  
  # Configuration parameters
  ami_id                = "ami-06b9219be654efe2b" 
  instance_type         = "t3.micro"
  iam_instance_profile  = "EC2-SSM-Role" 
  
  asg_min_size          = 1
  asg_max_size          = 3
  asg_desired_capacity  = 2
}