include_recipe 'esv_base'

if node['artifactory_url']
  java_path = "#{node['artifactory_url']}/chef/java"
  zk_path = "#{node['artifactory_url']}/chef/zookeeper/zookeeper-#{node.zk.version}.tar.gz"
  jar_path = "#{node['artifactory_url']}/chef/logstash"
  node.default['java']['jdk']['8']['x86_64']['url'] = "#{java_path}/jdk-8u40-linux-x64.tar.gz"
  include_recipe "java::default"
else
  Chef::Log.warn("node['artifactory_url'] not set!")
end

# Because the zk id always needs to persist, we do not leverage search for zk discovery
# Instead we use a known list that matches their ip to their id and is defined as an attribute.
# The default here gives us a single node zk cluster 
zk_servers = []
zk_data = node['zk']['servers']
node.set['zk']['myid'] = zk_data[node.ipaddress]
zk_data.each do |k,v|
 zk_servers.push("server.#{v}=#{k}:2888:3888\n")
end

zk_servers_config = zk_servers.sort.join
install_dir = node.zk.install_dir
data_dir = node.zk.dataDir

Chef::Log.debug("\e[32mZookeeper::ZK_nodes::#{zk_servers_config}\e[0m")

directory '/opt/esv-conf' do
  owner "daemon"
  group "daemon"
  mode 00755
  recursive true
end

directory "#{data_dir}/server#{node[:zk][:myid]}/data" do
  owner "daemon"
  group "daemon"
  mode 00700
  recursive true
end

directory node.zk.dataLogDir do
  owner "daemon"
  group "daemon"
  mode 00700
  recursive true
end

ark 'zookeeper' do
  url zk_path
  version node['zk']['version']
  prefix_root '/opt' 
  prefix_home '/opt' 
  action :install
  if ::File.exists?('/etc/sv/zookeeper')
    notifies :restart, 'service[zookeeper]', :delayed
  end
end

if [*zk_servers].empty?
  Chef::Log.warn("\e[41mZookeeper::***zookeeper_cluster (used by clients) not sane, not applying template.***\e[0m") { level :warn }
else
  Chef::Log.debug("\e[32mZookeeper Local Server List::\e[33m #{zk_servers.inspect}\e[0m")
  template "#{install_dir}/conf/zoo.cfg" do
    owner 'daemon'
    group 'daemon'
    mode 00600
    source 'zoo.cfg.erb'
    variables({
      :dataDir => "#{data_dir}/server#{node[:zk][:myid]}/data",
      :dataLogDir => node.zk.dataLogDir,
      :zk_servers_config => zk_servers_config
    })
  end
end

template "#{install_dir}/conf/myid" do
  owner 'daemon'
  group 'daemon'
  mode 00600
  source 'myid.erb'
  variables({
    :myid => node[:zk][:myid]
  })
end

link "#{data_dir}/server#{node[:zk][:myid]}/data/myid" do
  to '/opt/zookeeper/conf/myid'
end

cookbook_file 'log4j-server.properties' do
  owner 'daemon'
  group 'daemon'
  mode 00600
  path "#{install_dir}/conf/log4j-server.properties"
  if ::File.exists?('/etc/sv/zookeeper')
    notifies :restart, 'service[zookeeper]', :delayed
  end
end

# link to common config location for convenience
link '/opt/esv-conf/myid' do
  to "#{install_dir}/conf/myid"
end

link '/opt/esv-conf/zoo.cfg' do
  to "#{install_dir}/conf/zoo.cfg"
end

link '/opt/esv-conf/zk.log4j.cfg' do
  to "#{install_dir}/conf/log4j-server.properties"
end

%w(commons-lang-2.6.jar json-smart-1.1.1.jar jsonevent-layout-1.8-SNAPSHOT.jar).each do |jar|
  remote_file jar do
    source "#{jar_path}/#{jar}"
    path "#{install_dir}/lib/#{jar}"
    if ::File.exists?('/etc/sv/zookeeper')
      notifies :restart, 'service[zookeeper]', :delayed
    end
  end
end

runit_service 'zookeeper' do
  template_name 'zookeeper'
end

area = node['datacenter'].split("-")[0..1].join("-")

roles = node['zk']['clients'].join("\sOR\s")
zk_client_search = "chef_environment:#{node.chef_environment} AND datacenter:#{area}* AND (#{roles})"
zk_clients = []
zk_clients = search(:node, zk_client_search).map { |n| (n.service_address if (n.attribute?('service_address'))) || n.ipaddress }.compact.sort
zk_servers = zk_data.keys.delete_if {|ip| ip == node.ipaddress }

zk_clients.push(*node['zk']['external_clients']) unless (node['zk'].attribute?('external_clients') && node['zk']['external_clients'].empty?)

iptables_rule 'ports_zk' do
  variables({
    :zk_clients => zk_clients,
    :zk_servers => zk_servers
  })
end

if node['zk']['logstash']
  include_recipe 'tgt-elk-wrapper::logstash_agent'
  template '/opt/logstash/agent/etc/conf.d/input_zk_logs.conf' do
    source 'input_zk_logs.conf.erb'
#    notifies :restart, "logstash_service['logstash_agent']", :delayed
  end
end
