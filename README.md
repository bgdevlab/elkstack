ELK-ME
======

This script is for doing an automated install of elasticsearch, logstash and the kibana3 front end.
The logstash filters are designed to process logs from OpenStack clusters.
They will also consume collectd stats, and snmp via collectd.

INSTALLATION:
=============

Step One: Set up an ELK Server.
-------------------------------

Launch a new VM (or install a regular server with Ubuntu), log in and run:

	
	curl -sL http://bit.ly/elk-me | bash
	

Go get a cup of coffee.

Step Two: Get some data into it.
-------------------------------

You're going to need a git checkout of this project for the next few steps.

	git clone https://github.com/joshuamckenty/ELK-ME.git
	cd ELK-ME

If you're building a new OpenStack cluster, simply set up everything to log to syslog upstream, and point those logs at your new ELK box.
If you've already got a syslog server gathering up the logs from your cluster (often the boot node in a POC Piston OpenStack environment),
you can install logstash-forwarder on that node and use it to pass logs into your ELK server.

Logstash-forwarder requires the *same* pair of keys to be on the forwarder and the logstash server. So let's get that set up:

	cp logstash-forwarder.conf.sample logstash-forwarder.conf
	# customize as required here
	openssl blah blah
	fab deploy_forwarder
	fab deploy_logstash


We also like to graph some real-time meters, particularly disk usage, network bandwidth and CPU usage.
We do this by using collectd to poll SNMP data.
Copy the sample cluster collectd conf file (e.g., my-lab-openstack.conf.sample) and customize:

	<Plugin snmp>
		<Host "node-68">
			Address "172.16.10.68"
			Version 2
			Community "public"
			Collect "disk_usage" "hr_users" "std_traffic"
		</Host>
	</Plugin>

(Don't forget the trailing newline - collectd is picky about that.)

Deploy this using the fabric script.

	fab deploy_collectd

Note that your collectd server needs to be able to reach your openstack hosts on UDP port 161. If this isn't possible, you can use sshuttle as a tunnel for UDP (see the footnotes).
If you're willing or able to install collectd on each of your openstack nodes, you can obviously use this for stats meters directly, bypassing the SNMP polling. But you'll probably still want SNMP polling of your networking hardware.


Step Three: Do some queries.
-------------------------------

Elasticsearch query syntax is at http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-query-string-query.html#query-string-syntax

Start out by trying something like

	program:nova- AND NOT (INFO\:) AND NOT (DEBUG\:)


Step Four: Troubleshooting.
-------------------------------

If your log data isn't showing up, chances are that you've got firewall issues. Check the security group rules on your elkstack VM, and especially check for UDP filtering on your openstack cluster.

Syslog Port List:

 * TCP/514 Syslog (Devices supporting TCP)
 * UDP/514 Syslog (Devices that do not support TCP - Only use if absolutely necessary)
 * TCP/5043 Logstash-Forwarder
 * UDP/161 SNMP polling for collectd
 * UDP/25826 Collectd data


Appendix - Using Brian May's SSHUTTLE fork for UDP-over-SSH:
-------------------------------

	apt-get -y install python-dev python-setuptools autossh 
	wget http://www.pps.univ-paris-diderot.fr/~ylg/PyXAPI/PyXAPI-0.1.tar.gz
	tar -zxvf PyXAPI-0.1.tar.gz
	cd PyXAPI-0.1/
	./configure
	make
	make install
	cd
	git clone https://github.com/joshuamckenty/sshuttle.git
	cd sshuttle/packaging/
	./make_deb
	dpkg -i ./sshuttle-0.2.deb
	apt-get -fy install
	ip route add local default dev lo table 100
	ip rule add fwmark 1 lookup 100
	ip -6 route add local default dev lo table 100
	ip -6 rule add fwmark 1 lookup 100
	sshuttle --method=tproxy --daemon -r root@<my_openstack_host> 172.16.0.0/16


TODO (JMC):
-------------------------------

 - Make it clustered: http://everythingshouldbevirtual.com/highly-available-elk-elasticsearch-logstash-kibana-setup
 - Submit openstack patch to https://github.com/elasticsearch/logstash/tree/v1.4.1/patterns
 - Chain filters like so: https://groups.google.com/forum/#!topic/logstash-users/x0i-G0qiU6M
 - Use logstash metrics for graphana views (http://logstash.net/docs/1.4.2/filters/metrics)
 - Write a zendesk output: https://github.com/elasticsearch/logstash/tree/master/lib/logstash/outputs
 - Add more dashboards, maybe from these collections:
	- https://gist.github.com/mrlesmithjr/8f8ff8e2e8e6f43cb701 - Vmware
	- https://gist.github.com/mrlesmithjr/b0c8f9d8495c8dbefba7 - Syslog
	- https://gist.github.com/mrlesmithjr/42db96d077f4d1035186 - Windows

