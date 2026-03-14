# MiniSOC

MiniSOC is a lightweight home Security Operations Center (SOC) built on a Raspberry Pi.
The goal of this project is to understand how a basic SOC monitoring pipeline works in practice: collecting network traffic, detecting anomalies, correlating events and generating alerts.
The system monitors mirrored network traffic and can detect suspicious activity such as DNS anomalies and port scanning attempts.

---

## Architecture

- Router → Managed Switch (Port Mirroring) → Raspberry Pi → Detection Scripts → Alerts / Dashboard
- Network traffic is mirrored from the switch to the Raspberry Pi where detection scripts analyze the activity and generate alerts.

---

## Features

- DNS anomaly detection
- Port scan detection
- Event correlation
- Severity-based alerting
- Real-time terminal dashboard
- Email alerts for critical events

---

## Stack

- Raspberry Pi 5
- Ubuntu
- tcpdump
- Bash
- systemd

---

## How It Works

1. Network traffic is mirrored from the switch.
2. The Raspberry Pi captures packets using tcpdump.
3. Detection scripts analyze DNS and connection behavior.
4. Events are written to logs.
5. Correlation rules combine related events.
6. Alerts are displayed on the dashboard and critical alerts can trigger notifications.

---

## Project Report

Full project report:

[MiniSOC Report](docs/minisoc-report.pdf)

---

## Why Raspberry Pi?

Raspberry Pi provides a low-cost platform to build cybersecurity labs and experiment with monitoring systems in a real network environment.

---

## Status

Working prototype. The system will be improved with additional detection rules and expanded correlation logic.
