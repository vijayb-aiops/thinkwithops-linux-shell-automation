#!/bin/bash

# ==================================================
# 🧹 PROJECT 1: THE LOG CLEANER
# Automates cleanup of old log files to prevent disk space issues.
# Includes dry-run mode, force mode (non-interactive), and full logging.
# ==================================================

# ==============================
# CONFIGURATION
# ==============================
LOG_DIR="/var/log"                                # Directory where logs are located
DAYS_OLD=7                                        # Delete logs older than N days
LOG_FILE="/var/log/cleanup_$(date '+%Y%m%d_%H%M%S').log"  # Timestamped log file

# ==============================
# COLORS (for pretty terminal output)
# ==============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Reset color

# ==============================
# Function: Write timestamped message to both terminal and logfile
# ==============================
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE" > /dev/null
}

# ==============================
# Function: Show usage help
# ==============================
usage() {
    echo "Usage: $0 [--dry-run | --force]"
    echo "  --dry-run   : Show what would be deleted (no actual deletion)"
    echo "  --force     : Delete files without confirmation (for cron jobs)"
    exit 0
}

# ==============================
# Parse command-line arguments
# ==============================
DRY_RUN=false
FORCE=false
for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=true ;;
        --force)   FORCE=true ;;
        -h|--help) usage ;;
    esac
done

# ==============================
# Warn if not root (may fail to delete some logs)
# ==============================
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Warning: Not running as root. Some logs may not be deletable.${NC}"
fi

# ==============================
# Ensure target directory exists
# ==============================
if [ ! -d "$LOG_DIR" ]; then
    echo -e "${RED}❌ Error: Directory $LOG_DIR does not exist.${NC}"
    exit 1
fi

# ==============================
# Show current disk usage before cleanup
# ==============================
echo -e "${GREEN}📊 Current Disk Usage:${NC}"
df -h | grep -E "(\/$|\/var$)"

# Start logging session
echo ""
log_message "🧹 Starting log cleanup in $LOG_DIR (older than $DAYS_OLD days)"

# ==============================
# Build find command to locate old log files
# ==============================
FIND_CMD="find $LOG_DIR -name \"*.log*\" -mtime +$DAYS_OLD"

# ==============================
# DRY RUN MODE: Only show what would be deleted
# ==============================
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}📋 Files that would be deleted:${NC}"
    eval $FIND_CMD -print | while read file; do
        echo "  → $file"
        log_message "Would delete: $file"
    done
    FILE_COUNT=$(eval $FIND_CMD | wc -l)
    echo -e "${YELLOW}📊 Total files: $FILE_COUNT${NC}"
    log_message "DRY RUN: $FILE_COUNT files would be deleted."

# ==============================
# REAL RUN MODE: Actually delete files
# ==============================
else
    # If --force not passed, ask user before deleting
    if [ "$FORCE" = false ]; then
        echo -e "${RED}🧨 WARNING: This will DELETE files. Are you sure? (y/N)${NC}"
        read -r CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
            echo "🛑 Aborted by user."
            log_message "ABORTED: User canceled deletion."
            exit 0
        fi
    fi

    echo -e "${RED}🧨 DELETING FILES...${NC}"
    FILE_COUNT=0
    while IFS= read -r file; do
        if rm -f "$file" 2>/dev/null; then
            echo "  ✅ Deleted: $file"
            log_message "Deleted: $file"
            ((FILE_COUNT++))
        else
            echo "  ❌ Failed to delete: $file"
            log_message "Failed to delete: $file"
        fi
    done < <(eval $FIND_CMD -print)

    echo -e "${GREEN}✅ Cleanup complete. Deleted $FILE_COUNT files.${NC}"
    log_message "SUCCESS: Deleted $FILE_COUNT files."
fi

# ==============================
# Show disk usage after cleanup
# ==============================
echo ""
echo -e "${GREEN}📊 Disk Usage After Cleanup:${NC}"
df -h | grep -E "(\/$|\/var$)"

# ==============================
# Final success message
# ==============================
if [ "$DRY_RUN" = false ]; then
    echo ""
    echo -e "${GREEN}🎉 You just saved the server. Go get coffee. ☕${NC}"
fi

# ==============================
# Show where the log file is saved + print contents
# ==============================
echo ""
echo -e "${GREEN}📂 Log saved to: $LOG_FILE${NC}"
echo -e "${GREEN}📝 Log contents:${NC}"
cat "$LOG_FILE"
