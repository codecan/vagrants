# To change these, do:
# export CHEF_VAR1=foo
# export CHEF_VAR2=bar
ENV['CHEF_ORGANIZATION'] ||= ENV['USER']
ENV['CHEF_USERNAME'] ||= ENV['USER']
ENV['CHEF_ACCOUNT_URL'] ||= 'https://www.opscode.com'
ENV['CHEF_API_URL'] ||= 'https://api.opscode.com'
ENV['CHEF_MANAGE_URL'] ||= 'https://manage.opscode.com'
ENV['CHEF_API_ENDPOINT'] ||= "#{ENV['CHEF_API_URL']}/organizations/#{ENV['CHEF_ORGANIZATION']}/"
ENV['CHEF_VALIDATOR_KEY'] ||= ".chef/#{ENV['CHEF_ORGANIZATION']}-validator.pem"
ENV['CHEF_VALIDATOR_NAME'] ||= "#{ENV['CHEF_ORGANIZATION']}-validator"

classc='1.1.1'
        
if ENV['CHEF_SERVER_LOCAL']
    chef_server_ip = "#{classc}.10"
    ENV['CHEF_API_ENDPOINT'] = "https://#{chef_server_ip}"
    ENV['CHEF_VALIDATOR_KEY'] = ".chef/chef-validator.pem"
    ENV['CHEF_VALIDATOR_NAME'] = "chef-validator"
end

if not ::File.exists? ".chef/#{ENV['CHEF_ORGANIZATION']}-validator.pem" and not ENV['CHEF_SERVER_LOCAL']
  saved_env = ENV.to_hash
  ENV.reject! {|k,v| k =~ /GEM/} # we don't want vagrant GEM vars
  # ensure we are using our Gemfile
  if not ::File.exists? "vendor/gems"
    system("/opt/chef/embedded/bin/bundle install --path vendor/gems")
  end
  # knife setup our org
  cmd = "/opt/chef/embedded/bin/bundle exec knife setup #{ENV['CHEF_ORGANIZATION']} \
    --username #{ENV['CHEF_USERNAME']} \
    --key .chef/#{ENV['CHEF_USERNAME']}.pem \
    --account-url #{ENV['CHEF_ACCOUNT_URL']} \
    --api-server-url #{ENV['CHEF_API_URL']} \
    --manage-url #{ENV['CHEF_MANAGE_URL']} \
    --validation_key .chef/#{ENV['CHEF_ORGANIZATION']}-validator.pem"
  # use password variable if available
  cmd += " --password '#{ENV['CHEF_PASSWORD']}'" if ENV['CHEF_PASSWORD']
  # show CHEF_* vars and the cmd we will run... will prompt for password if not given
  puts ENV.select{|k,v| k =~ /^CHEF/}
  puts cmd
  system(cmd)
  # update the generated knife.rb to find our chef-repo
  open('.chef/knife.rb','a') do |f|
      f.write('cookbook_path "#{current_dir}/../chef-repo/cookbooks"')
      f.write("\n")
      f.write('cache_options(:path => "#{ENV[\'HOME\']}/.chef/checksums")')
      f.write("\n")
  end
  # upload everything from the chef-repo
  system('/opt/chef/embedded/bin/bundle exec knife upload /')
  # restore the ENV
  ENV.update saved_env
end

node_names = Dir.glob('chef-repo/roles/*-node.json').map{|x|File.basename(x).sub('-node.json','')}

Vagrant.configure("2") do |config|
  config.omnibus.chef_version = '11.6.0'
  config.vm.box_url = "https://opscode-vm-bento.s3.amazonaws.com/vagrant/opscode_centos-6.4_provisionerless.box"
  config.vm.box = "opscode_centos-6.4_provisionerless"

  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    vb.customize ["modifyvm", :id, "--cpus","2"]
  end

  if ENV['CHEF_SERVER_LOCAL']
    forwarded_port = 4443
    # Another alternative that creates a chef-server 
    config.vm.define 'chef-server' do |chef_server|
      chef_server.vm.network :private_network, ip: chef_server_ip
      chef_server.vm.network :forwarded_port, guest: 443, host: forwarded_port
      
      # install the knife-server gem, if gem list doesn't include it
      chef_server.vm.provision :shell,
      :inline => "/opt/chef/embedded/bin/gem list | grep knife-server || \
        /opt/chef/embedded/bin/gem install knife-server"
      
      # install the knife-essentials gem, if gem list doesn't include it
      chef_server.vm.provision :shell,
      :inline => "/opt/chef/embedded/bin/gem list | grep knife-essentials || \
        /opt/chef/embedded/bin/gem install knife-essentials"
      
      # install chef-server with knife-server gem if the chef-server-ctl command isn't there
      chef_server.vm.provision :shell,
      :inline => "chef-server-ctl status || \
        /opt/chef/bin/knife server bootstrap standalone \
        --node-name #{chef_server_ip} --host localhost \
        --webui-enable \
        --ssh-user vagrant --ssh-password vagrant && \
        ln -sf /opt/chef/bin/knife /usr/bin/knife"

      # symlink /root/chef-repo to our repo and update knife.rb to it
      chef_server.vm.provision :shell,
      :inline => "ls -d /vagrant/chef-repo/ && ln -sf /vagrant/chef-repo /root/ ;\
        grep cookbook_path /root/.chef/knife.rb ||
        echo \"\ncookbook_path '/root/chef-repo/cookbooks'\" >> /root/.chef/knife.rb"
      
      # if our knife.rb includes a repo, upload everything!
      chef_server.vm.provision :shell,
      :inline => "grep cookbook_path /root/.chef/knife.rb && \
         /opt/chef/bin/knife upload /"
    
      # copy out the keys for everyone else: will be avaliable via \
      # https://chef-server/docs/{knife.rb,admin.pem,chef-validator.pem}
      chef_server.vm.provision :shell,
        :inline => "mkdir -p /opt/chef-server/docs ; \
        cp -av /root/.chef/* /etc/chef-server/chef-validator.pem /opt/chef-server/docs/"
      
      # on vagrant-virtualbox we can just put this local in our /vagrant/chef dir
      chef_server.vm.provision :shell,
      :inline => "mkdir -p /vagrant/.chef ; \
        cp -av /root/.chef/root.pem /etc/chef-server/chef-validator.pem /vagrant/.chef/"

      chef_server.vm.provision :shell,
      :inline => "echo 'current_dir = File.dirname(__FILE__)' > /vagrant/.chef/knife.rb && \
        sed 's:/root/.chef:\#{current_dir}:g' /root/.chef/knife.rb  | \
        sed 's:/root/chef-repo/:\#{current_dir}/../chef-repo/:g' /root/.chef/knife.rb  | \
        sed s:\\\':\\\":g | \
        sed sXhttp://127.0.0.1:8000Xhttps://127.0.0.1:#{forwarded_port}Xg | \
        sed s:/etc/chef-server:\#{current_dir}:g >> /vagrant/.chef/knife.rb"
      # or we can just do vagrant ssh chef-server -- sudo cat /root/.chef/root.pem
      #                   vagrant ssh chef-server -- sudo cat /etc/chef-server/chef-validator.pem
    end
  end

  node_names.sort.each do |name|
    config.vm.define name do |node_config|
      node_config.vm.hostname = name
      node_config.vm.network :private_network, ip: "#{classc}.#{node_names.index(name)+11}"
      node_config.vm.provision :chef_client do |chef|
        chef.chef_server_url=ENV['CHEF_API_ENDPOINT']
        chef.validation_key_path=ENV['CHEF_VALIDATOR_KEY']
        chef.validation_client_name=ENV['CHEF_VALIDATOR_NAME']
        chef.add_role "#{name}-node" # have a role per node
        chef.json = {
          "ipaddress" => "#{classc}.#{node_names.index(name)+11}"
        }
      end
    end
  end
end
