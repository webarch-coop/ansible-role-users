# SSH Public Keys

The `authorized_keys` file in this directory has been automatically
assembled from the `authorized_keys_X` files (where `X` is a digit),
by [these Ansible tasks](https://git.coop/webarch/users/blob/master/tasks/ssh.yml),
if you wish to manually add keys to the `authorized_keys` file
please also save than as `authorized_keys_Y` in this directory,
(where `Y` is anything but a digit, for example a name or letter), 
in order that your public keys are included when the Ansible tasks
are next run.
