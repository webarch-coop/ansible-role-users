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

If you want to use any of the `quota_` variables then you also need to include the [quota role](https://git.coop/webarch/quota) and makse sure that `quota_dir` is set to a mount point for a partition, for example have a seperate `/home` partition.

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
        users_name: Foo Bar
        users_email: foo@example.org
        users_home: /var/www/foo
        users_skel: www
        users_group: users
        users_home_owner: root
        users_home_group: users
        # You must quote the mode or the leaving zero is stripped"
        users_home_mode: "0750"
        users_system: yes
        users_shell: /usr/sbin/nologin
        users_generate_ssh_key: yes
        users_editor: vim
        users_groups:
          group1: users
          group2: ssl-cert
      bar:
        users_home: /opt/bar
        users_shell: /bin/false
        users_system: yes
        users_quota: 1G
      baz:
        users_groups:
          group1: staff
          group2: users
        users_editor: vim
        users_quota_block_softlimit: 1908874
        users_quota_block_hardlimit: 2097152
        users_quota_inode_softlimit: 9532
        users_quota_inode_hardlimit: 10484
      chris:
        users_groups:
          group1: sudo
        users_editor: vim
        users_ssh_public_keys: https://git.coop/chris.keys 
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

## TODO

* Add the users dictionary to the `hosts.yml` file?
* Add more options from the [Ansible user module](https://docs.ansible.com/ansible/latest/modules/user_module.html)
