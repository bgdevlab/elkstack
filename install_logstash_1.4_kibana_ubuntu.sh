#!/bin/bash

#Provided by @mrlesmithjr
#EveryThingShouldBeVirtual.com

# Reworked by Joshua McKenty for OpenStack deployments

set -e
# Setup logging
# Logs stderr and stdout to separate files.
exec 2> >(tee "./Logstash_Kibana3/install_logstash_kibana_ubuntu.err")
exec > >(tee "./Logstash_Kibana3/install_logstash_kibana_ubuntu.log")

# Setting colors for output
red="$(tput setaf 1)"
yellow="$(tput bold ; tput setaf 3)"
NC="$(tput sgr0)"

mkdir -p /opt

# Capture your FQDN Domain Name and IP Address
echo "${yellow}Capturing your hostname${NC}"
yourhostname=$(hostname)
echo "${yellow}Capturing your domain name${NC}"
yourdomainname=$(dnsdomainname)
echo "${yellow}Capturing your FQDN${NC}"
yourfqdn=$(hostname -f)
echo "${yellow}Detecting IP Address${NC}"
IPADDY="$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
echo "Your hostname is currently ${red}$yourhostname${NC}"
echo "Your domain name is currently ${red}$yourdomainname${NC}"
echo "Your FQDN is currently ${red}$yourfqdn${NC}"
echo "Detected IP Address is ${red}$IPADDY${NC}"

# Disable CD Sources in /etc/apt/sources.list
echo "Disabling CD Sources and Updating Apt Packages and Installing Pre-Reqs"
sed -i -e 's|deb cdrom:|# deb cdrom:|' /etc/apt/sources.list
apt-get -qq update

# Install Pre-Reqs
apt-get install -y --force-yes openjdk-7-jre-headless ruby ruby1.9.1-dev libcurl4-openssl-dev git nginx curl collectd screen snmp

# Install Redis-Server
apt-get -y install redis-server
# Configure Redis-Server to listen on all interfaces
sed -i -e 's|bind 127.0.0.1|bind 0.0.0.0|' /etc/redis/redis.conf
service redis-server restart

# Install Elasticsearch

wget -O - http://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add -
echo "deb http://packages.elasticsearch.org/elasticsearch/1.2/debian stable main" > /etc/apt/sources.list.d/elasticsearch-stable.list
apt-get update
apt-get -y install elasticsearch

# Configuring Elasticsearch
# echo "cluster.name: logstash-cluster" >> /etc/elasticsearch/elasticsearch.yml
# echo "node.name: $yourhostname" >> /etc/elasticsearch/elasticsearch.yml
# echo "discovery.zen.ping.multicast.enabled: false" >> /etc/elasticsearch/elasticsearch.yml
# echo "discovery.zen.ping.unicast.hosts: ["127.0.0.1:[9300-9400]"]" >> /etc/elasticsearch/elasticsearch.yml
# echo "node.master: true" >> /etc/elasticsearch/elasticsearch.yml
# echo "node.data: true" >> /etc/elasticsearch/elasticsearch.yml
# echo "index.number_of_shards: 1" >> /etc/elasticsearch/elasticsearch.yml
# echo "index.number_of_replicas: 0" >> /etc/elasticsearch/elasticsearch.yml
# echo "bootstrap.mlockall: true" >> /etc/elasticsearch/elasticsearch.yml

# Making changes to /etc/security/limits.conf to allow more open files for elasticsearch
# mv /etc/security/limits.conf /etc/security/limits.bak
# grep -Ev "# End of file" /etc/security/limits.bak > /etc/security/limits.conf
# echo "elasticsearch soft nofile 32000" >> /etc/security/limits.conf
# echo "elasticsearch hard nofile 32000" >> /etc/security/limits.conf
# echo "# End of file" >> /etc/security/limits.conf

# Set Elasticsearch to start on boot
sudo update-rc.d elasticsearch defaults 95 10

# Restart Elasticsearch service
service elasticsearch restart

# Install ElasticHQ Plugin to view Elasticsearch Cluster Details http://elastichq.org
# To view these stats connect to http://logstashFQDNorIP:9200/_plugin/HQ/
/usr/share/elasticsearch/bin/plugin -install royrusso/elasticsearch-HQ || true

# Install elasticsearch Marvel Plugin Details http://www.elasticsearch.org/overview/marvel/
# To view these stats connect to http://logstashFQDNorIP:9200/_plugin/marvel
/usr/share/elasticsearch/bin/plugin -i elasticsearch/marvel/latest || true

# Install other elasticsearch plugins
# To view paramedic connect to http://logstashFQDNorIP:9200/_plugin/paramedic/index.html
/usr/share/elasticsearch/bin/plugin -install karmi/elasticsearch-paramedic || true
# To view elasticsearch head connect to http://logstashFQDNorIP:9200/_plugin/head/index.html
/usr/share/elasticsearch/bin/plugin -install mobz/elasticsearch-head || true

# Install Logstash
cd /opt
rm -rf logstash
wget https://download.elasticsearch.org/logstash/logstash/logstash-1.4.1.tar.gz
tar zxvf logstash-*.tar.gz
rm logstash-*.tar.gz
mv logstash-1.4.1 logstash
/opt/logstash/bin/plugin install contrib

# Create Logstash Init Script
cd /etc/init.d
curl -O https://raw.githubusercontent.com/joshuamckenty/Logstash_Kibana3/master/init.d/logstash

# Make logstash executable
chmod +x /etc/init.d/logstash

# Enable logstash start on bootup
update-rc.d logstash defaults 96 04

# Create Logstash configuration file
mkdir -p /etc/logstash
cd /etc/logstash
curl -O https://raw.githubusercontent.com/joshuamckenty/Logstash_Kibana3/master/conf/logstash.conf

# Update elasticsearch-template for logstash
mv /opt/logstash/lib/logstash/outputs/elasticsearch/elasticsearch-template.json /opt/logstash/lib/logstash/outputs/elasticsearch/elasticsearch-template.json.orig
cd /opt/logstash/lib/logstash/outputs/elasticsearch/
curl -O https://raw.githubusercontent.com/joshuamckenty/Logstash_Kibana3/master/conf/elasticsearch-template.json

# Create IPTables Grok pattern
tee -a /opt/logstash/patterns/IPTABLES <<EOF
NETFILTERMAC %{COMMONMAC:dst_mac}:%{COMMONMAC:src_mac}:%{ETHTYPE:ethtype}
ETHTYPE (?:(?:[A-Fa-f0-9]{2}):(?:[A-Fa-f0-9]{2}))
IPTABLES1 (?:IN=%{WORD:in_device} OUT=(%{WORD:out_device})? MAC=%{NETFILTERMAC} SRC=%{IP:src_ip} DST=%{IP:dst_ip}.*(TTL=%{INT:ttl})?.*PROTO=%{WORD:proto}?.*SPT=%{INT:src_port}?.*DPT=%{INT:dst_port}?.*)
IPTABLES2 (?:IN=%{WORD:in_device} OUT=(%{WORD:out_device})? MAC=%{NETFILTERMAC} SRC=%{IP:src_ip} DST=%{IP:dst_ip}.*(TTL=%{INT:ttl})?.*PROTO=%{INT:proto}?.*)
IPTABLES (?:%{IPTABLES1}|%{IPTABLES2})
EOF

# Restart logstash service
service logstash restart

# Configure collectd
cd /etc/collectd
mv collectd.conf collectd.conf.old || true
curl -O https://raw.githubusercontent.com/joshuamckenty/Logstash_Kibana3/master/conf/collectd.conf
/etc/init.d/collectd restart

# Install and configure Kibana3 frontend
cd /usr/share/nginx/html
rm -rf kibana
wget https://download.elasticsearch.org/kibana/kibana/kibana-3.0.1.tar.gz
tar zxvf kibana-3.0.1.tar.gz
rm kibana-*.tar.gz
mv kibana-* kibana

# Making the logstash dashboard the default
mv /usr/share/nginx/html/kibana/app/dashboards/default.json /usr/share/nginx/html/kibana/app/dashboards/default.json.orig
mv /usr/share/nginx/html/kibana/app/dashboards/logstash.json /usr/share/nginx/html/kibana/app/dashboards/default.json

cd /usr/share/nginx/html/kibana/app/dashboards
curl -O https://raw.githubusercontent.com/joshuamckenty/Logstash_Kibana3/master/dashboards/collectd.json
curl -O https://raw.githubusercontent.com/joshuamckenty/Logstash_Kibana3/master/dashboards/piston.json

# Install elasticsearch curator http://www.elasticsearch.org/blog/curator-tending-your-time-series-indices/
apt-get -y install python-pip
pip install elasticsearch-curator

# Create /etc/cron.daily/elasticsearch_curator Cron Job
tee -a /etc/cron.daily/elasticsearch_curator <<EOF
#!/bin/sh
/usr/local/bin/curator --host 127.0.0.1 delete 90
/usr/local/bin/curator --host 127.0.0.1 close 30
/usr/local/bin/curator --host 127.0.0.1 bloom 2
/usr/local/bin/curator --host 127.0.0.1 optimize 2

# Email report
#recipients="emailAdressToReceiveReport"
#subject="Daily Elasticsearch Curator Job Report"
#cat /var/log/elasticsearch_curator.log | mail -s $subject $recipients
EOF

# Make elasticsearch_curator executable
chmod +x /etc/cron.daily/elasticsearch_curator

# Create logrotate jobs to rotate logstash logs and elasticsearch_curator logs
# Logrotate job for logstash
tee -a /etc/logrotate.d/logstash <<EOF
/var/log/logstash.log {
        monthly
        rotate 12
        compress
        delaycompress
        missingok
        notifempty
        create 644 root root
}
EOF
# Logrotate job for elasticsearch_curator
tee -a /etc/logrotate.d/elasticsearch_curator <<EOF
/var/log/elasticsearch_curator.log {
        monthly
        rotate 12
        compress
        delaycompress
        missingok
        notifempty
        create 644 root root
}
EOF

# All Done
echo "Installation has completed!!"
echo -e "Connect to ${red}http://$yourfqdn/kibana${NC} or ${red}http://$IPADDY/kibana${NC}"
echo "${yellow}Enjoy!!!${NC}"
