default['java']['oracle']['accept_oracle_download_terms'] = true
default['java']['install_flavor'] = 'oracle'
default['java']['jdk_version'] = '8'

default['zk']['install_dir'] = '/opt/zookeeper'
default['zk']['dataDir'] = '/var/lib/zookeeper'
default['zk']['dataLogDir'] = '/var/lib/zookeeper'
default['zk']['user'] = 'daemon'
default['zk']['group'] = 'daemon'
default['zk']['servers'] = {node['ipaddress'] => 1}
default['zk']['version'] = '3.4.6'
default['zk']['clients'] = ['recipe:elk-wrapper*', 'role:kafka-wrapper']
default['zk']['logstash'] = true
default['zk']['maxClientCnxns'] = 1024
