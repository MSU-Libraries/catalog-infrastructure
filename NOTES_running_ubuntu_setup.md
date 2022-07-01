# Solving how to run the ubuntu-setup playbook

## Problems
- Should be run from ansible server
  - As it copies local files from user directories (which are only on ansible, not runner)
  - It add entries to known_hosts file for ansible user, as it is normally first run by another user

## Ideas
- New user `ubuntusetup` on ansible server which
  - Can ONLY run ubuntu setup (via `sudo` to ansible user)
  - Would need `ansible` user pre-created (we already have this in `user_data.sh`)
  - Need a pre-script to scan and add known_hosts entries to allow ansible to run it?

## Be Aware
- This does not involve adding anything into the `ansible@ansible` /etc/ansible/hosts.yml file
  - This may still be a manual process afterwards
  - Will then need to re-scan and add hostname keys to known_hosts
