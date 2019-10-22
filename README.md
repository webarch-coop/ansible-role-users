# Ansible Debian Users Role 

This repository contains an Ansible role for adding user accounts to Debian servers.

**NOTE: This role doesn't properly work with Ansible 2.8 due to [this bug](https://github.com/ansible/ansible/issues/56921).**

To use this role you need to use Ansible Galaxy to install it into another repository under `galaxy/roles/users` by adding a `requirements.yml` file in that repo that contains:

```yml
---
- name: users
  src: https://git.coop/webarch/users.git
  version: master
  scm: git
```

If you want to use any of the `quota_` variables then you also need to include the [quota role](https://git.coop/webarch/quota) and make sure that `quota_dir` is set to a mount point for a partition, for example have a seperate `/home` partition.

```yml
---
- name: quota
  src: https://git.coop/webarch/quota.git
  version: master
  scm: git
```

And a `ansible.cfg` that contains:

```
[defaults]
retry_files_enabled = False
pipelining = True
inventory = hosts.yml
roles_path = galaxy/roles

```

And a `.gitignore` containing:

```
galaxy/roles
```

To pull this repo in run:

```bash
ansible-galaxy install -r requirements.yml --force 
```

The other repo should also contain a `users.yml` file that contains:

```yml
---
- name: Add user accounts
  become: yes

  vars:
    users:
      foo:
        users_name: Foo Bar
        users_email: foo@example.org
        users_home: /var/www/foo
        users_skel: /usr/local/etc/skel.d/www
        users_group: users
        users_home_owner: root
        users_home_group: users
        # You must quote the mode or the leaving zero is stripped"
        users_home_mode: "0750"
        users_system: true
        users_shell: /usr/sbin/nologin
        users_generate_ssh_key: true
        users_editor: vim
        users_groups:
          - users
          - ssl-cert
        users_group_members:
          - www-data
      bar:
        users_home: /opt/bar
        users_shell: /bin/false
        users_system: true
        users_quota: 1G
      baz:
        users_groups:
          - staff
          - users
        users_editor: vim
        users_quota_block_softlimit: 1908874
        users_quota_block_hardlimit: 2097152
        users_quota_inode_softlimit: 9532
        users_quota_inode_hardlimit: 10484
      chris:
        users_groups:
          - sudo
          - operator
        users_editor: vim
        users_ssh_public_keys:
          - https://git.coop/chris.keys 
      fred:
        users_state: absent
    
  hosts:
    - users_servers

  roles:
    - users
```

And a `hosts.yml` file that contains lists of servers, for example:

```yml
---
all:
  children:
    users_servers:
      hosts:
        host3.example.org:
        host4.example.org:
        cloud.example.com:
        cloud.example.org:
        cloud.example.net:
```

Then it can be run as follows:

```bash
ansible-playbook users.yml 
```

## SSH Public Keys

The `users_ssh_public_keys` array should be set to a list of one or more URL's for public keys (eg from GitHub).

All the files at the URL's will be downloaded to files named:

* `~/.ssh/authorized_keys_0`
* `~/.ssh/authorized_keys_1`
* `~/.ssh/authorized_keys_2`

Then the concaternation of `~/.ssh/authorized_keys_*` will be added to `~/.ssh/authorized_keys`, this means if you want to add additional keys then you can simply add them to this directory, with a suitable filename, eg `~/.ssh/authorized_keys_extra`. 

The `exclusive` option for the [authorized_key module](https://docs.ansible.com/ansible/latest/modules/authorized_key_module.html) is not set to `True` so keys will have to be removed manually.

One drawback with this is that you can't prepend a key with `key_options`, for example, `from="127.0.0.1" ssh-rsa AAA...`, this behavious might be change in the future if we don't use the Ansible authorized_key module for adding the keys.

## Apache

### Options

Server wide settings for `VirtualHosts` can be set like this (see the commented out variables in [defaults/main.yml](defaults/main.yml):

```yml
users_apache_options:
  - -Indexes
  - +SymlinksIfOwnerMatch
  - -MultiViews
  - +IncludesNOEXEC
  - -ExecCGI
users_apache_index:
  - index.php
  - index.html
  - index.shtml
  - index.htm
users_apache_override:
  - AuthConfig
  - FileInfo
  - Indexes
  - Limit
  - Options=Indexes,SymLinksIfOwnerMatch,MultiViews,IncludesNOEXEC
  - Nonfatal=Override
```

If these variables ar not set server-wide then the `users_apache_type` variable can be used per `VirtualHost` and if it is set to `php` then these directives are used:

```apache
Options -Indexes +SymlinksIfOwnerMatch -MultiViews +IncludesNOEXEC -ExecCGI
DirectoryIndex index.php index.html index.htm index.shtml
AllowOverride AuthConfig FileInfo Indexes Limit Options=Indexes,SymLinksIfOwnerMatch,MultiViews,IncludesNOEXEC Nonfatal=Override
```

And if it is set to `cgi` then these directives are used:

```apache
Options -Indexes +SymlinksIfOwnerMatch -MultiViews +IncludesNOEXEC +ExecCGI
DirectoryIndex index.cgi index.pl index.html index.htm index.shtml
AllowOverride AuthConfig FileInfo Indexes Limit Options=ExecCGI,SymLinksIfOwnerMatch,MultiViews,IncludesNOEXEC Nonfatal=Override
```

And if it is omitted (or set to a value such as `static`) then these defaults are used:

```apache
Options -Indexes +SymlinksIfOwnerMatch -MultiViews +IncludesNOEXEC -ExecCGI
DirectoryIndex index.html index.htm index.shtml
AllowOverride AuthConfig FileInfo Indexes Limit Options=Indexes,SymLinksIfOwnerMatch,MultiViews,IncludesNOEXEC Nonfatal=Override
```

The arrays, `users_apache_options`, `users_apache_index` and `users_apache_override` can also be set by `VirtualHost` and if they are these overrule the other settings, see the [Apache template for the details](templates/apache.conf.j2).

### Location

The `users_apache_htauth_locations` array can be used to apply HTTP Authentication to directories, for example:

```yml
        users_apache_htauth_locations:
          - name: WordPress Login
            location: /wp-login.php
```
The `users_apache_htauth_users` array can be used to set usernames and passwords, these are written to `~/.htpasswd/` in one file per `users_apache_server_name`, the optional `state` variables ce be set to absent to remove users, for example:

```yml
        users_apache_htauth_users:
          - name: foo
            password: bar
          - name: baz
            state: absent
```
If the `type` is set to `None` then `AuthUserFile` isn't set then a `require` array can be set [to do things like only allow a few IP addresses](https://httpd.apache.org/docs/current/mod/mod_authz_core.html#require), for example:

```yml
        users_apache_htauth_locations:
          - name: Drupal Login
            location: /user/login
            type: None
            require:
              - ip 10 172.20 192.168.2
              - method GET POST
```

### Expires

The optional `users_apache_expires` variable can be used to select the [medium](https://git.coop/webarch/apache/blob/master/templates/expires-medium.conf.j2) or [strict](https://git.coop/webarch/apache/blob/master/templates/expires-strict.conf.j2) configuration to `Include` into the `VirtualHost`.

### Robots

The optional `users_apache_robots` variable can be set to `deny` to `Include` the [robots config](https://git.coop/webarch/apache/blob/master/templates/robots-deny.conf.j2) and this will also set an `Alias` for the [robots.txt](https://git.coop/webarch/apache/blob/master/templates/robots.deny.txt.j2) file.

### PHP

Some specific PHP variables include the `users_apache_nophp_dirs` array, this can be used to list directories that PHP cannot be used in, for example directories where users can upload files, for example:

```yml
        users_apache_nophp_dirs:
          - wp-content/uploads
```

### Example Apache VirtualHost 

If a user has a set of variables like this:

```yml
    users_apache_virtual_hosts:
      default:
        users_apache_type: php
        users_apache_nophp_dirs:
          - wp-content/uploads
        users_apache_server_name: wordpress.example.org
        users_apache_server_aliases:
          - www.wordpress.example.org
        users_cms: wordpress
        wordpress_dbname: wordpress_live
        users_daily_scripts:
          - "wp-update {{ users_basedir }}/wordpress/{{ users_sites_dir }}/default"
        users_apache_htauth_locations:
          - name: WordPress Config
            location: /wp-config.php
            type: None
            require:
              - all denied
        users_apache_nophp_dirs:
          - wp-content/uploads
        users_apache_expires: medium
      dev:
        users_apache_type: php
        users_apache_nophp_dirs:
          - wp-content/uploads
        users_apache_robots: deny
        users_apache_server_name: dev.wordpress.example.org
        users_apache_server_aliases:
          - www.dev.wordpress.example.org
        users_cms: wordpress
        wordpress_dbname: wordpress_dev
        users_daily_scripts:
          - "wp-update {{ users_basedir }}/wordpress/{{ users_sites_dir }}/default"
        users_apache_htauth_users:
          - name: foo
            password: bar
        users_apache_htauth_locations:
          - name: WordPress Login
            location: /wp-login.php
          - name: WordPress Config
            location: /wp-config.php
            type: None
            require:
              - all denied
        users_apache_expires: medium

```

It will generate an Apache config like this:

```apache
# Ansible managed

# wordpress.example.org
# /home/wordpress/sites/default
<VirtualHost *:80>
  ServerName wordpress.example.org
  ServerAlias www.wordpress.example.org
  RedirectMatch 301 ^(?!/\.well-known/acme-challenge/).* https://wordpress.example.org$0
</VirtualHost>
# wordpress.example.org
# /home/wordpress/sites/default
<VirtualHost *:443>
  ServerName wordpress.example.org
  ServerAlias www.wordpress.example.org
  SSLEngine on
  SSLCertificateFile            /etc/ssl/le/wordpress.wordpress.example.org.cert.pem
  SSLCertificateKeyFile         /etc/ssl/le/wordpress.wordpress.example.org.key.pem
  SSLCertificateChainFile       /etc/ssl/le/wordpress.wordpress.example.org.ca.pem
  ServerAdmin "chris@webarch.net"
  <Location "/wp-config.php" >
    # No AuthUserFile for this Location
    AuthName "WordPress Config"
    AuthType None
    Require all denied
  </Location>
  DocumentRoot "/home/wordpress/sites/default"
  <Directory "/home/wordpress/sites/default">
    Options -Indexes +SymlinksIfOwnerMatch -MultiViews +IncludesNOEXEC -ExecCGI
    DirectoryIndex index.php index.html index.htm index.shtml wsh.shtml
    AllowOverride AuthConfig FileInfo Indexes Limit Options=Indexes,SymLinksIfOwnerMatch,MultiViews,IncludesNOEXEC Nonfatal=Override
    <IfModule proxy_fcgi_module>
      <IfModule setenvif_module>
        SetEnvIfNoCase ^Authorization$ "(.+)" HTTP_AUTHORIZATION=$1
      </IfModule>
      <FilesMatch "\.php$">
        <If "-f %{REQUEST_FILENAME}">
          SetHandler "proxy:unix:/users/wordpress/home/wordpress/php-fpm.sock|fcgi://localhost"
        </If>
      </FilesMatch>
    </IfModule>
    Require all granted
    IncludeOptional "/etc/apache2/conf-available/expires-medium.conf"
  </Directory>
  # No PHP allowed in this directory
  <Directory "/home/wordpress/sites/default/wp-content/uploads">
    <FilesMatch "\.php$">
      <If "-f %{REQUEST_FILENAME}">
        Require all denied
      </If>
    </FilesMatch>
  </Directory>
  CustomLog /var/log/apache2/wordpress_access.log bandwidth
  LogLevel error
  ErrorLog  /home/wordpress/logs/apache.error.log
  CustomLog /home/wordpress/logs/apache.access.log combinedio
</VirtualHost>

# dev.wordpress.example.org
# /home/wordpress/sites/dev
<VirtualHost *:80>
  ServerName dev.wordpress.example.org
  ServerAlias www.dev.wordpress.example.org
  RedirectMatch 301 ^(?!/\.well-known/acme-challenge/).* https://dev.wordpress.example.org$0
</VirtualHost>
# dev.wordpress.example.org
# /home/wordpress/sites/dev
<VirtualHost *:443>
  ServerName dev.wordpress.example.org
  ServerAlias www.dev.wordpress.example.org
  SSLEngine on
  SSLCertificateFile            /etc/ssl/le/wordpress.wordpress.example.org.cert.pem
  SSLCertificateKeyFile         /etc/ssl/le/wordpress.wordpress.example.org.key.pem
  SSLCertificateChainFile       /etc/ssl/le/wordpress.wordpress.example.org.ca.pem
  ServerAdmin "chris@webarch.net"
  IncludeOptional /etc/apache2/conf-available/robots-deny.conf
  <Location "/wp-login.php" >
    AuthUserFile "/home/wordpress/.htpasswd/dev.wordpress.example.org"
    AuthName "WordPress Login"
    AuthType Basic
    Require valid-user
  </Location>
  <Location "/wp-config.php" >
    # No AuthUserFile for this Location
    AuthName "WordPress Config"
    AuthType None
    Require all denied
  </Location>
  DocumentRoot "/home/wordpress/sites/dev"
  <Directory "/home/wordpress/sites/dev">
    Options -Indexes +SymlinksIfOwnerMatch -MultiViews +IncludesNOEXEC -ExecCGI
    DirectoryIndex index.php index.html index.htm index.shtml wsh.shtml
    AllowOverride AuthConfig FileInfo Indexes Limit Options=Indexes,SymLinksIfOwnerMatch,MultiViews,IncludesNOEXEC Nonfatal=Override
    <IfModule proxy_fcgi_module>
      <IfModule setenvif_module>
        SetEnvIfNoCase ^Authorization$ "(.+)" HTTP_AUTHORIZATION=$1
      </IfModule>
      <FilesMatch "\.php$">
        <If "-f %{REQUEST_FILENAME}">
          SetHandler "proxy:unix:/users/wordpress/home/wordpress/php-fpm.sock|fcgi://localhost"
        </If>
      </FilesMatch>
    </IfModule>
    Require all granted
    IncludeOptional "/etc/apache2/conf-available/expires-medium.conf"
  </Directory>
  # No PHP allowed in this directory
  <Directory "/home/wordpress/sites/dev/wp-content/uploads">
    <FilesMatch "\.php$">
      <If "-f %{REQUEST_FILENAME}">
        Require all denied
      </If>
    </FilesMatch>
  </Directory>
  CustomLog /var/log/apache2/wordpress_access.log bandwidth
  LogLevel error
  ErrorLog  /home/wordpress/logs/apache.error.log
  CustomLog /home/wordpress/logs/apache.access.log combinedio
</VirtualHost>

# vim: set ft=apache:

```


## TODO

* Add more options from the [Ansible user module](https://docs.ansible.com/ansible/latest/modules/user_module.html)
