variable landingzone {
  default = {
    backend_type = "azurerm"
    tfstates = {
      launchpad = {
        level   = "lower"
        tfstate = "terraform.tfstate"
      }
    }
  }
}

data "terraform_remote_state" "remote" {
  for_each = try(var.landingzone.tfstates, {})

  backend = var.landingzone.backend_type
  config = {
    storage_account_name = "tfstorageaccdev"
    container_name       = "tstate-dev-cont"
    resource_group_name  = "agp-tf-rg"
    subscription_id      = "249a3bf8-18cc-4f88-ab0e-77e87f943d8c"
    key                  = each.value.tfstate
  }
}

