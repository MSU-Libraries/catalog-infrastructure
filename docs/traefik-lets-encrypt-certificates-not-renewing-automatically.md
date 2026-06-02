# Traefik Let's Encrypt certificates not renewing automatically

Traefik runs as two separate services on the cluster, one as the keymaster, which requests
the certificate, and another traefik service that simply serves certificates. Each Traefik
container runs on only a single node, so only 1 node is assigned the responsibility
of requesting certificates.

There is a separate service called cert-sync that copies the certificates nightly
from the keymaster to shared storage and from the shared storage to each
of the other Traefik container's volumes.

Notes on this approach:

* If a new or renewed certificate is requested, it may take a few days
  for the other nodes to get it because the first night will be
  when it syncs it to the shared storage and the second night the other
  containers will get it.
* When new certificates are copied on to the non-keymaster containers,
  they need to be restarted to recognize these new certificates. By default
  there is not an automatic process for this. Certificates are renewed one
  month before they expire, so if you perform certain actions which restart
  those containres (re-deploy, Docker restart, or server reboot) then the
  cert syncing may occur without any extra effort.
* An automatic method for triggering the syncing can be accomplished via
  CI pipelines. For example, in Gilab, setting up a pipeline to run
  periodically (once or twice a day) can accomplish this by running the
  CI on the `main` branch with the variable `TRAEFIK_CERT_RELOAD` set to `1`.
  This will trigger a parital CI which provisions the cluster and then
  runs a limited Ansible playbook to force reload of the Traefik followers.

If you need to manually sync the certicates faster you can:

* Run this command **up to three times** to re-deploy the sync service:

```bash
# Service must be removed or the "timer" for restarting it will not reset
docker service rm cert-sync_cert-sync; sudo -Hu deploy docker stack deploy -c /home/deploy/core-stacks/docker-compose.cert-sync.yml cert-sync

# Running it multiple times allows for:
#  1. Keymaster to sync to shared storage
#  2. Traefik followers to sync from shared storage
```

* Restart the Traefik containers on the non-keymaster nodes:

```bash
# Run on nodes 2 and 3 in the cluster
docker stop $(docker ps -q -f name=traefik_traefik)

# Or with a single command on any node
docker service update --force traefik_traefik
```


