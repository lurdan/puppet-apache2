# Class: apache
#
# apache を管理するクラス。
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

  package { 'apache2':
    ensure => installed,
  }

  package { "apache2-mpm-${mpm}":
    ensure => installed,
    before => Package['apache2'],
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
    enable => $active,
    require => Package['apache2'],
  }

  exec { 'apache2-reloaded':
    command => '/etc/init.d/apache2 reload',
    refreshonly => true,
    before => Service['apache2'],
  }

  concat { '/etc/apache2/ports.conf':
    require => Package['apache2'],
    notify => Service['apache2'],
  }

  @apache2::namevhost {
    'default':;
    'default-ssl': port => '443';
  }

  @apache2::listen {
    '80':;
    '443':;
  }
}

define apache2::conf ( $content = '', $ensure = 'present', $order = false ) {
  if $order {
    $filename = "${order}-${name}"
  }
  else {
    $filename = "${name}"
  }

  file { "/etc/apache2/conf.d/$filename":
    ensure => $ensure,
    content => $content,
    require => Package['apache2'],
    notify => Exec['apache2-reloaded'],
  }
}

# Define: namevhost
#
# サイト毎の NameVirtualHost を定義する固有リソース。
# モジュール内部で使用するヘルパー。
#
# Parameters:
#   priority を含めた (sites-enabled 配下の symlink と同じ) 名前で定義されることを想定している。
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

define apache2::listen () {
  concat::fragment { "apache2-listen-${name}":
    target => '/etc/apache2/ports.conf',
    content => "Listen ${name}\n",
  }
}
