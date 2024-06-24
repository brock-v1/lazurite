output "extlb_ip" {
  value = azurerm_public_ip.extlb-ip.ip_address
}
output "vm1_ip" {
  value = azurerm_windows_virtual_machine.vm1.public_ip_address
}
output "vm1_pw" {
  sensitive = true
  value     = azurerm_windows_virtual_machine.vm1.admin_password
}
output "vm2_ip" {
  value = azurerm_windows_virtual_machine.vm2.public_ip_address
}
output "vm2_pw" {
  sensitive = true
  value     = azurerm_windows_virtual_machine.vm2.admin_password
}