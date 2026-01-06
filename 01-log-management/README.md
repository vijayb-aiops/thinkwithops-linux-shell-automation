# Log Management & Analysis (Project 01)

## Problem Statement
Log directories grow quickly and stale log files consume disk, hiding real incidents and risking outages.

## Why This Matters in Production
When disks fill, services crash or enter read-only mode, paging teams and causing downtime; unmanaged logs also hide security signals.

## Solution Overview
Automated cleanup with safe defaults, reporting, and optional deletion, plus lightweight log insights for troubleshooting.

## Folder Structure (brief)
- src/: cleaner and analyzer scripts with shared config
- output/: reports, state, and runtime logs
- tests/: basic retention test harness
- cron/: sample schedule

## How to Run (include examples)
- dry-run cleanup: `./run.sh clean --dirs "/var/log /opt/app/logs" --retention 14 --dry-run`
- real cleanup: `./run.sh clean --dirs "/var/log" --run --report`
- generate report only: `./run.sh clean --report --dry-run`
- analyze logs: `./run.sh analyze --dir /var/log --pattern "*.log"`

## Safety Features
- dry-run default
- unsafe dir checks
- delete cap
- logging

## Automation Ready
- cron example location: `cron/log_cleaner.cron`

## Possible Extensions
- S3 upload of reports
- Slack notifications via webhook
- CI job integration
