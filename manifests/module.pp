# Define: apache2::module
#
# This module manages sample
#
# Parameters:
#   $title (required):
#     libapache2-mod- を除いた名前を指定
#   $ensure:
#     present|absent|enable|disable
#   $confname:
#   $config:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
# [Remember: No empty lines between comments and class definition]
define apache2::module( $ensure = 'present', $confname = false, $config = false ) {
  if $confname {
    $conffile = $confname
  }
  else {
    $conffile = $name
  }
  anchor { "apache2::module::${name}::begin": require => Package['apache2'] }
  anchor { "apache2::module::${name}::end":  before => Exec['apache2-reloaded'] }

  apache2::module::install { "$name":
    ensure => $ensure,
    require => Anchor["apache2::module::${name}::begin"],
  }

  apache2::module::config { "$conffile":
    ensure => $ensure,
    config => $config,
    require => Anchor["apache2::module::install::${name}::end"],
    before => Anchor["apache2::module::${name}::end"],
  }
}

define apache2::module::install ( $ensure = 'present' ) {
  anchor { "apache2::module::install::${name}::begin": }
  anchor { "apache2::module::install::${name}::end": }

  $module_noncore = generate('/usr/bin/apt-cache', 'search', "libapache2-mod-${name}", '--names-only')
  $module_package = $name ? {
    'suexec' => 'apache2-suexec',
    'security' => 'libapache-mod-security',
    default => $module_noncore ? {
      '' => 'core',
      /libapache2-mod/ => "libapache2-mod-${name}",
    }
  }

  case $module_package {
    'core': {
      debug "No module packages [$module_packages] are found. Assuming apache2 core modules."
    }
    default:  {
      package { "$module_package":
        ensure => $ensure,
        require => Anchor["apache2::module::install::${name}::begin"],
        before => Anchor["apache2::module::install::${name}::end"],
      }
    }
  }
}

define apache2::module::config ($ensure = 'present', $config = false ) {
  case $ensure {
    'present': {
      exec { "/usr/sbin/a2enmod $name":
        creates => "/etc/apache2/mods-enabled/${name}.load",
      }
      if $config {
        file { "/etc/apache2/mods-available/${name}.conf":
          ensure => $ensure,
          content => $config,
          require => Exec["/usr/sbin/a2enmod $name"],
        }
      }
    }
    'absent': {
      exec { "/usr/sbin/a2dismod $name":
        onlyif => "/usr/bin/test -e /etc/apache2/mods-enabled/${name}.load";
      }
    }
  }
}
