module "network" {
  source = "./modules/network"
  
  env                  = var.env
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "security" {
  source               = "./modules/security"

  env                  = var.env
  vpc_id               = module.network.vpc_id
  allowed_inbound_cidr = "0.0.0.0/0"
}