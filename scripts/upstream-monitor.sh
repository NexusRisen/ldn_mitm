#!/bin/bash
# Upstream Monitor Script
# Polls upstream repo and triggers sync workflow instantly when changes detected
#
# Usage: ./upstream-monitor.sh
# Set environment variable: export GITHUB_PAT="your_personal_access_token"
#
# Run in background: nohup ./upstream-monitor.sh &

UPSTREAM_REPO="spacemeowx2/ldn_mitm"
YOUR_REPO="NexusRisen/ldn_mitm"
POLL_INTERVAL=10  # seconds between checks

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for PAT
if [ -z "$GITHUB_PAT" ]; then
    echo -e "${RED}Error: GITHUB_PAT environment variable not set${NC}"
    echo "Set it with: export GITHUB_PAT='your_personal_access_token'"
    echo "Create a PAT at: https://github.com/settings/tokens"
    echo "Required scopes: repo, workflow"
    exit 1
fi

# Store last known state
LAST_COMMIT=""
LAST_RELEASE=""

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

get_upstream_commit() {
    curl -s "https://api.github.com/repos/$UPSTREAM_REPO/commits/master" | grep -m1 '"sha"' | cut -d'"' -f4
}

get_upstream_release() {
    curl -s "https://api.github.com/repos/$UPSTREAM_REPO/releases/latest" | grep -m1 '"tag_name"' | cut -d'"' -f4
}

trigger_workflow() {
    local event_type=$1
    log "${YELLOW}Triggering $event_type workflow...${NC}"

    curl -s -X POST \
        -H "Authorization: token $GITHUB_PAT" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$YOUR_REPO/dispatches" \
        -d "{\"event_type\":\"$event_type\"}"

    log "${GREEN}Workflow triggered: $event_type${NC}"
}

# Initialize with current state
log "Starting upstream monitor for $UPSTREAM_REPO"
log "Polling every $POLL_INTERVAL seconds"

LAST_COMMIT=$(get_upstream_commit)
LAST_RELEASE=$(get_upstream_release)

log "Initial commit: ${LAST_COMMIT:0:7}"
log "Initial release: $LAST_RELEASE"
log "Monitoring started. Press Ctrl+C to stop."
echo ""

while true; do
    # Check for new commits
    CURRENT_COMMIT=$(get_upstream_commit)
    if [ -n "$CURRENT_COMMIT" ] && [ "$CURRENT_COMMIT" != "$LAST_COMMIT" ]; then
        log "${GREEN}New commit detected!${NC}"
        log "Old: ${LAST_COMMIT:0:7} -> New: ${CURRENT_COMMIT:0:7}"
        trigger_workflow "sync-upstream"
        LAST_COMMIT="$CURRENT_COMMIT"
    fi

    # Check for new releases
    CURRENT_RELEASE=$(get_upstream_release)
    if [ -n "$CURRENT_RELEASE" ] && [ "$CURRENT_RELEASE" != "$LAST_RELEASE" ]; then
        log "${GREEN}New release detected!${NC}"
        log "Old: $LAST_RELEASE -> New: $CURRENT_RELEASE"
        trigger_workflow "sync-releases"
        LAST_RELEASE="$CURRENT_RELEASE"
    fi

    sleep $POLL_INTERVAL
done
