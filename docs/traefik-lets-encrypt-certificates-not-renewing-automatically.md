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
  they need to be restarted to recognize these new certificates. There is
  currently not an automatic process for this because Let's Encypt requests
  new certificates one month before they expire, so the logic being that we have
  a month for those certificates to sync to the non-keymaster nodes and for those
  containers to restart (due to re-deploy, Docker restart, or server reboot).

If you need to manually sync the certicates faster you can:

* Run this command **three times** to re-deploy the sync service:

```bash
docker service rm cert-sync_cert-sync; sudo -Hu deploy docker stack deploy -c /home/deploy/core-stacks/docker-compose.cert-sync.yml cert-sync
```

* Restart the Traefik containers on the non-keymaster nodes:

```bash
# Run on nodes 2 and 3 in the cluster
docker stop $(docker ps -q -f name=traefik_traefik)
```


