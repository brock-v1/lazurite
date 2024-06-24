locals {
  # Get first two characters of the location
  location_short = substr(var.location, 0, 2)
}