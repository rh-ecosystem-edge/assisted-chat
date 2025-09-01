#!/bin/bash

set -eo pipefail

# Cleanup function for trap handler
cleanup() {
    echo -e "\n${YELLOW}Received interrupt signal. Cleaning up...${RESET}" >&2

    # Kill background processes
    if [[ -n "${liveness_pid:-}" ]]; then
        kill "$liveness_pid" 2>/dev/null || true
    fi

    # Kill any remaining concurrent request processes
    if [[ -n "${pids:-}" ]]; then
        for pid in "${pids[@]}"; do
            [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
        done
    fi

    # Stop liveness monitoring by removing the PID file
    [[ -n "${RESULTS_DIR:-}" ]] && rm -f "$RESULTS_DIR/liveness.pid" 2>/dev/null || true

    # Remove temporary directory
    [[ -n "${RESULTS_DIR:-}" ]] && rm -rf "$RESULTS_DIR" 2>/dev/null || true

    echo -e "${GREEN}Cleanup completed.${RESET}" >&2
    exit 130  # Standard exit code for SIGINT
}

# Set trap for SIGINT (Ctrl-C)
trap cleanup SIGINT

# Color definitions
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Test concurrent streaming requests to the lightspeed server by simulating users."
    echo ""
    echo "Options:"
    echo "  -u, --users NUM              Number of concurrent users (default: 3)"
    echo "  -r, --requests-per-user NUM  Number of requests per user (default: 5)"
    echo "  -d, --delay SECONDS          Delay between requests per user in seconds (default: 1.0)"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Run with 3 users, 5 requests each, 1s delay"
    echo "  $0 -u 5 -r 3 -d 0.5         # Run with 5 users, 3 requests each, 0.5s delay"
    echo "  $0 --users 10 --requests-per-user 2 --delay 2  # 10 users, 2 requests each, 2s delay"
}

# Parse command line arguments
CONCURRENT_USERS=3
REQUESTS_PER_USER=5
REQUEST_DELAY=1.0

while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--users)
            CONCURRENT_USERS="$2"
            # Validate that it's a positive integer
            if ! [[ "$CONCURRENT_USERS" =~ ^[1-9][0-9]*$ ]]; then
                echo -e "${RED}Error: Number of users must be a positive integer${RESET}" >&2
                exit 1
            fi
            shift 2
            ;;
        -r|--requests-per-user)
            REQUESTS_PER_USER="$2"
            # Validate that it's a positive integer
            if ! [[ "$REQUESTS_PER_USER" =~ ^[1-9][0-9]*$ ]]; then
                echo -e "${RED}Error: Number of requests per user must be a positive integer${RESET}" >&2
                exit 1
            fi
            shift 2
            ;;
        -d|--delay)
            REQUEST_DELAY="$2"
            # Validate that it's a positive number (integer or decimal)
            if ! [[ "$REQUEST_DELAY" =~ ^[0-9]*\.?[0-9]+$ ]]; then
                echo -e "${RED}Error: Delay must be a positive number${RESET}" >&2
                exit 1
            fi
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${RESET}" >&2
            echo "Use -h or --help for usage information." >&2
            exit 1
            ;;
    esac
done

# Calculate total requests
TOTAL_REQUESTS=$((CONCURRENT_USERS * REQUESTS_PER_USER))

# Get the script directory to locate utils
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

# Source the OCM token utility
source "$PROJECT_ROOT/utils/ocm-token.sh"

# Configuration
DEFAULT_QUERY="List my openshift clusters"
SERVER_URL="https://assisted-chat.api.integration.openshift.com/v1/streaming_query"
LIVENESS_URL="https://assisted-chat.api.integration.openshift.com/liveness"
RESULTS_DIR="/tmp/concurrent_test_$$"
LIVENESS_RESULTS_FILE="$RESULTS_DIR/liveness_times.txt"

echo -e "${CYAN}=== Concurrent User Simulation Test ===${RESET}"
echo "Testing $CONCURRENT_USERS users, each sending $REQUESTS_PER_USER requests with ${REQUEST_DELAY}s delay ($TOTAL_REQUESTS total)..."
echo

# Create results directory
mkdir -p "$RESULTS_DIR"


# Function to send a single request
send_request() {
    local request_id="$1"
    local result_file="$RESULTS_DIR/result_$request_id.txt"
    local start_time=$(date +%s.%N)
    
    # OCM token should already be available from parent shell
    if [[ -z "$OCM_TOKEN" ]]; then
        echo "FAILURE,$request_id,000,0,OCM_TOKEN_NOT_AVAILABLE" > "$result_file"
        return 0
    fi
    
    # Make the streaming request
    local curl_exit_code=0
    timeout 60s curl --silent --no-buffer \
        -H "Authorization: Bearer ${OCM_TOKEN}" \
        -H "Accept: text/event-stream" \
        -H "Cache-Control: no-cache" \
        "$SERVER_URL" \
        --json "{\"query\": \"${DEFAULT_QUERY}\"}" > /dev/null 2>&1 || curl_exit_code=$?

    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    if [[ $curl_exit_code -eq 0 ]]; then
        echo "SUCCESS,$request_id,200,$duration,OK" > "$result_file"
    else
        echo "FAILURE,$request_id,000,$duration,TIMEOUT" > "$result_file"
    fi
}

# Function to simulate a user sending sequential requests
simulate_user() {
    local user_id="$1"

    # Stagger user start times to avoid simultaneous requests
    # User 1 starts immediately, User 2 after 0.1s, User 3 after 0.2s, etc.
    local stagger_delay=$(echo "($user_id - 1) * 0.1" | bc -l 2>/dev/null || awk "BEGIN {print ($user_id - 1) * 0.1}")
    if (( $(echo "$stagger_delay > 0" | bc -l 2>/dev/null || awk "BEGIN {print ($stagger_delay > 0)}") )); then
        echo "User $user_id: Waiting ${stagger_delay}s before starting..."
        sleep "$stagger_delay"
    fi

    local user_start_time=$(date +%s.%N)
    echo "User $user_id: Starting session with $REQUESTS_PER_USER requests"

    for request_num in $(seq 1 $REQUESTS_PER_USER); do
        local global_request_id="${user_id}_${request_num}"
        echo "User $user_id: Sending request $request_num/$REQUESTS_PER_USER"

        # Send the request using the existing function
        send_request "$global_request_id"

        # Wait configured delay before next request (except for the last one)
        if [[ $request_num -lt $REQUESTS_PER_USER ]]; then
            sleep "$REQUEST_DELAY"
        fi
    done

    local user_end_time=$(date +%s.%N)
    if command -v bc >/dev/null 2>&1; then
        local user_duration=$(echo "$user_end_time - $user_start_time" | bc -l)
    else
        local user_duration=$(awk "BEGIN {print $user_end_time - $user_start_time}")
    fi

    echo "User $user_id: Completed session in ${user_duration}s"
}

# Function to continuously check liveness endpoint
check_liveness_continuously() {
    local liveness_pid_file="$RESULTS_DIR/liveness.pid"
    echo $$ > "$liveness_pid_file"
    
    # Clear the results file
    > "$LIVENESS_RESULTS_FILE"
    
    local counter=1
    while [[ -f "$liveness_pid_file" ]]; do
        local start_time=$(date +%s.%N)
        
        # Call liveness endpoint
        local curl_exit_code=0
        curl --silent --max-time 2 "$LIVENESS_URL" > /dev/null 2>&1 || curl_exit_code=$?
        
        local end_time=$(date +%s.%N)
        if command -v bc >/dev/null 2>&1; then
            local duration=$(echo "$end_time - $start_time" | bc -l)
        else
            local duration=$(awk "BEGIN {print $end_time - $start_time}")
        fi
        
        # Record the timing
        if [[ $curl_exit_code -eq 0 ]]; then
            echo "$counter,$duration,SUCCESS" >> "$LIVENESS_RESULTS_FILE"
        else
            echo "$counter,$duration,FAILED" >> "$LIVENESS_RESULTS_FILE"
        fi
        
        counter=$((counter + 1))
        sleep 0.5  # Check every 500ms
    done
}

declare -a pids

# Get OCM token once before spawning workers to avoid race conditions
echo "Retrieving OCM token..."
if ! get_ocm_token; then
    echo -e "${RED}Error: Failed to retrieve OCM token. Please ensure you're logged in to OCM.${RESET}" >&2
    echo "Run 'ocm login --use-auth-code' and follow the instructions." >&2
    exit 1
fi

# Export token so it's available to subshells
export OCM_TOKEN

echo "Launching $CONCURRENT_USERS concurrent users (staggered start: 0.1s intervals)..."
echo "Starting liveness monitoring..."

# Start liveness checking in background
check_liveness_continuously &
liveness_pid=$!

overall_start=$(date +%s.%N)

# Launch all users concurrently
for i in $(seq 1 $CONCURRENT_USERS); do
    simulate_user "$i" &
    pids[$i]=$!
done

# Wait for all users to complete
for i in $(seq 1 $CONCURRENT_USERS); do
    wait ${pids[$i]}
done

# Stop liveness checking
echo "Stopping liveness monitoring..."
rm -f "$RESULTS_DIR/liveness.pid" 2>/dev/null
wait $liveness_pid 2>/dev/null || true

overall_end=$(date +%s.%N)
if command -v bc >/dev/null 2>&1; then
    overall_duration=$(echo "$overall_end - $overall_start" | bc -l)
else
    overall_duration=$(awk "BEGIN {print $overall_end - $overall_start}")
fi

echo "All requests completed."
echo

# Analyze results
successful_requests=0
failed_requests=0
total_response_time=0
min_time=""
max_time=""

for user_id in $(seq 1 $CONCURRENT_USERS); do
    for request_num in $(seq 1 $REQUESTS_PER_USER); do
        global_request_id="${user_id}_${request_num}"
        result_file="$RESULTS_DIR/result_${global_request_id}.txt"
    if [[ -f "$result_file" ]]; then
        result=$(cat "$result_file")
        IFS=',' read -r status request_id http_status duration error_type <<< "$result"
        
        if [[ "$status" == "SUCCESS" ]]; then
            successful_requests=$((successful_requests + 1))
            
            # Check if bc is available and duration is valid
            if command -v bc >/dev/null 2>&1 && [[ "$duration" =~ ^[0-9]*\.?[0-9]+$ ]]; then
                total_response_time=$(echo "$total_response_time + $duration" | bc -l)
                
                # Set min_time if empty or if current duration is smaller
                if [[ -z "$min_time" ]]; then
                    min_time="$duration"
                elif (( $(echo "$duration < $min_time" | bc -l) )); then
                    min_time="$duration"
                fi
                
                # Set max_time if empty or if current duration is larger
                if [[ -z "$max_time" ]]; then
                    max_time="$duration"
                elif (( $(echo "$duration > $max_time" | bc -l) )); then
                    max_time="$duration"
                fi
            fi
        else
            failed_requests=$((failed_requests + 1))
        fi
    else
        failed_requests=$((failed_requests + 1))
    fi
    done
done

# Calculate average response time
avg_response_time=""
if [[ $successful_requests -gt 0 ]]; then
    if command -v bc >/dev/null 2>&1; then
        avg_response_time=$(echo "scale=3; $total_response_time / $successful_requests" | bc -l 2>/dev/null || echo "0.000")
    else
        avg_response_time="N/A"
    fi
fi

# Analyze liveness results
max_liveness_time=""
liveness_checks=0
liveness_failures=0

if [[ -f "$LIVENESS_RESULTS_FILE" ]]; then
    while IFS=',' read -r counter duration status; do
        liveness_checks=$((liveness_checks + 1))
        
        if [[ "$status" == "FAILED" ]]; then
            liveness_failures=$((liveness_failures + 1))
        fi
        
        # Track maximum liveness time
        if command -v bc >/dev/null 2>&1 && [[ "$duration" =~ ^[0-9]*\.?[0-9]+$ ]]; then
            if [[ -z "$max_liveness_time" ]]; then
                max_liveness_time="$duration"
            else
                # Use bc to compare durations
                if bc -l <<< "$duration > $max_liveness_time" 2>/dev/null | grep -q "1"; then
                    max_liveness_time="$duration"
                fi
            fi
        fi
    done < "$LIVENESS_RESULTS_FILE"
    

fi

# Display summary
echo -e "${CYAN}=====================================================================${RESET}"
echo -e "${CYAN}                           TEST SUMMARY                            ${RESET}"
echo -e "${CYAN}=====================================================================${RESET}"
echo
echo -e "${YELLOW}📊 RESULTS:${RESET}"
echo "  • Users: $CONCURRENT_USERS"
echo "  • Requests per user: $REQUESTS_PER_USER"
echo "  • Delay between requests: ${REQUEST_DELAY}s"
echo "  • Total requests: $TOTAL_REQUESTS"
echo -e "  • ${GREEN}✅ Successful: $successful_requests${RESET}"
echo -e "  • ${RED}❌ Failed: $failed_requests${RESET}"

if [[ $TOTAL_REQUESTS -gt 0 ]]; then
    if command -v bc >/dev/null 2>&1; then
        success_rate=$(echo "scale=1; $successful_requests * 100 / $TOTAL_REQUESTS" | bc -l 2>/dev/null || echo "0.0")
        echo -e "  • 📈 Success rate: ${success_rate}%"
    else
        # Fallback calculation without bc
        success_rate=$((successful_requests * 100 / TOTAL_REQUESTS))
        echo -e "  • 📈 Success rate: ${success_rate}%"
    fi
fi

echo
echo -e "${YELLOW}⏱️  TIMING:${RESET}"
echo "  • Total test duration: ${overall_duration}s"

if [[ $successful_requests -gt 0 ]]; then
    echo "  • Average response time: ${avg_response_time}s"
    echo "  • Fastest response: ${min_time}s"
    echo "  • Slowest response: ${max_time}s"
    
    if command -v bc >/dev/null 2>&1 && (( $(echo "$overall_duration > 0" | bc -l 2>/dev/null || echo "0") )); then
        rps=$(echo "scale=2; $successful_requests / $overall_duration" | bc -l 2>/dev/null || echo "0.00")
        echo "  • Throughput: ${rps} requests/second"
    fi
fi

if [[ -n "$max_liveness_time" ]]; then
    echo "  • Longest liveness check: ${max_liveness_time}s"
fi

echo
echo -e "${YELLOW}🩺 LIVENESS MONITORING:${RESET}"
if [[ $liveness_checks -gt 0 ]]; then
    echo "  • Total liveness checks: $liveness_checks"
    if [[ $liveness_failures -gt 0 ]]; then
        echo -e "  • ${RED}❌ Failed checks: $liveness_failures${RESET}"
    else
        echo -e "  • ${GREEN}✅ All checks passed${RESET}"
    fi
    if [[ -n "$max_liveness_time" ]]; then
        echo "  • Max liveness response time: ${max_liveness_time}s"
    fi
else
    echo "  • No liveness data collected"
fi

echo
if [[ $successful_requests -eq $TOTAL_REQUESTS ]]; then
    echo -e "${GREEN}🎉 All requests succeeded!${RESET}"
elif [[ $successful_requests -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  Mixed results - some requests failed${RESET}"
else
    echo -e "${RED}💥 All requests failed!${RESET}"
fi

echo
echo -e "${CYAN}=====================================================================${RESET}"

# Normal completion - cleanup is handled by trap or natural exit
rm -rf "$RESULTS_DIR"
