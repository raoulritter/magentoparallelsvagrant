Vagrant.configure("2") do |config|
  
  config.vm.box = "mpasternak/focal64-arm"
  config.vm.provision "file", source: "./start.sh", destination: "start.sh"
  config.ssh.insert_key = false
  config.vm.provider :parallels do |v|
        v.memory = "4096"
        v.cpus = 2
  end
  
end