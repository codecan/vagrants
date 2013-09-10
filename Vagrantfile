ENV['CHEF_ORGANIZATION'] ||= ENV['USER']
ENV['CHEF_USERNAME'] ||= ENV['USER']
ENV['CHEF_ACCOUNT_URL'] ||= 'https://www.opscode.com'
ENV['CHEF_API_URL'] ||= 'https://api.opscode.com'
ENV['CHEF_MANAGE_URL'] ||= 'https://manage.opscode.com'

if not ::File.exists? ".chef/#{ENV['CHEF_ORGANIZATION']}-validator.pem"
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

classc='1.1.1'
node_names = Dir.glob('chef-repo/roles/*-node.json').map{|x|File.basename(x).sub('-node.json','')}

Vagrant.configure("2") do |config|
  config.omnibus.chef_version = '11.6.0'
  config.vm.box_url = "https://opscode-vm-bento.s3.amazonaws.com/vagrant/opscode_centos-6.4_provisionerless.box"
  config.vm.box = "opscode_centos-6.4_provisionerless"

  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    vb.customize ["modifyvm", :id, "--cpus","2"]
  end

  node_names.sort.each do |name|
    config.vm.define name do |node_config|
      node_config.vm.hostname = name
      node_config.vm.network :private_network, ip: "#{classc}.#{node_names.index(name)+10}"
      node_config.vm.provision :chef_client do |chef|
        chef.chef_server_url="https://api.opscode.com/organizations/#{ENV['CHEF_ORGANIZATION']}/"
        chef.validation_key_path=".chef/#{ENV['CHEF_ORGANIZATION']}-validator.pem"
        chef.validation_client_name="#{ENV['CHEF_ORGANIZATION']}-validator"
        chef.add_role "#{name}-node" # have a role per node
      end
    end
  end
end
