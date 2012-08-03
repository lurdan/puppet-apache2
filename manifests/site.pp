# Define: site
#
# This resource defines site virtualhost settings.
#
# Parameters:
#   $title (required):
#   $priority:
#     default との整合のため、3 桁数字を与える
#   $ensure:
#     present|absent|enable|disable
#
# Actions:
#
# Requires:
#
# Sample Usage:
#   apache2::site { 'new-site':
#     priority => '020',
#     ensure => present,
#   }
define apache2::site (
  $ensure = 'present',
  $target = false,
  $priority = '000',
  $site_name = false,
  $site_ip = '*' ,
  $site_port = '80',
  $site_user = 'www-data',
  $site_group = 'www-data',
  $site_tmpl = 'apache2/default.erb',
  $port = false,
  $namevhost = false
  ) {

  $vhost_name = $site_name ? {
    false => $::ipaddress,
    default => $site_name,
  }

  case $site_port {
    '80': {
      realize( Apache2::Namevhost['default'] )
      realize( Apache2::Listen['80'] )
    }
    '443': {
      realize( Apache2::Namevhost['default-ssl'] )
      realize( Apache2::Listen['443'] )
    }
  }

  $linkname = $name ? {
    'default' => 'default',
    default => "${priority}-${name}"
  }

  case $ensure {
    'link': {
      file { "/etc/apache2/sites-enabled/${priority}-${name}":
        ensure => link,
        target => $target,
        require => Package['apache2'],
        notify => Service['apache2'],
      }
    }
    'present': {
      case $namevhost {
        false: {
          apache2::site_install { $linkname:
            site_user => $site_user,
            site_group => $site_group,
            site_tmpl => $site_tmpl
          }
        }
        default: {
          apache2::namevhost{ "$name": port => $site_port, order => '05' }
          apache2::site_install { $linkname: site_tmpl => $site_tmpl, require => Apache2::Namevhost["$name"], }
        }
      }

      exec { "enable-site-$name":
        command => "/usr/sbin/a2ensite $linkname",
        unless => "/bin/sh -c '[ -L /etc/apache2/sites-enabled/${priority}-${name} ] && [ /etc/apache2/sites-enabled/${priority}-${name} -ef /etc/apache2/sites-available/$linkname ]'",
        notify => Exec['apache2-reloaded'],
        require => [ File["/etc/apache2/sites-available/$linkname"], Package['apache2'] ]
      }
    }
    'installed': {
      apache2::site_install { $linkname: site_tmpl => $site_tmpl, }
    }
    'absent': {
      exec { "disable-site-$name":
        command => "/usr/sbin/a2dissite $linkname",
        onlyif => "/bin/sh -c '[ -L /etc/apache2/sites-enabled/${priority}-${name} ] && [ /etc/apache2/sites-enabled/${priority}-${name} -ef /etc/apache2/sites-available/$linkname ]'",
#        notify => Exec['apache2-reloaded'],
        require => Package['apache2']
      }
    }
    default: { err ( "[apache2::site]>> Unknown ensure value: '$ensure'" ) }
  }
}

# Define: site_install
#
# 使用するサイトを定義する固有リソース。
# モジュール内部で使用するヘルパー。
#
# Parameters:
#
# Actions:
#   'default' として定義された場合は何もしない
#
# Requires:
#
# Sample Usage:
#   apache2::site_install { 'new-site': }
#
define apache2::site_install ( $site_user, $site_group, $site_tmpl ) {

  if $name == 'default' {
    file { '/etc/apache2/sites-available/default':
      ensure => present,
      require => Package['apache2'],
    }
  }
  else {
    file { "/etc/apache2/sites-available/$name":
      mode => 640, owner => root, group => adm,
      ensure => present,
      content => template("$site_tmpl"),
      require => Package['apache2'],
    }
  }
}

#define apache2::htaccess( ) {
#
#
#}
