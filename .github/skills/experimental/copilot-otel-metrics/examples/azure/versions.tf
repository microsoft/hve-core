terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }

  # backend.tf is intentionally absent. Remote state configuration belongs to
  # the repository that consumes this template, not to the template itself.
}

provider "azurerm" {
  features {}
}

provider "azapi" {}
