output "public_ip" {
    value = google_compute_address.public_ip.address
}