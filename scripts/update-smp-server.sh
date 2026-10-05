#!/bin/bash

# systemd has to be configured to use SIGINT to save and restore undelivered messages after restart.
# Add this to [Service] section:
# KillSignal=SIGINT
curl -L -o /opt/popopx/bin/smp-server-new https://github.com/simplex-chat/popopxmq/releases/latest/download/smp-server-ubuntu-20_04-x86-64
systemctl stop smp-server
cp /var/opt/popopx/smp-server-store.log /var/opt/popopx/smp-server-store.log.bak
mv /opt/popopx/bin/smp-server /opt/popopx/bin/smp-server-old
mv /opt/popopx/bin/smp-server-new /opt/popopx/bin/smp-server
chmod +x /opt/popopx/bin/smp-server
systemctl start smp-server
