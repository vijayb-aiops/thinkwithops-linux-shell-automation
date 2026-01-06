# 🧹 Project 1 – Log Cleaner (Interview Explanation)

## STAR Points

**S – Situation**  
A production server went down at 3 AM because disk usage hit 98%.  
Root cause: endless log files in `/var/log` filling the disk.  
Applications crashed, users were locked out, and services froze.

**T – Task**  
Recover the server immediately and build a long-term automated solution  
so that old log files would never again cause outages.

**A – Action**  
- Wrote a Bash script to monitor disk usage and clean logs older than 7 days.  
- Added a **dry-run mode** for safety (preview before deletion).  
- Implemented detailed logging of every action to timestamped files.  
- Introduced a `--force` flag for non-interactive automation (cron jobs).  
- Scheduled it with cron to run daily, storing logs in `/var/log/log_cleaner_cron_YYYYMMDD.log`.

**R – Result**  
- Server restored within minutes, disk usage dropped immediately.  
- Prevented repeat incidents: no disk-related outages afterwards.  
- Improved uptime, stability, and confidence in production operations.  
- Reduced firefighting → freed up the team to focus on proactive work.

---

## Short Version (30–40 sec)

*"We once had a production server go down at 3 AM because disk usage hit 98% due to uncontrolled log growth. My task was to restore the server and prevent this from happening again. I built a Bash script that checks disk usage, deletes logs older than 7 days, and logs every action. It includes a dry-run mode for safety and a `--force` flag for cron automation. Once deployed, the script restored space instantly and completely eliminated log-related outages, improving uptime and reducing firefighting."*

---

## Long Version (2–3 min)

*"At one point, we faced a serious incident at 3 AM when a production server stopped responding. Disk usage had reached 98%, caused by uncontrolled growth of log files in `/var/log`. Applications crashed, services froze, and users were locked out.  

My responsibility was not only to recover the server quickly but also to ensure this problem never happened again.  

I created a Bash script that continuously monitors disk usage, finds logs older than 7 days, and deletes them safely. To make it robust, I added multiple features: a **dry-run mode** to preview deletions without risk, a **detailed logging system** so every action is timestamped and auditable, and a `--force` flag so the script could run unattended via cron. Finally, I automated it with a cron job scheduled daily, storing per-day logs in `/var/log/log_cleaner_cron_YYYYMMDD.log`.  

The results were immediate. On the first run, disk usage dropped and the server recovered within minutes. More importantly, after automation, we never experienced a disk-full outage again. This significantly improved uptime and reliability, reduced late-night firefighting, and gave the team confidence that this risk was fully controlled. Overall, it demonstrated how automation, observability, and proactive maintenance can directly improve system stability."*

---

# Log Cleanup Script Flowchart Analysis

## Overview
This flowchart represents a comprehensive **log file cleanup script** designed to manage disk space by removing old log files based on configurable age thresholds.

## Key Components and Parameters

### Configuration Variables
- `LOG_DIR`: Directory containing log files to be processed
- `DAYS_OLD`: Age threshold (in days) for files to be considered for deletion
- `LOG_FILE`: Location where script actions and results are recorded

### Command Line Arguments
- `--dry-run`: Test mode that shows what would be deleted without actually removing files
- `--force`: Skip user confirmation prompts for automated execution

## Workflow Breakdown

### 1. Initialization Phase
- **Start Script**: Entry point
- **Load Configuration**: Reads the three main parameters (LOG_DIR, DAYS_OLD, LOG_FILE)
- **Parse Arguments**: Processes command-line flags (--dry-run, --force)

### 2. Validation Phase
- **Directory Check**: Verifies that the specified `$LOG_DIR` exists
- **Show Disk Usage (Before)**: Captures initial disk space usage for comparison

### 3. File Discovery Phase
- **Build Find Command**: Creates a command to locate files older than N days in the log directory

### 4. Execution Decision Tree

#### Dry Run Mode Path
- If `--dry-run = true`: Lists files that would be deleted and logs them without actual deletion
- Provides safe preview of actions

#### Live Execution Path
- **Confirmation Check**: If not using `--force`, prompts user for confirmation
- **User Decision Points**:
  - User can abort the operation
  - User can confirm to proceed
- **File Deletion**: Processes each file individually, logging success/failure for each deletion

### 5. Completion Phase
- **Log Total Files Deleted**: Records the final count of removed files
- **Show Disk Usage (After)**: Displays updated disk space usage
- **Display Log File Location & Contents**: Shows where actions were logged and their details
- **End Script**: Clean termination

## Key Features

### Safety Mechanisms
- Dry-run mode for testing
- User confirmation prompts (unless forced)
- Comprehensive logging of all actions

### Monitoring Capabilities
- Before/after disk usage comparison
- Individual file deletion tracking
- Complete audit trail in log files

### Flexibility
- Configurable age threshold
- Optional interactive or automated execution
- Detailed reporting and logging
