# Traefik Let's Encrypt certificates not renewing automatically

Traefik runs as host network mode on each node and DNS is normally configured to round robin between all nodes on a cluster.
This can lead to the situation where the Let's Encrypt certificate fails to renew before expiration
due to the round robin DNS not resolving to the correct node when performing a HTTP challenge.

This issue is something we have on our radar to investigate further and find a workaround for, but in
the mean time it may require a manual intervention to get the certificates to renew before expiration.

For context, Let's Encrypt certificates last for 3 months. They normally attempt to renew after 2 months have expired. If a certificate isn't over 2 months old, Traefik will not attempt to renew it.

To trigger the Let's Encrypt renewal process within Traefik to succeed for a given node (we'll
use `catalog-beta.lib.msu.edu` for the certificate hostname and `catalog-2.aws.lib.msu.edu` for the
node in this example):

* Change DNS for the hostname to the node where the certificate needs to be updated in your local DNS. In our case this is Libraries Windows DNS (manual process, requires Systems unit sysadmin to make change)
  * Example: Update `catalog-beta.lib.msu.edu` from the round robin production DNS of `catalog.aws.lib.msu.edu` to the specific node DNS of `catalog-2.aws.lib.msu.edu`
* If needing to update certs on multiple nodes, or to speed the DNS change back once completed, also reduce the DNS TTL for the record to 1 minute
* Wait several minutes longer than the original TTL (up to 10 more in some cases) to let DNS changes propagate
  * If the original TTL was 5 minutes, you may need to wait 10 to 15 minutes
* Connect to the node in question and `docker stop` the `traefik_traefik.xyz...` container to force it to restart; restarting Traefik will make it perform a new challenge attempt right away
  * Example: `ssh catalog-2.aws.lib.msu.edu` and `docker stop traefik_traefik.yqeqk81ltw.kaawo44qqtu`
* Wait up to two minutes for Traefik to start and the Let's Encrypt challange to complete
* Verify the new certificate is visible for the host
  * Beware using a browser to verify, as they like to cache everything; consider using the command line.
  * Example: `echo | openssl s_client -servername catalog-beta.lib.msu.edu -connect catalog-2.aws.lib.msu.edu:443 2>/dev/null | openssl x509 -nokeys -dates | head -n2`
    * Note in the above command where it the certificate hostname _and_ the node hostname are set
* If cert if not updated, be patient (10+ minutes) and try again restarting the Traefik container
* Once the new certificate is verified, proceed to change DNS to update any other certs than need manual assistance
* Once all certificates are okay, change DNS back to the round robin configuration and prior TTL
  * Example: Update `catalog-beta.lib.msu.edu` back to `catalog.aws.lib.msu.edu` with a TTL of 5 minutes

That should be all that's required.
