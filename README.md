# Ansible Debian Users Role 

This repository contains an Ansible role for adding user accounts to Debian servers.

To use this role you need to use Ansible Galaxy to install it into another repository under `galaxy/roles/users` by adding a `requirements.yml` file in that repo that contains:

```yml
---
- name: users
  src: https://git.coop/webarch/users.git
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
roles/galaxy
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
        home: /opt/foo
        shell: /bin/false
        system: yes
      bar:
        home: /var/www/bar
        system: yes
        shell: /usr/sbin/nologin
        generate_ssh_key: yes
        editor: vim
        groups:
          - ssl-cert
      baz:
        groups:
          - staff
          - users
        editor: vim
      chris:
        groups:
          - sudo
        editor: vim
        ssh_public_keys: https://git.coop/chris.keys 
    
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

## TODO

* Add the users dictionary to the `hosts.yml` file?
* Add more options from the [Ansible user module](https://docs.ansible.com/ansible/latest/modules/user_module.html)
