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
    'mariadb105',
    'mariadb105-server',
    'wget',
    'unzip',
  ]:
    ensure => installed,
  }

  # Download latest wordpress
  exec { 'download_wordpress':
    command => 'wget https://wordpress.org/latest.zip -O /tmp/wordpress.zip && unzip -o /tmp/wordpress.zip -d /tmp',
    creates => '/tmp/wordpress',
    require => [ 
      Package['wget'],
      Package['unzip'],
    ],
  }

  # Copy wordpress into apache httpd folder
  file { '/var/www/html/wordpress':
    ensure  => directory,
    recurse => true,
    source  => '/tmp/wordpress',
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

  # Ensure mariadb service runs
  service { 'mariadb':
    ensure => running,
    enable => true,

    require => [
      Package['mariadb105'],
      Package['mariadb105-server'],
    ],
  }

  class { 'mysql::server':
    manage_package => false,
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
      Service['mariadb'],
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
