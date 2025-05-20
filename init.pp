class wordpress (
  String $wp_db_name = 'wordpress',
  String $wp_db_user = 'wp_user',
  # Use your own strong password instead
  String $wp_db_password = 'wordpress',
) {

  # Fetch the salt data
  $salt_data = inline_template("<%= `curl -s https://api.wordpress.org/secret-key/1.1/salt/` %>")

  # Download required packages
  package { [
    'httpd',
    'php',
    'php-mysqlnd',
    'wget',
  ]:
    ensure => installed,
  }

  # Download latest wordpress
  exec { 'download_wordpress':
    command => 'curl -sLO https://wordpress.org/latest.tar.gz && tar -xzf latest.tar.gz --strip-components=1 -C /var/www/html',
    creates => '/var/www/html/index.php',
    path    => ['/usr/bin', '/bin', '/usr/local/bin'],
    require => [ 
      Package['wget'],
    ],
  }

  # Update owner and group for httpd
  file { '/var/www/html/wordpress':
    ensure  => directory,
    recurse => true,
    owner   => 'apache',
    group   => 'apache',
    require => [
      Exec['download_wordpress'],
      Package['httpd'],
    ],
  }

  # Generate wp-config from template
  file { '/var/www/html/wp-config.php':
    ensure  => present,
    content => template('wordpress/wp-config.php.erb'),
    require => [
      Package['httpd'],
    ],
  }

  class { 'mysql::client':
    package_name => 'mariadb105',
  }

  class { 'mysql::server':
    package_name => 'mariadb105-server',
    root_password  => 'root_password', # Use your own strong password instead
  }

  # Create the wordpress database
  mysql::db { $wp_db_name:
    user     => $wp_db_user,
    password => $wp_db_password,
    host     => 'localhost',
    grant    => ['ALL'],
    charset  => 'utf8mb4',
    collate  => 'utf8mb4_unicode_ci',

    require => [
      Class['mysql::server'],
    ],
  }

  service { 'httpd':
    ensure => running,
    enable => true,

    require => [
      Package['httpd'],
      Mysql::Db[$wp_db_name],
      File['/var/www/html/wp-config.php'],
    ],
  }

}
