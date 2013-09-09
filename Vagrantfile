require 'io/console'

def get_password(prompt=nil)
  prompt ||= "Enter Chef Password for #{ENV['CHEF_USERNAME']} at #{ENV['CHEF_MANAGE_URL']}:"
  STDOUT.write prompt
  STDIN.noecho{|io|io.gets}.chomp
end

organization = ENV['CHEF_ORGANIZATION'] ||= ENV['USER']
chef_username = ENV['CHEF_USERNAME'] ||= ENV['USER']

ENV['CHEF_ACCOUNT_URL'] ||= 'https://www.opscode.com'
ENV['CHEF_API_URL'] ||= 'https://api.opscode.com'
ENV['CHEF_MANAGE_URL'] ||= 'https://manage.opscode.com'

require 'pp'

if not ::File.exists? ".chef/#{organization}-validator.pem"
  chef_password = ENV['CHEF_PASSWORD'] ||= get_password
  saved_env = ENV.to_hash
  ENV.reject! {|k,v| k =~ /GEM/} # we don't want vagrant GEM vars
  # knife setup our org
  cmd = "/opt/chef/embedded/bin/bundle exec knife setup #{organization} \
    --username #{chef_username} --password #{chef_password} \
    --key .chef/#{chef_username}.pem \
    --account-url #{ENV['CHEF_ACCOUNT_URL']} \
    --api-server-url #{ENV['CHEF_API_URL']} \
    --manage-url #{ENV['CHEF_MANAGE_URL']} \
    --validation_key .chef/#{organization}-validator.pem"
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
  system('knife upload /')
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
        chef.chef_server_url="https://api.opscode.com/organizations/#{organization}/"
        chef.validation_key_path=".chef/#{organization}-validator.pem"
        chef.validation_client_name="#{organization}-validator"
        chef.add_role "#{name}-node" # have a role per node
      end
    end
  end
end
