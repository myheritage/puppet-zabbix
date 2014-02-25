class zabbix {
	file { '/etc/puppet/zabbix/zabbix.conf.flag':
		content	=>	template("zabbix/zabbix.conf.flag.erb"),
		notify	=>	Exec["zabbixconfigurator"],
		require	=>	File["/etc/puppet/zabbix"],
	}
	
	file { '/etc/puppet/zabbix':
		ensure	=>	directory,
		group	=>	root,
		owner	=>	root,
	}
	

}