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

  user_accounts:
    - name: foo
      home: /home/foo
      shell: /bin/bash
      system: no
      groups: sudoers
      # the following variables are optional
      ssh_public_keys: https://git.coop/foo.keys
      # vim is currently the only supported editor
      editor: vim
    - name: bar
      home: /var/www/foo
      shell: /bin/false
      system: yes
      groups: ssl-cert
      # the following variables are optional
      # ssh_public_keys: 
      # vim is currently the only supported editor
      editor: vim
    
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

* Make these variables default to sensible values if not set:
   * home: `/home/{{ item.name }}`
   * shell: `/bin/bash`
   * system: `no`
   * groups: `""`
