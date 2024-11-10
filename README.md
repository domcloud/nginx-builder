# Custom NGINX + Passenger

This repo contains specific patches to avoid brief 502 Gateway Problem when NGINX reloads.

It works, but leaves PassengerAgent leaks over time because [the reap function](./passenger.diff) is commented out. To solve it, you need to put [the cleanup script](./cleanup.sh) in the cronjob.

## Building

```sh
make all
```
## Installing (Rocky Linux)

```sh
git clone https://github.com/domcloud/nginx-builder/ /usr/local/lib/nginx-builder
cd /usr/local/lib/nginx-builder/
make install

cat <<'EOF' > /usr/lib/systemd/system/nginx.service
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
# Nginx will fail to start if /run/nginx.pid already exists but has the wrong
# SELinux context. This might happen when running `nginx -t` from the cmdline.
# https://bugzilla.redhat.com/show_bug.cgi?id=1268621
ExecStartPre=/usr/bin/rm -f /run/nginx.pid
ExecStartPre=/usr/local/sbin/nginx -t
ExecStart=/usr/local/sbin/nginx
ExecReload=/usr/local/sbin/nginx -s reload
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=mixed
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
```
