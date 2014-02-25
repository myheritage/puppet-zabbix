class zabbix::credentials (
  $username = 'Admin',
  $zabbixhost = '127.0.0.1',
  $url = undef,
  $use_ssl = true
) {
  $password = hiera("zabbix-${username}")
  if !$password { fail "Could not find password for ${username}" }
  file { '/root/.zabbix':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0600',
    content => template('zabbix/dotzabbix.erb'),
  }

}
