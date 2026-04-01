#!/usr/bin/env bash
set -Eu
trap "echo Error in: \${FUNCNAME:-top level}, line \${LINENO}" ERR

VPN_SERVER="${1:-vpnctr.nashtech.com}"

VPN_ROUTES=(
  10.17.0.0/16 # socbn515, etc
  10.130.0.0/16 # DNS
  10.206.0.0/16
)

VPN_NAMESERVERS=(
  10.130.0.21
  10.130.0.22
)

trap 'cleanup_routes' EXIT

# Make sure sudo doesn't ask for password
sudo -v
while true; do sleep 1; sudo -n true; sleep 60; done &
SUDO_KEEPALIVE_PID=$!

# Trigger docker socket to make sure net devs are up
docker build -t gp .

cleanup_routes() {
  for route in "${VPN_ROUTES[@]}"; do
    sudo ip route delete "$route" || true
  done
  for nameserver in "${VPN_NAMESERVERS[@]}"; do
    sudo sed -i "/^nameserver $nameserver$/d" /etc/resolv.conf
  done

  kill "$SUDO_KEEPALIVE_PID"
}

setup_routes() {
  for route in "${VPN_ROUTES[@]}"; do
    sudo ip route add "$route" via 172.17.0.2 dev docker0 || true
  done
  for nameserver in "${VPN_NAMESERVERS[@]}"; do
    if ! grep "^nameserver $nameserver$" /etc/resolv.conf; then
      sudo sed -i "1i nameserver $nameserver" /etc/resolv.conf
    fi
  done
}

# --privileged needed because glycin uses bwrap /o\
x11docker \
    --network \
    --sudouser \
    --share /dev/net/tun \
    --runasroot "echo '$USER ALL=(ALL) NOPASSWD: SETENV: /usr/bin/gpclient' >> /etc/sudoers" \
    --runasroot "echo '$USER ALL=(ALL) NOPASSWD: SETENV: /usr/bin/bash'     >> /etc/sudoers" \
    --runasroot 'iptables -A POSTROUTING -t nat         -o tun0 -j MASQUERADE' \
    --runasroot 'iptables -A FORWARD            -i eth0 -o tun0 -j ACCEPT' \
    --runasroot 'iptables -A FORWARD            -i tun0 -o eth0 -j ACCEPT -m state --state RELATED,ESTABLISHED' \
    --name gp \
    --home \
    --hostwayland \
    -- \
    --privileged \
    --sysctl net.ipv4.ip_forward=1 \
    --cap-add=ALL \
    -- \
    gp \
    sudo -E /usr/bin/gpclient --ignore-tls-errors --fix-openssl connect "$VPN_SERVER" --disable-ipv6 \
2> >(
  while IFS= read -r line; do
      echo "Output: $line"
      if [[ "$line" == *"Connected to VPN"* ]]; then
          set -x
          setup_routes
          set +x
      elif [[ "$line" == *"openconnect_mainloop returned -5, exiting" ]]; then
          break
      fi
  done
)
