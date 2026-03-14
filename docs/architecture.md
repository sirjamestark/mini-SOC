# Architecture

MiniSOC monitors mirrored traffic from the home network using a Raspberry Pi.

## Network Flow

Router -> Managed Switch -> Raspberry Pi

The switch mirrors traffic to the Raspberry Pi, which captures and analyzes packets.

## Pipeline

1. Traffic is mirrored from the switch
2. Packets are captured with tcpdump
3. Detection scripts analyze activity
4. Events are written to logs
5. Correlation rules combine related events
6. Alerts are shown on the dashboard
7. Critical alerts can be sent by email

## Main Components

- `dns_watch.sh` -> detects unusual DNS activity
- `port_watch.sh` -> detects port scan behavior
- `correlate.sh` -> combines multiple events
- `mail_router.sh` -> handles alert notifications
- `dashboard_live.sh` -> shows live alerts
