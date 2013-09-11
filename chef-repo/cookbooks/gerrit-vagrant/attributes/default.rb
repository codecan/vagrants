eth1ip = network.interfaces.eth1.addresses.select{|k,v|v['family']=='inet'}.keys.first
#override['gerrit']['http_listen_url']="proxy-http://#{eth1ip}:8081"
override['gerrit']['canonical_url'] = "http://#{eth1ip}:2900"
override['gerrit']['http_proxy']['host_name']=eth1ip
override['gerrit']['http_proxy']['listen_ports']=[2900]
