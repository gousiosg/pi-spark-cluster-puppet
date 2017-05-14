class defaults {
  exec { "apt-update": command => "/usr/bin/apt-get update" }

  package { 'vim': ensure => present }
  package { 'git-core': ensure => present }
  package { 'curl' : ensure => present }
  package { 'ntp' : ensure => present }
  package { 'dnsutils' : ensure => present }
  package { 'oracle-java8-jdk' : ensure => present }
  package { 'htop' : ensure => present }
  package { 'nmon' : ensure => present }

  #alternatives { 'editor':
  #  path => '/usr/bin/vim.basic',
  #}

  ssh_authorized_key { "ssh-key-pi":
      user  => "pi",
      ensure => present,
      type   => "ssh-rsa",
      key    => "AAAAB3NzaC1yc2EAAAABIwAAAQEAtyYEI3bTfWntzykFiAWXq6yd7jU1w/ON2DtJ8U28wH1nTsy8Y1zR7nWuTbeTHLhWMe4el/cTn/SW6c8WGJGkE8Xkir6Y5XOrJ3BSj/4EwnqnYt8SyM0ZvLo8sDOPqhTkYQhA4ZNUykQJsAvDRMrEvdqsnjuZtqDi/tru8RvPlo/ChmL2CHCcvGyHWsAixCqgUS6cjz+TzuBePpXdYvrTjIY+6GJDLQ4UIpaJcc2iwLoWS4TEbyaPf5+2qNBwZ2/bQC5u2aosVuD9K/q1aRpvNTqil+J2Ip/irimK2tBPLcf5BdLecnxObyx4GiZ49T8T9YghsoM9Z4a56i0kN0DOkQ==",
      name   => "pi@master"
  }
}

class my::hadoop {
    class { 'cdh::hadoop':
        # Logical Hadoop cluster name.
        cluster_name       => 'bdp',
        # Must pass an array of hosts here, even if you are
        # not using HA and only have a single NameNode.
        namenode_hosts     => ['master.spark'],
        datanode_mounts    => [
            '/var/lib/hadoop/data/a'
        ],
        # You can also provide an array of dfs_name_dirs.
        dfs_name_dir       => '/var/lib/hadoop/name',
    }
}


class my::hadoop::master inherits my::hadoop {
    include cdh::hadoop::master
}

class my::hadoop::worker inherits my::hadoop {
    include cdh::hadoop::worker
}

node 'master' {

  include defaults
  include my::hadoop::master

  # Configure networking
  network::interface { 'wlan0':
    wpa_ssid => '',
    wpa_psk => '',
    enable_dhcp => true
  }

  network::interface { 'eth0':
    ipaddress => '10.0.0.1',
    netmask   => '255.255.255.0',
  }

  class { 'dnsmasq':
    interface => 'eth0',
    listen_address => '10.0.0.1',
    domain  => 'spark',
    enable_tftp => false
  }

  dnsmasq::dhcp { 'dhcp':
    paramset => 'spark',
    dhcp_start => '10.0.0.10',
    dhcp_end => '10.0.0.20',
    netmask => '255.255.255.0',
    lease_time => '24h'
  }

  dnsmasq::dhcpstatic {
    'slave1': mac => 'b8:27:eb:cf:5e:3d', ip  => '10.0.0.2';
    'slave2': mac => 'b8:27:eb:25:8b:60', ip => '10.0.0.3';
    'slave3': mac => 'b8:27:eb:b9:bc:e9', ip => '10.0.0.4';
    'slave4': mac => 'b8:27:eb:ca:ed:9a', ip => '10.0.0.5';
  }

  dnsmasq::address {
    "master.spark": ip => '10.0.0.1';
    "slave1.spark": ip => '10.0.0.2';
    "slave2.spark": ip => '10.0.0.3';
    "slave3.spark": ip => '10.0.0.4';
    "slave4.spark": ip => '10.0.0.5';
  }

  # NAT config
  package {'iptables-persistent': ensure => present}

  firewall { '100 snat for network internal':
    chain    => 'POSTROUTING',
    jump     => 'MASQUERADE',
    proto    => 'all',
    outiface => 'wlan0',
    source   => '10.0.0.0/24',
    table    => 'nat'
  } ->
  exec { 'enable ip_forwarding': command => '/bin/echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf ; /sbin/sysctl -w net.ipv4.ip_forward="1"' }

  # Puppet master installation
  package {'puppetmaster-passenger': ensure => present}
  file { "/etc/puppet/files":
    ensure => 'link',
    target => '/home/pi/pi-spark-cluster-puppet/files'
  }

  file { "/etc/puppet/manifests/site.pp":
    ensure => 'link',
    target => '/home/pi/pi-spark-cluster-puppet/nodes.pp'
  }

  # LCD screen
  file { "/boot/cmdline.txt":
    source => "puppet:///files/cmdline.txt",
    group => "root",
    owner => "root"
  }

  file { "/boot/config.txt":
    source => "puppet:///files/config.txt",
    group => "root",
    owner => "root"
  }

  file { "/boot/overlays/waveshare35a-overlay.dtb":
    source => "puppet:///files/waveshare35a-overlay.dtb",
    group => "root",
    owner => "root"
  }
  package {'tmux': ensure => present}
}

node /slave[0-9]*\.spark/ {
  include defaults
  include my::hadoop::worker
}

