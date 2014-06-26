from fabric.api import env, roles, run, cd, put

# TODO(JMC): Use os.environ.get for roledefs for 12factor?
# TODO(JMC): Make an init script for logstash-forwarder and install it properly

# Define sets of servers as roles
env.roledefs = {
    'elk': ['elkstack.org'],
    'collectd': ['elkstack.org'],
    'forwarder': [''],
}

# Set the user to use for ssh
env.user = 'dhc-user'

def deploy():
    deploy_logstash()
    deploy_collectd()
    

@roles('web')
def deploy_logstash():
     with cd('/etc/logstash'):
        put('logstash-forwarder.crt', '/etc/logstash', use_sudo=True)
        put('logstash-forwarder.key', '/etc/logstash', use_sudo=True)
        run('chown root:root logstash-forwarder.*', use_sudo=True)
        put('conf/logstash.conf', '/etc/logstash', use_sudo=True)
        run('/etc/init.d/logstash restart', use_sudo=True)

@roles('collectd')
def deploy_collectd():
     with cd('/etc/collectd'):
        run('sudo apt-get -y install snmp-mibs-downloader')
        put('conf/collectd.conf', '/etc/collectd', use_sudo=True)
        put('conf/collectd.conf.d/*', '/etc/collectd/collectd.conf.d', use_sudo=True)
        run('sudo /etc/init.d/collectd restart')

@roles('forwarder')
def deploy_forwarder():
    run('sudo mkdir -p /opt/logstash-forwarder')
    with cd('/opt/logstash-forwarder'):
        put('logstash-forwarder.crt', '/opt/logstash-forwarder', use_sudo=True)
        put('logstash-forwarder.key', '/opt/logstash-forwarder', use_sudo=True)
        put('logstash-forwarder.conf', '/opt/logstash-forwarder', use_sudo=True)
        put('logstash-forwarder', '/opt/logstash-forwarder', use_sudo=True)
        run('sudo /opt/logstash-forwarder/logstash-forwarder --config logstash-forwarder.conf')
        