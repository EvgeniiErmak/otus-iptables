# -*- mode: ruby -*-
# vi: set ft=ruby :
# ДЗ «Сценарии iptables»: inetRouter — centralRouter — centralServer + inetRouter2
# Сеть внутри ВМ настраивает Ansible (auto_config: false), Vagrant только создаёт адаптеры.

MACHINES = {
  inetRouter: {
    nets: [
      { ip: "192.168.255.1", netmask: "255.255.255.252", intnet: "router-net" }
    ]
  },
  centralRouter: {
    nets: [
      { ip: "192.168.255.2", netmask: "255.255.255.252", intnet: "router-net" },
      { ip: "192.168.0.1",   netmask: "255.255.255.240", intnet: "dir-net" },
      { ip: "192.168.255.5", netmask: "255.255.255.252", intnet: "router2-net" }
    ]
  },
  centralServer: {
    nets: [
      { ip: "192.168.0.2", netmask: "255.255.255.240", intnet: "dir-net" }
    ]
  },
  inetRouter2: {
    nets: [
      { ip: "192.168.255.6", netmask: "255.255.255.252", intnet: "router2-net" },
      { ip: "192.168.56.10", netmask: "255.255.255.0" }   # host-only, виден с хоста
    ]
  }
}

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"
  config.vm.box_check_update = false
  config.vm.synced_folder ".", "/vagrant", disabled: true

  MACHINES.each_with_index do |(name, cfg), idx|
    config.vm.define name do |box|
      box.vm.hostname = name.to_s

      cfg[:nets].each do |net|
        if net[:intnet]
          box.vm.network "private_network", ip: net[:ip], netmask: net[:netmask],
                         virtualbox__intnet: net[:intnet], auto_config: false
        else
          box.vm.network "private_network", ip: net[:ip], netmask: net[:netmask],
                         auto_config: false
        end
      end

      box.vm.provider "virtualbox" do |vb|
        vb.name   = "iptables-#{name}"
        vb.memory = 1024
        vb.cpus   = 1
      end

      # Ansible запускается один раз после подъёма последней ВМ — сразу на все хосты
      if idx == MACHINES.size - 1
        box.vm.provision "ansible" do |ansible|
          ansible.playbook           = "ansible/playbook.yml"
          ansible.limit              = "all"
          ansible.compatibility_mode = "2.0"
        end
      end
    end
  end
end
