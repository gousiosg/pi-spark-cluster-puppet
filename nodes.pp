node 'master' {

  network::interface { 'eth0':
    ipaddress => '10.0.0.1',
    netmask   => '255.255.255.0',
  }

  class { 'dnsmasq':
    interface => 'eth0',
    no_dhcp_interface => 'wlan0',
    domain  => 'spark',
    enable_tftp => false
  }

  dnsmasq::dhcpstatic {
    'slave1': mac => 'b8:27:eb:cf:5e:3d', ip  => '10.0.0.2';
  }
}

