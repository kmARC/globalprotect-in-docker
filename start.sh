#!/usr/bin/env bash
set -Eeuo pipefail
trap "echo Error in: \${FUNCNAME:-top level}, line \${LINENO}" ERR

VPN_SERVER="${1:-vpnctr.nashtech.com}"

VPN_ROUTES=(
  10.17.0.0/16
  10.130.0.0/16
  10.206.0.0/16
)

VPN_NAMESERVERS=(
  10.130.0.21
  10.130.0.22
)

trap 'cleanup' EXIT INT

cleanup() {
  for route in "${VPN_ROUTES[@]}"; do
    sudo ip route delete "$route" || true
  done
  for nameserver in "${VPN_NAMESERVERS[@]}"; do
    sudo sed -i "/^nameserver $nameserver$/d" /etc/resolv.conf
  done
}

for route in "${VPN_ROUTES[@]}"; do
  sudo ip route add "$route" via 172.17.0.2 dev docker0 || true
done
for nameserver in "${VPN_NAMESERVERS[@]}"; do
  if ! grep "^nameserver $nameserver$" /etc/resolv.conf; then
    sudo sed -i "1i nameserver $nameserver" /etc/resolv.conf
  fi
done

docker build -t gp .

# --privileged needed because glycin uses bwrap /o\
x11docker \
  --network \
  --sudouser \
  --share /dev/net/tun \
  --runasroot 'iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE' \
  --runasroot "echo '$USER ALL=(ALL) NOPASSWD: SETENV: /usr/bin/gpclient' >> /etc/sudoers" \
  --name gp \
  --home \
  --hostwayland \
  -- \
  --privileged \
  --sysctl net.ipv4.ip_forward=1 \
  --cap-add=ALL \
  -- \
  gp \
  sudo -E /usr/bin/gpclient --ignore-tls-errors --fix-openssl connect "$VPN_SERVER"

