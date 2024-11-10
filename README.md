# Custom NGINX + Passenger

This repo contains specific patches to avoid brief 502 Gateway Problem when NGINX reloads.

It works, but leaves PassengerAgent leaks over time because [the reap function](./passenger.diff) is commented out. To solve it, you need to put [the cleanup script](./cleanup.sh) in the cronjob.

## Building

```sh
make all
```
## Installing (Rocky Linux)

```sh
make install
```
