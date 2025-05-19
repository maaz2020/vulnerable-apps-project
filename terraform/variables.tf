variable "location" {
  default = "East US"
}

variable "resource_group_name" {
  default = "devsecops-lab"
}

variable "vm_configs" {
  type = map(object({
    vm_name        = string
    vm_size        = string
    admin_username = string
    ssh_public_key = string
    public_ip      = bool
    open_ports     = list(number)
    script_path    = optional(string)
  }))

  default = {
    jenkins = {
      vm_name        = "jenkins-vm"
      vm_size        = "Standard_B1s"
      admin_username = "azureuser"
      ssh_public_key = "~/.ssh/azure_rsa.pub"
      script_path    = "../scripts/install_jenkins.sh" # Relative path from module
      public_ip      = true
      open_ports     = [22, 8080, 8081]
    },
    juiceshop = {
      vm_name        = "juiceshop-vm"
      vm_size        = "Standard_B2s"
      admin_username = "azureuser"
      ssh_public_key = "~/.ssh/azure_rsa.pub"
      script_path    = "../scripts/install_juiceshop.sh" # Relative path from module
      public_ip      = true
      open_ports     = [22, 3000]
    },
    sonarqube = {
      vm_name        = "sonarqube-vm"
      vm_size        = "Standard_B2ms"
      admin_username = "azureuser"
      ssh_public_key = "~/.ssh/azure_rsa.pub"
      script_path    = "../scripts/install_sonarqube.sh" # Relative path from module
      public_ip      = true
      open_ports     = [22, 9000]
    }
  }
}
