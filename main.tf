terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "europe-west8"
}

variable "project_id" {
  type        = string
  description = "Идентификатор вашего проекта в GCP"
}

# Инстанс виртуальной машины для Jenkins
resource "google_compute_instance" "jenkins" {
  name         = "jenkins-server"
  machine_type = "e2-micro"
  zone         = "europe-west8-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-13"
      size  = 20                      
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Автоматическое назначение внешнего IP-адреса
    }
  }

  # Передача вашего стартового скрипта установки Jenkins
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e

    marker_file="/var/lib/jenkins-install.done"
    if [ -f "$marker_file" ]; then
      echo "Jenkins installation already completed; skipping."
      exit 0
    fi

    sudo apt update && sudo apt install fontconfig openjdk-21-jre -y
    sudo wget -O /usr/share/keyrings/jenkins-keyring.gpg https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt update
    sudo apt install jenkins -y

    sudo touch "$marker_file"
  EOT

  tags = ["jenkins-server"]
}

# Правило файрвола для доступа к веб-интерфейсу Jenkins (порт 8080)
resource "google_compute_firewall" "jenkins_web" {
  name    = "allow-jenkins-8080"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["jenkins-server"]
}

# Вывод итоговой ссылки для подключения
output "jenkins_url" {
  value       = "http://${google_compute_instance.jenkins.network_interface[0].access_config[0].nat_ip}:8080"
  description = "URL для доступа к Jenkins"
}