# Class: zabbix::agent
#
#
class zabbix::agent (
		$pid_file="/var/run/zabbix/zabbix_agentd.pid",
		$log_file="/var/log/zabbix/zabbix_agentd.log",
		$log_file_size=0,
		$debug_level=3,
		$server='zabbix',
		$listen_port='10050',
		$manage_hostentry = false
	) {

	$package_name="zabbix20-agent"
	$include_directory="/etc/zabbix/zabbix_agentd/"
	$zabbix_server="zabbix"
	$config_file='/etc/zabbix/zabbix_agentd.conf'
	$zabbix2_config_file='/etc/zabbix_agentd.conf'
	
	package { "${package_name}":
		ensure => installed,
	}

	service { "zabbix-agent":
	    enable => true,
		ensure => running,
		hasrestart => true,
		hasstatus => true,
		require => [
			File["${config_file}"],
			Package["${package_name}"]
		]
	}

	file { "${config_file}":
		require	=>	Package["${package_name}"],
		content	=>	template("zabbix/agent/zabbix_agentd.conf.erb"),
		mode    =>	644,
		notify	=>	Service['zabbix-agent'],
		ensure => file,
	}

	file { "${zabbix2_config_file}":
		ensure => link,
		target	=>	"${config_file}"
	}

	file { "${include_directory}":
		ensure => directory,
		recurse	=> false
	}
	if $manage_hostentry {
		@@zabbix_host { $::hostname:
    			ensure     => 'present',
    			groups     => hiera_array('zabbix::agent::groups',[]),
    			templates  => hiera_array('zabbix::agent::templates',[]),
    			interfaces => hiera_array('zabbix::agent::interfaces',[]),
  		}
	}

}
