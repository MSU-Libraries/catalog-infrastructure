# Mounting the Shared Storage
To mount the shared storage (`/mnt/shared/local` on the nodes) on your local machine, use
the credentials for the same user as used by Solr and the Traefik Dashboard). To mount,
we will be making use of the `sshfs` tool.

For more information on this share see the
[technical documentation](https://msu-libraries.github.io/catalog/first-time-setup/#for-local-development).

**Permissions on Server**  
The shared storage on the server will need to be writable by the connecting user. For example, if the
storage us group writable by the `ubuntu` user, the user on the server will needt o be in the `ubuntu`
group. This can be done by adding the group to the user in `configure-playbook/variables.yml` CI
variable, `VARIABLE_YAML_FILE` and then triggering the CI process.
```
 - name: myuser
   comment: 'Myu Ser'
   groups: ubuntu
   public_keys:
```

## MacOS
Mac users will require macFUSE and sshfs to be installed separately before continuing.
The latest release is available on the [osxfuse GitHub site](https://osxfuse.github.io/).

Locally on the Mac mounting the share, you'll have to make it think it also has permissions to write.
For example, if the server has the `ubunbu` group as writable with gid of `1000`, you'll need to
configure you Mac to also have a group with gid `1000` that your user

To create the new group and add your user `myuser`:
```sh
# Create group ubuntu with gid 1000
sudo dscl . -create /groups/ubuntu gid 1000
# Add user myuser to ubuntu group
sudo dscl . -append /Groups/ubuntu GroupMembership myuser
```

From there you should be able to create a directory to mount from and mount as your normal user (no `sudo`):
```sh
# Only need to create the directory the first time
mkdir ~/my-sshfs

sshfs -o allow_other,default_permissions myuser@catalog-1.aws.lib.msu.edu:/mnt/shared/local ~/my-sshfs
```

To unmount:
```sh
umount ~/my-sshfs 
```

## Linux
Before attempting to mount, you will need `sshfs`. To install:
```bash
$ sudo apt install sshfs
```

Here is an example of mounting the share (to and example `/mnt/point/` directory) for a single time (not auto-remounted):
```bash
sudo sshfs -o allow_other,default_permissions [netid]@catalog-1.aws.lib.msu.edu:/mnt/shared/local /mnt/point
```

Here is an example of an `/etc/fstab` entry for mounting it:
```bash
[netid]@catalog-1.aws.lib.msu.edu:/mnt/shared/local /mnt/point fuse.sshfs noauto,x-systemd.automount,_netdev,reconnect,identityfile=/home/[netid]/.ssh/id_ed25519,allow_other,default_permissions 0 0
```

To mount:
```bash
$ sudo mkdir -p /mnt/catalog
$ sudo mount /mnt/catalog
$ sudo umount /mnt/catalog
```
