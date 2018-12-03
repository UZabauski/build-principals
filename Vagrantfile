BOX_IMAGE = "sbeliakou/centos"
NODE_COUNT = 3

Vagrant.configure("2") do |config|
	(1..NODE_COUNT).each do |i|
     	config.vm.define "jenkins-#{i}" do |subconfig|
       		subconfig.vm.box = BOX_IMAGE
       		subconfig.vm.hostname = "jenkins-#{i}"
       		subconfig.vm.network :private_network, ip: "192.168.170.#{i + 100}"
       		subconfig.vm.provision 'shell', path: "script.sh", args:"#{i}" 
       		subconfig.vm.provider "virtualbox" do |vb|
	 			vb.memory = "1024"
	 			vb.name = "jenkins-#{i}"
	 		end
	 	end
	end
end
