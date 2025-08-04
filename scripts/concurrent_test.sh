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
    echo "Test concurrent streaming requests to the lightspeed server."
    echo ""
    echo "Options:"
    echo "  -n, --requests NUM    Number of concurrent requests (default: 5)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   # Run with default 5 concurrent requests"
    echo "  $0 -n 10            # Run with 10 concurrent requests"
    echo "  $0 --requests 20     # Run with 20 concurrent requests"
}

# Parse command line arguments
CONCURRENT_REQUESTS=5

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--requests)
            CONCURRENT_REQUESTS="$2"
            # Validate that it's a positive integer
            if ! [[ "$CONCURRENT_REQUESTS" =~ ^[1-9][0-9]*$ ]]; then
                echo -e "${RED}Error: Number of requests must be a positive integer${RESET}" >&2
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

# Get the script directory to locate utils
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

# Source the OCM token utility
source "$PROJECT_ROOT/utils/ocm-token.sh"

# Configuration
DEFAULT_QUERY="What is the OpenShift Assisted Installer? Can you list my clusters?"
SERVER_URL="http://localhost:8090/v1/streaming_query"
LIVENESS_URL="http://127.0.0.1:8090/liveness"
RESULTS_DIR="/tmp/concurrent_test_$$"
LIVENESS_RESULTS_FILE="$RESULTS_DIR/liveness_times.txt"

echo -e "${CYAN}=== Concurrent Streaming Request Test ===${RESET}"
echo "Testing $CONCURRENT_REQUESTS concurrent requests..."
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
    if command -v bc >/dev/null 2>&1; then
        local duration=$(echo "$end_time - $start_time" | bc -l)
    else
        local duration=$(awk "BEGIN {print $end_time - $start_time}")
    fi
    
    if [[ $curl_exit_code -eq 0 ]]; then
        echo "SUCCESS,$request_id,200,$duration,OK" > "$result_file"
    else
        echo "FAILURE,$request_id,000,$duration,TIMEOUT" > "$result_file"
    fi
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

echo "Launching $CONCURRENT_REQUESTS concurrent requests..."
echo "Starting liveness monitoring..."

# Start liveness checking in background
check_liveness_continuously &
liveness_pid=$!

overall_start=$(date +%s.%N)

# Launch all requests concurrently
for i in $(seq 1 $CONCURRENT_REQUESTS); do
    send_request "$i" &
    pids[$i]=$!
done

# Wait for all requests to complete
for i in $(seq 1 $CONCURRENT_REQUESTS); do
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

for i in $(seq 1 $CONCURRENT_REQUESTS); do
    result_file="$RESULTS_DIR/result_$i.txt"
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
echo "  • Total requests: $CONCURRENT_REQUESTS"
echo -e "  • ${GREEN}✅ Successful: $successful_requests${RESET}"
echo -e "  • ${RED}❌ Failed: $failed_requests${RESET}"

if [[ $CONCURRENT_REQUESTS -gt 0 ]]; then
    if command -v bc >/dev/null 2>&1; then
        success_rate=$(echo "scale=1; $successful_requests * 100 / $CONCURRENT_REQUESTS" | bc -l 2>/dev/null || echo "0.0")
        echo -e "  • 📈 Success rate: ${success_rate}%"
    else
        # Fallback calculation without bc
        success_rate=$((successful_requests * 100 / CONCURRENT_REQUESTS))
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
if [[ $successful_requests -eq $CONCURRENT_REQUESTS ]]; then
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
