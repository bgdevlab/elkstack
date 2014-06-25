ELK-ME
----------------------------------------

This script is for doing an automated install of elasticsearch, logstash and the kibana3 front end.
The logstash filters are designed to process logs from OpenStack clusters.
They will also consume collectd stats, and snmp via collectd.

Install instructions.
```
curl -sL http://bit.ly/elk-me | bash
```

Setup syslog for devices as follows.
Port List:

 * TCP/514 Syslog (Devices supporting TCP)
 * UDP/514 Syslog (Devices that do not support TCP - Only use if absolutely necessary)
 * TCP/5043 Logstash-Forwarder


DASHBOARD COLLECTIONS:

 - https://gist.github.com/mrlesmithjr/8f8ff8e2e8e6f43cb701 - Vmware
 - https://gist.github.com/mrlesmithjr/b0c8f9d8495c8dbefba7 - Syslog
 - https://gist.github.com/mrlesmithjr/42db96d077f4d1035186 - Windows

TODO (JMC): Make it clustered
http://everythingshouldbevirtual.com/highly-available-elk-elasticsearch-logstash-kibana-setup

TODO (JMC): Submit openstack patch to https://github.com/elasticsearch/logstash/tree/v1.4.1/patterns
TODO (JMC): Chain filters like so: https://groups.google.com/forum/#!topic/logstash-users/x0i-G0qiU6M

Elasticsearch query syntax is at http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/query-dsl-query-string-query.html#query-string-syntax

Polling SNMP via collectd is useful.
But it often requires a UDP-over-SSH proxy.
Use this:
=========
https://github.com/brianmay/sshuttle/tree/tproxy/src
https://groups.google.com/forum/#!msg/sshuttle/YxjLH0Fwstk/wBoYXfQVyxAJ

Write a new logstash output to go direct to zendesk?
* https://github.com/elasticsearch/logstash/tree/master/lib/logstash/outputs

Consider collectd polling of:

 - md
 - libvirt
 - 