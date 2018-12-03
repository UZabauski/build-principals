# -*- mode: ruby -*-
# vi: set ft=ruby :
nubmer_of_nodes=2

Vagrant.configure("2") do |config|
    config.vm.define "default" do |default|
        default.vm.box = "sbeliakou/centos"
        default.vm.network "private_network", ip: "192.168.56.88"
        default.vm.provider "virtualbox" do |v|
          v.memory = 3072
        end
        default.vm.provision "shell", path: "install_jenkins.sh", privileged: false
    end
    config.vm.define "sonar" do |default|
        default.vm.box = "sbeliakou/centos"
        default.vm.network "private_network", ip: "192.168.56.80"
        default.vm.provider "virtualbox" do |v|
          v.memory = 3072
        end
        default.vm.provision "shell", path: "install_sonar.sh", privileged: false
    end
    # (1..nubmer_of_nodes).each do |i|
    # config.vm.define "node_#{i}" do |node|
        # node.vm.box = "sbeliakou/centos"
        # node.vm.provider "virtualbox" do |v|
            # v.name = "jenkins_slave_#{i}"
        # end
        # node.vm.network "private_network", ip: "192.168.56.9#{i}"
        # node.vm.provision "shell", path: "install_jenkins_node.sh", privileged: false
        # node.vm.provision "file", source: "id_rsa.pub", destination: "autorized_keys"
    # end
end
