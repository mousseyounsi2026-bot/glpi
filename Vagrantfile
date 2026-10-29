# -*- mode: ruby -*-
# Labo GLPI 11 — Debian 12 + Apache + PHP 8.2 + MariaDB 10.11
# Usage : vagrant up   puis   http://localhost:8080  (glpi / glpi)

Vagrant.configure("2") do |config|
  config.vm.box      = "debian/bookworm64"
  config.vm.hostname = "glpi-lab"

  # Accès depuis l'hôte Windows
  config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"
  # Réseau privé : utile pour faire remonter l'inventaire d'autres VM (agent GLPI)
  config.vm.network "private_network", ip: "192.168.56.10"

  config.vm.provider "virtualbox" do |vb|
    vb.name   = "glpi-lab"
    vb.memory = 2048
    vb.cpus   = 2
  end

  config.vm.provision "shell", path: "provision.sh",
    env: { "GLPI_VERSION" => "11.0.4", "DB_PASS" => "Glpi-Lab-2026!" }
end
