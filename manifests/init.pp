# Class: apache2
#
# This class controls apache2.
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#   class { 'apache2': mpm => 'worker' }
#   apache2::modules { ... }
#   apache2::site
class apache2 ( $active = true, $mpm = 'worker' ) {

  $pkg_name = $::osfamily ? {
    'Debian' => 'apache2',
    'RedHat' => 'httpd',
  }

  package { 'apache2':
    ensure => latest,
    name => $pkg_name,
  }

  if $::osfamily ==  'Debian' {
    package { "apache2-mpm-${mpm}":
      ensure => latest,
      before => Package['apache2'],
    }
    concat { '/etc/apache2/ports.conf':
      require => Package['apache2'],
      notify => Service['apache2'],
    }

    @apache2::namevhost {
      'default':;
    }

    @apache2::listen {
      '80':;
      '443':;
    }
  }

  file { '/var/www':
    ensure => directory,
    mode => 755,
    require => Package['apache2'],
  }

  service { 'apache2':
    ensure => $active ? {
      true => running,
      default => stopped,
    },
    name => $pkg_name,
    enable => $active,
    require => Package['apache2'],
  }

  exec { 'apache2-reloaded':
    command => "/etc/init.d/${pkg_name} reload",
    refreshonly => true,
    before => Service['apache2'],
  }
}

# Define: apache2::conf
#
# Creates separate config parts for apache2.
#
# Parameters:
#   content:
#   ensure:
#   mode:
#   owner:
#   group:
#   order:
#
# Requires:
#
# Sample Usage:
#   apache2::conf { 'mysite.conf':
#     content => template('mymod/vhost.conf.erb');
#   }
#
define apache2::conf (
  $content = '',
  $ensure = 'present',
  $mode = 640,
  $owner = root,
  $group = 0,
  $order = false
  ) {

  $confdir = $::osfamily ? {
    'Debian' => '/etc/apache2/conf.d',
    'RedHat' => '/etc/httpd/conf.d',
  }

  $filename = $order ? {
    false => "${name}",
    default => "${order}-${name}"
  }

  file { "${confdir}/${filename}":
    ensure => $ensure,
    content => $content,
    require => Package['apache2'],
    notify => Exec['apache2-reloaded'],
  }
}

# Define: apache2::namevhost (Debian only)
#
# This resource represents Namevhost parameter for each site.
# It's intended to be used inside this module.
#
# Parameters:
#   Name
#   ip
#   port
#
# Actions:
#
# Requires:
#
# Sample Usage:
#   apache2::namevhost { '00-default':
#     ip => '192.168.11.1',
#     port => '8080',
#   }
#
define apache2::namevhost( $ip = '*', $port = '80', $order = '10' ) {
  apache2::conf { "${name}-namevhost":
    content => "NameVirtualHost $ip:$port",
    order => $order,
  }
}

# Define: apache2::listen (Debian only)
#
# This resource represents Listen parameter.
#
# Parameters:
#
# Requires:
#
# Sample Usage:
#   apache2::listen { '443':; }
#
define apache2::listen () {
  concat::fragment { "apache2-listen-${name}":
    target => '/etc/apache2/ports.conf',
    content => "Listen ${name}\n",
  }
}
