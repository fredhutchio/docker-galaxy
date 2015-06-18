# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.network "private_network", ip: "192.168.33.20"
  config.vm.hostname = "web.galaxy.dev"

  # config.vm.synced_folder ".", "/vagrant", type: :nfs
  # config.bindfs.bind_folder "/vagrant", "/vagrant",
  #                           chown_ignore: true,
  #                           chgrp_ignore: true

  config.vm.provider "virtualbox" do |v|
    v.memory = 2048
  end

  # add postgresql-client
  config.vm.provision "docker", images: ["ubuntu:14.04", "postgres:9.3"]
  config.vm.provision "shell", inline: "usermod -a -G docker vagrant"
end
