#!/bin/sh
# node_exporter on the fck-nat instance (Amazon Linux 2023). Runs once at first boot;
# a failure here doesn't affect NAT. Reachable only from the VPC (fck-nat SG).
set -eu

dir="node_exporter-${version}.linux-${arch}"
cd /tmp
curl -fsSLo node_exporter.tar.gz "https://github.com/prometheus/node_exporter/releases/download/v${version}/$dir.tar.gz"
echo "${sha256}  node_exporter.tar.gz" | sha256sum -c -
tar xzf node_exporter.tar.gz
install -m 0755 "$dir/node_exporter" /usr/local/bin/node_exporter
rm -rf node_exporter.tar.gz "$dir"

id node_exporter >/dev/null 2>&1 || useradd --system --no-create-home --shell /sbin/nologin node_exporter

cat > /etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Prometheus node_exporter
After=network-online.target
Wants=network-online.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:${port}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now node_exporter
