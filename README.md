# Ansible Debian Users Role 

[![pipeline status](https://git.coop/webarch/users/badges/master/pipeline.svg)](https://git.coop/webarch/users/-/commits/master)

This repository contains an Ansible role for adding user accounts to Debian
servers.

**Lots of documentation needs to be added to this file, what follows probably
isn't up to date, see the [releases](https://git.coop/webarch/users/-/releases)
for updates and changes, do not use the `master` branch for production, it is
used for development.**

To use this role you need to use Ansible Galaxy to install it into another
repository under `galaxy/roles/users` by adding a `requirements.yml` file in
that repo that contains:

```yml
---
- name: users
  src: https://git.coop/webarch/users.git
  version: master
  scm: git
```

If you want to use any of the `quota_` variables then you also need to include
the [quota role](https://git.coop/webarch/quota) and make sure that `quota_dir`
is set to a mount point for a partition, for example have a seperate `/home`
partition.

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

## Debugging

If `users_update_strategy: check`, for example on the command line using
`--extra-vars "users_update_strategy=true"` then no changes will be made other
than to generate `/root/users/proposed/*.yml` state files.

If `users_domain_check` is set to `strict` then if a domain name doesn't
resolve to the servers IP address then the tasks will stop rather than just
warn.

So, for example:

```bash
ansible-galaxy install -r requirements.yml --force && \
  ansible-playbook users.yml --extra-vars "users_update_strategy=check"
```

## SSH Public Keys

The `users_ssh_public_keys` array should be set to a list of one or more URL's
for public keys (eg from GitHub).

All the files at the URL's will be downloaded to files named:

* `~/.ssh/authorized_keys.d/authorized_keys_0`
* `~/.ssh/authorized_keys.d/authorized_keys_1`
* `~/.ssh/authorized_keys.d/authorized_keys_2`

Then the `~/.ssh/authorized_keys.d/authorized_keys_*` files are assembled to
`~/.ssh/authorized_keys`, (inless this file name is overridden from the
default, see the users_ssh_authorized_keys_file_name variable) this means if
you want to add additional keys then you can simply add them to this directory,
with a suitable filename, eg `~/.ssh/authorized_keys.d/authorized_keys_extra`. 

## Apache

By default a `DocumentRoot` and `Directory` set of directives are generated for
each `VirtualHost` based on the YAML dictionaries defined by
`users_apache_virtual_hosts`. This `DocumentRoot` and `Directory` will be
omitted if `users_apache_vhost_docroot` is set to `False` at a `VirtualHost`
level (prior to version `3.0.0` of this role the `users_apache_vhost_docroot`
was not a boolean and could be set to a path, however this wasn't used so it
was re-purposed) . Additional `Directory` sections can be added using
`users_apache_directories` at a `VirtualHost` level.

### Options

Server wide settings for `VirtualHosts` can be set like this (see the commented
out variables in [defaults/main.yml](defaults/main.yml)):

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

If these variables ar not set server-wide then the `users_apache_type` variable
can be used per `VirtualHost` and if it is set to `php` then these directives
are used:

```apache
Options -Indexes +SymlinksIfOwnerMatch -MultiViews +IncludesNOEXEC -ExecCGI
DirectoryIndex index.php index.html index.htm index.shtml
AllowOverride AuthConfig FileInfo Indexes Limit Options=Indexes,SymLinksIfOwnerMatch,MultiViews,IncludesNOEXEC Nonfatal=Override
```

And if `users_apache_type` is set to `cgi` then these directives are used:

```apache
Options -Indexes +SymlinksIfOwnerMatch -MultiViews +IncludesNOEXEC +ExecCGI
DirectoryIndex index.cgi index.pl index.html index.htm index.shtml
AllowOverride AuthConfig FileInfo Indexes Limit Options=ExecCGI,SymLinksIfOwnerMatch,MultiViews,IncludesNOEXEC Nonfatal=Override
```

And if `users_apache_type` is omitted (or set to a value such as `static`) then
these defaults are used:

```apache
Options -Indexes +SymlinksIfOwnerMatch -MultiViews +IncludesNOEXEC -ExecCGI
DirectoryIndex index.html index.htm index.shtml
AllowOverride AuthConfig FileInfo Indexes Limit Options=Indexes,SymLinksIfOwnerMatch,MultiViews,IncludesNOEXEC Nonfatal=Override
```

The arrays, `users_apache_options`, `users_apache_index` and
`users_apache_override` can also be set by `VirtualHost` aand if they are these
overrule the other settings for the `DocumentRoot` directory, see the [Apache
template for the details](templates/apache.conf.j2).

Basic authentication can be set on the `DocumentRoot` directory, for example
for MediaWiki (the `VisualEditor` needs access via the `localhost`):

```yml
        users_apache_auth_name: Private
        users_apache_auth_type: Basic
        users_apache_require:
          - valid-user
          - ip "{{ ansible_default_ipv4.address }}"
          - ip 127.0.0.1
```

The same `users_apache_htauth_users` array is used for the usernaes and
passwords as documented below.

### Location

The `users_apache_locations` array can be used to apply HTTP Authentication to
URL paths, for example:

```yml
        users_apache_locations:
          - authname: WordPress Login
            location: /wp-login.php
          - authname: WordPress Admin
            location: /wp-admin/
          - authname: WordPress Admin Ajax
            location: /wp-admin/admin-ajax.php
            authtype: None
            require:
              - all granted
          - authname: WordPress Config
            location: /wp-config.php
            authtype: None
            require:
              - all denied
```

The `users_apache_htauth_users` array can be used to set usernames and
passwords, these are written to `~/.htpasswd/` in one file per
`users_apache_server_name`, the optional `state` variables can be set to absent
to remove users, for example:

```yml
        users_apache_htauth_users:
          - name: foo
            password: bar
          - name: baz
            state: absent
```

If the `authtype` is set to `None` then `AuthUserFile` isn't set and then a
`require` array can be set [to do things like only allow a few IP
addresses](https://httpd.apache.org/docs/current/mod/mod_authz_core.html#require),
for example:

```yml
        users_apache_locations:
          - authname: Drupal Login
            location: /user/login
            authtype: None
            require:
              - ip 10 172.20 192.168.2
              - method GET POST
```

It is also possible to set `Redirect`, see [the Apache
Documentation](https://httpd.apache.org/docs/2.4/mod/mod_alias.html#redirect):

```yml
        users_apache_locations:
          - location: old-site/
            redirect: https://example.org/
```

An `Alias` can also be used in a `Location`:
```yml
        users_apache_locations:
          - location: /static
            alias: /home/foo/sites/www/staticfiles
```

### Directories

The `users_apache_directories` variable can be used at a `VirtualHost` level to
list dictionaries representing `Directory` directives, **relative to the
`users_sites_dir` path**. The variables that can be used are the same as the
ones for the `DocumentRoot` directory apart from `users_apache_type`, this
can't be used to set the `Ditectory` type to `php` or `static`.

Prior to version `3.0.0` of this role `users_apache_directories` was used for
an array of directories and when it was used the default `DocumentRoot` /
`Directory` was omitted, from version `3.0.0` and up a dictionary rather than
an array is used and the default `DocumentRoot` / `Directory` can be ommitted
by setting `users_apache_vhost_docroot` to `False`.

This is handy when some directories are needed for static
content and `Alias` and also a proxy, for example:

```yml
    users_apache_virtual_hosts:
      api:
        users_apache_type: static
        users_apache_server_name: "api.{{ inventory_hostname }}"
        users_apache_alias:
          - url: /static
            path: /home/api/sites/api/staticfiles
          - url: /media
            path: /home/api/sites/api/media
        users_apache_directories:
          api/static:
            users_apache_options:
              - Indexes
          api/media:
            users_apache_options:
              - Indexes
        users_apache_proxy_pass:
          - path: /static
            url: "!"
          - path: /media
            url: "!"
          - path: /
            url: http://127.0.0.1:8000/
            reverse: true
```

And this will generate:

```apache
  Alias "/static" "/home/api/sites/api/staticfiles"
  Alias "/media" "/home/api/sites/api/media"
  <Directory "/home/api/sites/api/staticfiles">
    Options Indexes
    AllowOverride None
    Require all granted
  </Directory>
  <Directory "/home/api/sites/api/media">
    Options Indexes
    AllowOverride None
    Require all granted
  </Directory>
  ProxyPass "/static" "!"
  ProxyPass "/media" "!"
  ProxyPass "/" "http://127.0.0.1:8000/"
  ProxyPassReverse "/" "http://127.0.0.1:8000/"
```

If no Directories are required use `users_apache_directories: []`.

### Reverse Proxy

Configure a reverse proxy, for example for a [Nextcloud notify_push
server](https://github.com/nextcloud/notify_push#apache) like this you can
specify:

```yml
        users_apache_proxy_pass:
          - path: /push/ws
            url: ws://127.0.0.1:7867/ws
          - path: /push/
            url: http://127.0.0.1:7867/
            reverse: true
```

And this will generate:

```apache
  ProxyPass "/push/ws" "ws://127.0.0.1:7867/ws"
  ProxyPass "/push/" "http://127.0.0.1:7867/"
  ProxyPassReverse "/push/" "http://127.0.0.1:7867/"
```

For a [reverse
proxy](https://docs.rocket.chat/installing-and-updating/manual-installation/configuring-ssl-reverse-proxy#running-behind-an-apache-ssl-reverse-proxy)
to a [Rocket.Chat server installed using
snaps](https://docs.rocket.chat/installing-and-updating/snaps):

```yml
        users_apache_proxy_pass:
          - path: /
            url: http://127.0.0.1:3000/
            rewrite_conditions:
              - '%{HTTP:Upgrade} websocket [NC]'
              - '%{HTTP:Connection} upgrade [NC]'
            rewrite_rules:
              - '^/?(.*) "ws://127.0.0.1:3000/$1" [P,L]'
            reverse: true
```

And this will generate:

```apache
  ProxyPass "/" "http://127.0.0.1:3000/"
  RewriteEngine on
  RewriteCond %{HTTP:Upgrade} websocket [NC]
  RewriteCond %{HTTP:Connection} upgrade [NC]
  RewriteRule ^/?(.*) "ws://127.0.0.1:3000/$1" [P,L]
  ProxyPassReverse "/" "http://127.0.0.1:3000/"
```

### FilesMatch

If an `users_apache_filesmatch` array specified at the `VirtualHost` level with
a list of `regex` like this:

```yml
        users_apache_filesmatch:
          - regex: '^license\.txt$'
          - regex: '^readme\.html$'
          - regex: '^xmlrpc\.php$'
```

Then access to these files will be denied, unless one of more `require` items
are listed, for example:

```yml
        users_apache_filesmatch:
          - regex: '^xmlrpc\.php$'
            require:
              - method GET HEAD
              - ip 9.9.9.9
```

### Expires

The optional `users_apache_expires` variable can be used to select the
[medium](https://git.coop/webarch/apache/blob/master/templates/expires-medium.conf.j2)
or
[strict](https://git.coop/webarch/apache/blob/master/templates/expires-strict.conf.j2)
configuration to `Include` into the `VirtualHost`.

### Robots

The optional `users_apache_robots` variable can be set to `deny` to `Include`
the [robots
config](https://git.coop/webarch/apache/blob/master/templates/robots-deny.conf.j2)
and this will also set an `Alias` for the
[robots.txt](https://git.coop/webarch/apache/blob/master/templates/robots.deny.txt.j2)
file.

### PHP

Some specific PHP variables include the `users_apache_nophp_dirs` array, this
can be used to list directories that PHP cannot be used in, for example
directories where users can upload files, for example:

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

* Generate a CHANGELOG.md from the
  [releases](https://git.coop/webarch/users/-/releases) perhaps using [Release
  Exporter](https://github.com/akshaybabloo/release-exporter)

* Better documentation

* [Better CMS options](https://git.coop/webarch/users/issues/29)

* Add more options from the [Ansible user
  module](https://docs.ansible.com/ansible/latest/modules/user_module.html)
