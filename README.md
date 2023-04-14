# Webarchitects Ansible Debian Users Role

[![pipeline status](https://git.coop/webarch/users/badges/master/pipeline.svg)](https://git.coop/webarch/users/-/commits/master)

This repository contains an Ansible role for adding user accounts to Debian
servers.

**Lots of documentation needs to be added to this file, what follows probably
isn't up to date, see the [releases](https://git.coop/webarch/users/-/releases)
for updates and changes, do not use the `master` branch for production, it is
used for development.**

For an example of a users YAML dictionary see [the users dictionary for the
development
server](https://git.coop/webarch/wsh/-/blob/master/host_vars/wsh.webarchitects.org.uk/vars.yml)
that is used for testing this role.

## Users update strategy

By default this role will update users defined in the `users` dictionary for
whom their YAML dictionary has changed (see [the defaults](defaults/main.yml)),
when their state is either *"present"* or *"absent"*, if their state is set to
*"ignore"* then the account will simply be ignored.

The reason for this is since running all the tasks in this role for all the
users takes a long time and usually runs a lot of tasks that won't make
changes.

In order to keep track of the users state, on the server (so that updates can
be applied from different places), YAML files for each user are written to
sub-directories of `/root/users` called, `current`, `previous` and `proposed`.

By setting the `users_update_strategy` variable to "all" (rather than the
default of "changed") all, rather than only users with a changed `users`
dictionary, will be updated.

Alternative update strategies can be specified by setting the
`users_update_strategy` variable to a few optional values as explained below.

### Update all users

```bash
ansible-playbook wsh.yml --extra-vars "users_update_strategy=all"
```

### Only run checks on users

```bash
ansible-playbook users.yml --extra-vars "users_update_strategy=check"
```

### Only update changed users

This is the default:

```bash
ansible-playbook users.yml --extra-vars "users_update_strategy=changed"
```

### Only update users Apache sites-available files

```bash
ansible-playbook users.yml --extra-vars "users_update_strategy=apache"
```

## Only update users disk quotas

```bash
ansible-playbook users.yml --extra-vars "users_update_strategy=quotas"
```

### Only update the firewall rules

```bash
ansible-playbook users.yml --extra-vars "users_update_strategy=firewall"
```

### Only update users PHP-FPM pool.d files

```bash
ansible-playbook users.yml --extra-vars "users_update_strategy=phpfpm"
```

### Update users SSH public keys

```bash
ansible-playbook users.yml --extra-vars "users_update_strategy=sshkeys"
```

### Updated users in additional groups

Update all users which have `users_groups` defined:

```bash
ansible-playbook users.yml --extra-vars "users_update_strategy=groups"
```

## How to use this role

To use this role you need to use Ansible Galaxy to install it into another
repository under `galaxy/roles/users` by adding a `requirements.yml` file in
that repo that contains:

```yaml
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

```yaml
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

```yaml
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

```yaml
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

## Cron jobs

If `users_cron` is defined and true, at a server level then for users that are
in the `chroot` group an hourly and daily cron job is created to run bash
scripts that are created (empty by default) at `~/bin/cron_daily.sh` and
`~/bin/cron_hourly.sh` in the chroot, for non-chrooted users a  cron job is
created to run the same bash scripts.

Tasks can be added to the Bash scripts using the `users_hourly_scripts` and
`users_daily_scripts` arrays at a user level, or they can be manually added not
using Ansible by users, for example to archive Matomo stats on an hourly basis:

```yaml
    users_hourly_scripts:
      - "cd ~/sites/default && php console --no-ansi -qn core:archive --force-all-websites > ~/private/matomo-archive.log"
      - "cd ~/sites/default && php console --no-ansi -qn core:run-scheduled-tasks > ~/private/matomo-archive.log"
```

The number of minutes part the hour that the script run at in set randomly for
each user and saved in `~/.cron_min` to ensure that all the jobs for different
users don't run at the same time.

Also many features of the [Ansible cron
module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/cron_module.html)
cane used used via a `users_cron_jobs` array set at the users level, for example:

```yaml
    users_cron_jobs:
      - name: printenv
        job: printenv
        minute: 2
      - name: echo foo
        job: echo foo
        state: absent
        minute: "*/5"
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

### Chrooting Apache, PHP-FPM and SSH

SSH and PHP-FPM users in the `chroot` group are chrooted to a a read-only
chroot at `/chroots/USER` which has `/home/USER` mounted read-write at
`/chroots/USER/home/USER`.

Apache, unlike SSH and PHP-FPM, which can have a seperate chroot per user, has
one chroot for the whole server, not one per user or `VirtualHost`, however
when combined with `suEXEC` which allows the group and user that runs scripts
via CGID or FastCGI to be set via `SuexecUserGroup` for CGI applications it is
possible to use the Apache chroot isolate users running CGI from the
environment in which other services are running.

One restriction that `suEXEC` has is to only allow CGI to be run in
sub-directories on `/var/www`, so to get around this when Apache is chrooted
users home directories are also mounted under `/var/www/users` and under the
same path in the Apache chroot and under the same path in the SSH / PHP-FPM
chroots.

The way this role has been designed to implement this is having a read-write
chroot at `/chroot` which is then mounted at `/chroots/www-data` read-only and
then on top of that `/home/USER` is mounted read-write at
`/chroots/www-data/home/USER` and also at
`/chroots/www-data/var/www/users/USER`.

In addition some other directories are automatically mounted to get it all to
work.  ### Options

Server wide settings for `VirtualHosts` can be set like this (see the commented
out variables in [defaults/main.yml](defaults/main.yml)):

```yaml
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

In addition there is support for `cgi` and `fcgi` together with Apache being
chrooted and running suEXEC to ensure the the processes run as the user
specified and have limited access to the host.

Support for enabling several `users_apache_type`'s is to be implemended and the
variable might be renamed to a more sensible `users_apache_handlers`.

The arrays, `users_apache_options`, `users_apache_index` and
`users_apache_override` can also be set by `VirtualHost` aand if they are these
overrule the other settings for the `DocumentRoot` directory, see the [Apache
template for the details](templates/apache.conf.j2).

Basic authentication can be set on the `DocumentRoot` directory, for example
for MediaWiki (the `VisualEditor` needs access via the `localhost`):

```yaml
        users_apache_auth_name: Private
        users_apache_auth_type: Basic
        users_apache_require:
          - valid-user
          - ip "{{ ansible_default_ipv4.address }}"
          - ip 127.0.0.1
```

The same `users_apache_htauth_users` array is used for the usernaes and
passwords as documented below.

### SetEnv

The `users_apache_env` array can be used to set and remove environmental
variables, at a server or `VirtualHost` level, via [the
`SetEnv`](https://httpd.apache.org/docs/current/mod/mod_env.html#setenv) and
[the
`UnsetEnv`](https://httpd.apache.org/docs/current/mod/mod_env.html#unsetenv)
Apache directives, for example:

```yaml
        users_apache_env:
          - env: FOO
            value: bar
          - env: BAZ
            set: false
```

Will generate:

```apache
SetEnv FOO bar
UnsetEnv BAZ
```

### SetEnvIf

The `users_apache_set_env_if` array can be used to set env vars, at a server or
`VirtualHost` level, using [the
`SetEnvIf`](https://httpd.apache.org/docs/current/mod/mod_setenvif.html#setenvif)
and [the
`SetEnvIfNoCase`](https://httpd.apache.org/docs/current/mod/mod_setenvif.html#setenvifnocase)
Apache directives, for example:

```yaml
        users_apache_set_env_if:
          - attribute: Host
            regex: "^(.*)$"
            env: THE_HOST=$1
            case: false
```
Will generate:

```apache
SetEnvIfNoCase Host "^(.*)$" THE_HOST=$1
```

And if `case` is omitted or set to `True`:

```apache
SetEnvIf Host "^(.*)$" THE_HOST=$1
```
Will generate:

```apache
SetEnvIf Host "^(.*)$" THE_HOST=$1
```

See the [Apache SetEnvIf documentation](https://httpd.apache.org/docs/current/mod/mod_setenvif.html).

### Header and RequestHeader

The `users_apache_headers` array can be used to set [Header](https://httpd.apache.org/docs/current/mod/mod_headers.html#header) and [RequestHeader](https://httpd.apache.org/docs/current/mod/mod_headers.html#requestheader) directives, at a `VirtualHost` level, for example:

```yaml
        users_apache_headers:
          - type: request
            action: set
            expr: "Content-Security-Policy: default-src 'self'"
          - type: request
            action: setifempty
            arg: X-Forwarded-Proto https
          - type: request
            action: setifempty
            arg: X-Forwarded-Host %{THE_HOST}e
```

The `response` header type accepts an optional condition, `con`, an action, `action` and an expression, `expr`, for example

```
Header {% if header.con is defined %}{{ header.con }} {% endif %}{{ header.action }} {{ header.expr }}
```

The `request` type accepts an action, `action` and an argument, `arg`:

```
RequestHeader {{ header.action }} {{ header.arg }}
```

### Alias and Redirect

The `users_apache_redirects` array can be used to generate
[`Redirect`](https://httpd.apache.org/docs/current/mod/mod_alias.html#redirect),
[`RedirectMatch`](https://httpd.apache.org/docs/current/mod/mod_alias.html#redirectmatch),
[`RedirectPermanent`](https://httpd.apache.org/docs/current/mod/mod_alias.html#redirectpermanent)
and
[`RedirectTemp`](https://httpd.apache.org/docs/current/mod/mod_alias.html#redirecttemp)
directives, for example:

```yaml
        users_apache_redirects:
          - path: /service
            url: http://foo2.example.com/service
            status: "301"
          - path: /one
            url: http://example.com/two
            status: permanent
          - regex_path: (.*)\.gif$
            url: http://other.example.com$1.jpg
          # Use a `regex_path` if you want any URL on the domain to be redirected to a specific page
          - regex_path: (.*)
            url: http://new.example.com/about
```

The `users_apache_alias` array can be used to generate
[`Alias`](https://httpd.apache.org/docs/current/mod/mod_alias.html#alias) and
[`AliasMatch`](https://httpd.apache.org/docs/current/mod/mod_alias.html#aliasmatch)
directives, for example:

```yaml
        users_apache_alias:
          - url: /image
            path: /ftp/pub/image
          - url: /icons/
            path: /usr/local/apache/icons/
          - regex_url: ^/icons(/|$)(.*)
            path: /usr/local/apache/icons$1$2
```

### Rewrite

The `users_apache_rewrite` array can be used to set `RewriteCond` and
`RewriteRule` directives, for example:

```yaml
        users_apache_rewrite_rules:
          - cond: %{HTTP_USER_AGENT} DavClnt
          - rule: ^$ /remote.php/webdav/ [L,R=302]
          - rule: .* - [env=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
          - rule: ^\.well-known/carddav /remote.php/dav/ [R=301,L]
          - rule: ^\.well-known/caldav /remote.php/dav/ [R=301,L]
          - rule: ^remote/(.*) remote.php [QSA,L]
          - rule: ^(?:build|tests|config|lib|3rdparty|templates)/.* - [R=404,L]
          - rule: ^\.well-known/(?!acme-challenge|pki-validation) /index.php [QSA,L]
          - rule: ^(?:\.(?!well-known)|autotest|occ|issue|indie|db_|console).* - [R=404,L]
```

To generate:

```apache
  RewriteEngine on
  RewriteCond %{HTTP_USER_AGENT} DavClnt
  RewriteRule ^$ /remote.php/webdav/ [L,R=302]
  RewriteRule .* - [env=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
  RewriteRule ^\.well-known/carddav /remote.php/dav/ [R=301,L]
  RewriteRule ^\.well-known/caldav /remote.php/dav/ [R=301,L]
  RewriteRule ^remote/(.*) remote.php [QSA,L]
  RewriteRule ^(?:build|tests|config|lib|3rdparty|templates)/.* - [R=404,L]
  RewriteRule ^\.well-known/(?!acme-challenge|pki-validation) /index.php [QSA,L]
  RewriteRule ^(?:\.(?!well-known)|autotest|occ|issue|indie|db_|console).* - [R=404,L]
```

### Location

The `users_apache_locations` array can be used to apply HTTP Authentication to
URL paths, for example:

```yaml
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

```yaml
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

```yaml
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

```yaml
        users_apache_locations:
          - location: old-site/
            redirect: https://example.org/
```

An `Alias` can also be used in a `Location`:
```yaml
        users_apache_locations:
          - location: /static
            alias: /home/foo/sites/www/staticfiles
```

And `ProxyPass` and `ProxyPassReverse` can be used in a `Location`, see [the
Apache ProxyPass documentation](https://httpd.apache.org/docs/2.4/mod/mod_proxy.html#proxypass):

```yaml
        users_apache_locations:
          - location: /push/
            proxy_pass: http://127.0.0.1:7867/
            reverse: true
          - location: /push/ws
            proxy_pass: ws://127.0.0.1:7867/ws
```

Results in:

```apache
  <Location "/push/" >
    ProxyPass "http://127.0.0.1:7867/"
    ProxyPassReverse "http://127.0.0.1:7867/
  </Location>
  <Location "/push/ws" >
    ProxyPass "ws://127.0.0.1:7867/ws"
  </Location>
```

### Directories

The `users_apache_directories` variable can be used at a `VirtualHost` level to
list dictionaries representing `Directory` directives, **relative to the
`users_sites_dir` path**. The variables that can be used are the same as the
ones for the `DocumentRoot` directory apart from `users_apache_type`, this
can't be used to set the `Directory` type to `php` or `static`.

Prior to version `3.0.0` of this role `users_apache_directories` was used for
an array of directories and when it was used the default `DocumentRoot` /
`Directory` was omitted, from version `3.0.0` and up a dictionary rather than
an array is used and the default `DocumentRoot` / `Directory` can be ommitted
by setting `users_apache_vhost_docroot` to `False`.

This is handy when some directories are needed for static
content and `Alias` and also a proxy, for example:

```yaml
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

The following variables can be used to control the content of the `Directory` directive:

#### users_apache_add_output_filters

A list of [AddOutputFilter directives](https://httpd.apache.org/docs/current/mod/mod_mime.html#addoutputfilter), for example:

```yaml
        users_apache_add_output_filters:
          - INCLUDES;DEFLATE shtml
```

Will generate:

```apache
    AddOutputFilter INCLUDES;DEFLATE shtml
```

#### users_apache_add_type

A list of MIME types and extensions for [AddType](https://httpd.apache.org/docs/current/mod/mod_mime.html#addtype), for example:

```yaml
        users_apache_add_type:
          - ext: bar
            type: text/plain
```

Will generate:

```apache
    AddType text/plain .bar
```

Note that the dot before the file extensions is added automatically.

#### users_apache_auth_name

A [AuthName](https://httpd.apache.org/docs/2.4/mod/mod_authn_core.html#authname), for example:

```yaml
        users_apache_auth_name: Authentication Required
```

```apache
      AuthName Authentication Required
```

#### users_apache_auth_type

A [AuthType](https://httpd.apache.org/docs/2.4/mod/mod_authn_core.html#authtype), when set to `Basic` a [AuthUserFile](https://httpd.apache.org/docs/2.4/mod/mod_authn_file.html#authuserfile) directive is automatically added to point to the htpasswd for for the VirtualHost, for example:

```yaml
        users_apache_auth_type: Basic
```

```apache
      AuthType Basic
      AuthUserFile: /home/example/.htpasswd/foo
```

The other options, `Digest` and `Form` and `None` can be used but they don't add any additional directives.

#### users_apache_expires

Set `users_apache_expires` to one of these values:

* forever
* medium
* strict

For one of the [Apache role](https://git.coop/webarch/apache) templates to be added as a `IncludeOptional` for the `Directory`:

* [expires-forever.conf](https://git.coop/webarch/apache/-/blob/master/templates/expires-forever.conf.j2)
* [expires-medium.conf)](https://git.coop/webarch/apache/-/blob/master/templates/expires-medium.conf.j2)
* [expires-strict.conf](https://git.coop/webarch/apache/-/blob/master/templates/expires-strict.conf.j2)

#### users_apache_filesmatch

A list of[FilesMatch](https://httpd.apache.org/docs/2.4/mod/core.html#filesmatch) and [Require]() directives for example:

```yaml
        users_apache_filesmatch:
          - regex: "^(?<sitename>[^/]+)"
            require:
              - "ldap-group cn=%{env:MATCH_SITENAME},ou=combined,o=Example"
```

```apache
<FilesMatch "^(?<sitename>[^/]+)">
    Require ldap-group cn=%{env:MATCH_SITENAME},ou=combined,o=Example
</FilesMatch>
```

If `require` is omitted then it will default to `Require all denied`.

#### users_apache_header_name

A values for the [HeaderName](https://httpd.apache.org/docs/current/mod/mod_autoindex.html#headername), for example:

```yaml
        users_apache_header_name: HEADER.html
```

```apache
HeaderName HEADER.html
```

#### users_apache_index

A list of file names for the [DirectoryIndex](https://httpd.apache.org/docs/2.4/mod/mod_dir.html#directoryindex) directive, for example:

```yaml
        users_apache_index:
          - index.htm
          - index.html
          - index.php
```

```apache
DirectoryIndex index.htm index.html index.php
```

#### users_apache_index_head_insert

Text for the [IndexHeadInsert](https://httpd.apache.org/docs/2.4/mod/mod_autoindex.html#indexheadinsert) directive, for example:

```yaml
        users_apache_head_insert: '<link rel=\"sitemap\" href=\"/sitemap.html\">'
```

```apache
IndexHeadInsert '<link rel=\"sitemap\" href=\"/sitemap.html\">'
```

#### users_apache_index_options

A list of options for the [IndexOptions](https://httpd.apache.org/docs/2.4/mod/mod_autoindex.html#indexoptions), for example:

```yaml
        users_apache_index_options:
          - +ScanHTMLTitles
          - -IconsAreLinks
          - FancyIndexing
```

```apache
IndexOptions +ScanHTMLTitles -IconsAreLinks FancyIndexing
```

#### users_apache_options
#### users_apache_override
#### users_apache_readme_name

A values for the [ReadmeName](https://httpd.apache.org/docs/current/mod/mod_autoindex.html#readmename), for example:

```yaml
        users_apache_readme_name: FOOTER.html
```

```apache
ReadmeName FOOTER.html
```

#### users_apache_require

A list of requirements for the Apache [Require](https://httpd.apache.org/docs/2.4/mod/mod_authz_core.html#require) directive, for example:

```yaml
        users_apache_require:
          - ip 10 172.20 192.168.2
          - method http-method GET HEAD
```

```apache
Require ip 10 172.20 192.168.2
Require method http-method GET HEAD
```

#### users_apache_ssi_legacy

A boolean, enable the [SSILegacyExprParser](https://httpd.apache.org/docs/2.4/mod/mod_include.html#ssilegacyexprparser).

#### users_apache_ssi_modified

A boolean, enable [SSILastModified](https://httpd.apache.org/docs/2.4/mod/mod_include.html#ssilastmodified).

### Reverse Proxy

Configure a reverse proxy, for example for a [Nextcloud notify_push
server](https://github.com/nextcloud/notify_push#apache) like this you can
specify:

```yaml
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

```yaml
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

For an
[ONLYOFFICE](https://github.com/biva/documentation/blob/biva/admin_manual/configuration_server/onlyoffice_configuration.rst)
server:

```yaml
        users_apache_set_env_if:
          - attribute: Host
            regex: "^(.*)$"
            env: THE_HOST=$1
        users_apache_headers:
          - type: request
            action: setifempty
            argument: X-Forwarded-Proto https
          - type: request
            action: setifempty
            argument: X-Forwarded-Host %{THE_HOST}e
        users_apache_proxy_pass:
          - add_headers: false
            path: /.well-known
            url: !
          - pathmatch: (.*)(\/websocket)$
            url: "ws://127.0.0.1:8006/$1$2"
          - path: /
            url: http://127.0.0.1:8006/
            reverse: true
```

A reverse proxy to an applicaton that doesn't have any user authentication can be configured to use HTTP Authentication, for example for [Mailcatcher](https://git.coop/webarch/mailcatcher):

```yaml
        users_apache_proxy_pass:
          - path: /
            url: http://127.0.0.1:1080/
            reverse: true
            htauth: true
        users_apache_htauth_users:
          - name: mailcatcher
            password: foo
```

By default the reverse proxy doesn't proxy error documents served from `/wsh`:

```apache
    ProxyErrorOverride On
    ProxyPass "/wsh/" "!"
```

### FilesMatch

If an `users_apache_filesmatch` array specified at the `VirtualHost` level with
a list of `regex` like this:

```yaml
        users_apache_filesmatch:
          - regex: '^license\.txt$'
          - regex: '^readme\.html$'
          - regex: '^xmlrpc\.php$'
```

Then access to these files will be denied, unless one of more `require` items
are listed, for example:

```yaml
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

```yaml
        users_apache_nophp_dirs:
          - wp-content/uploads
```

In order to enable PHP settings for the CLI to be configured differently for each user this Bash alias is written to `~/.bash_aliases`:

```bash
alias php="php --php-ini ~/.php.ini"
```

And `~/.php.ini` is created with the following three lines (with `example` replaced with the username):

```
sys_temp_dir = "/home/example/tmp"
memory_limit = -1
apc.enable_cli = 1
```

Setting `memory_limit = -1` overides the default of 128M, this is required for the Nextcloud CLI updater.

By default, for users in the `phpfpm` group, the PHP socket is created in the `$HOME` directory as `~/php-fpm.sock`, the use of this path by the Apache configuratoon can be overridden when Apache is not chrooted and the users is not chrooted, per `VirtualHost` by setting `users_apache_php_socket_path` to a path to another socket _however_ this variable is not used by this roles PHP tasks, the socket configuration needs to be done by the [PHP role](https://git.coop/webarch/php).

### Example Apache VirtualHost

If a user has a set of variables like this:

```yaml
    users_apache_virtual_hosts:
      default:
        users_apache_type: php
        users_apache_php_socket_path: /run/php/php8.2-fpm.sock
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
