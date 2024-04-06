#Persistent minecraft disk
resource "google_compute_disk" "minecraft" {
  name  = "minecraft"
  type  = "pd-standard"
  zone  = var.zone
  image = "cos-cloud/cos-stable"
}

resource "google_compute_network" "minecraft" {
    name = "minecraft"
    auto_create_subnetworks = false
}

resource "google_compute_address" "public_ip" {
    name = "minecraft-public-ip"
}

resource "google_compute_subnetwork" "minecraft-subnet" {
    name = "minecraft-subnet"
    ip_cidr_range = "10.0.0.0/24"
    network = google_compute_network.minecraft.id
}

resource "google_compute_instance" "minecraft" {
  name         = "minecraft"
  machine_type = "n1-standard-1"
  zone         = var.zone
  tags         = ["minecraft"]

  # Run itzg/minecraft-server docker image on startup
  # The instructions of https://hub.docker.com/r/itzg/minecraft-server/ are applicable
  # For instance, Ssh into the instance and you can run
  #  docker logs mc
  #  docker exec -i mc rcon-cli
  # Once in rcon-cli you can "op <player_id>" to make someone an operator (admin)
  # Use 'sudo journalctl -u google-startup-scripts.service' to retrieve the startup script output
  metadata_startup_script = "docker run -d -p 25565:25565 -e EULA=TRUE -e VERSION=1.12.2 -v /var/minecraft:/data --name mc -e TYPE=FORGE -e FORGEVERSION=14.23.0.2552 -e MEMORY=2G --rm=true itzg/minecraft-server:latest;"

  metadata = {
    enable-oslogin = "TRUE"
    ssh-keys="gallo:${file("C:/Users/gallo/.ssh/id_rsa.pub")}"
  }
      
  boot_disk {
    auto_delete = false # Keep disk after shutdown (game data)
    source      = google_compute_disk.minecraft.self_link
  }

  network_interface {
    network = google_compute_network.minecraft.name
    subnetwork = google_compute_subnetwork.minecraft-subnet.name

    access_config {
      nat_ip = google_compute_address.public_ip.address
    }
  }

  scheduling {
    preemptible       = true # Closes within 24 hours (sometimes sooner)
    automatic_restart = false
  }
}

resource "google_compute_firewall" "minecraft" {
  name    = "minecraft"
  network = google_compute_network.minecraft.name
  # Minecraft client port
  allow {
    protocol = "tcp"
    ports    = ["25565"]
  }
  # ICMP (ping)
  allow {
    protocol = "icmp"
  }
  # SSH (for RCON-CLI access)
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["minecraft"]
}