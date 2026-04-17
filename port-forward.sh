#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="otel-demo"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if port is already in use
check_port() {
    local port=$1
    if lsof -i :$port > /dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to start port forwarding
start_port_forwarding() {
    print_info "Starting port forwarding for OpenTelemetry demo services..."

    # Kill any existing port-forward processes for these ports
    for port in 8080 3000 16686; do
        if check_port $port; then
            print_warning "Port $port is already in use. Killing existing processes..."
            lsof -ti :$port | xargs kill -9 2>/dev/null || true
            sleep 1
        fi
    done

    # Web store (frontend-proxy)
    print_info "Starting port forwarding for web store (http://localhost:8080)..."
    kubectl port-forward -n "$NAMESPACE" svc/frontend-proxy 8080:8080 > /dev/null 2>&1 &
    local frontend_pid=$!

    # Grafana
    local grafana_service
    grafana_service=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$grafana_service" ]; then
        print_info "Starting port forwarding for Grafana (http://localhost:3000)..."
        kubectl port-forward -n "$NAMESPACE" "svc/$grafana_service" 3000:80 > /dev/null 2>&1 &
        local grafana_pid=$!
    fi

    # Jaeger
    local jaeger_service
    jaeger_service=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=jaeger -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$jaeger_service" ]; then
        print_info "Starting port forwarding for Jaeger (http://localhost:16686)..."
        kubectl port-forward -n "$NAMESPACE" "svc/$jaeger_service" 16686:16686 > /dev/null 2>&1 &
        local jaeger_pid=$!
    fi

    sleep 3

    # Verify port forwards are working
    print_info "Verifying port forwards..."

    if check_port 8080; then
        print_info "✓ Web store is accessible at http://localhost:8080"
    else
        print_error "✗ Web store port forward failed"
    fi

    if check_port 3000; then
        print_info "✓ Grafana is accessible at http://localhost:3000"
    fi

    if check_port 16686; then
        print_info "✓ Jaeger is accessible at http://localhost:16686"
    fi

    print_info "Port forwarding is now running in the background."
    print_info "To stop: $0 stop"
    print_info "To check status: $0 status"
}

# Function to stop port forwarding
stop_port_forwarding() {
    print_info "Stopping all port forwarding processes..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2
    print_info "✓ All port forwarding processes stopped"
}

# Function to show status
show_status() {
    print_info "Port forwarding status:"

    if check_port 8080; then
        print_info "✓ Web store: http://localhost:8080"
    else
        print_warning "✗ Web store: not running"
    fi

    if check_port 3000; then
        print_info "✓ Grafana: http://localhost:3000"
    else
        print_warning "✗ Grafana: not running"
    fi

    if check_port 16686; then
        print_info "✓ Jaeger: http://localhost:16686"
    else
        print_warning "✗ Jaeger: not running"
    fi

    # Show running kubectl port-forward processes
    local pf_processes
    pf_processes=$(pgrep -f "kubectl port-forward" 2>/dev/null || echo "")
    if [ -n "$pf_processes" ]; then
        echo
        print_info "Running port-forward processes:"
        ps -p $pf_processes -o pid,cmd 2>/dev/null || true
    else
        echo
        print_warning "No kubectl port-forward processes running"
    fi
}

# Function to restart port forwarding
restart_port_forwarding() {
    print_info "Restarting port forwarding..."
    stop_port_forwarding
    sleep 2
    start_port_forwarding
}

# Main function
main() {
    case "${1:-start}" in
        "start")
            start_port_forwarding
            ;;
        "stop")
            stop_port_forwarding
            ;;
        "restart")
            restart_port_forwarding
            ;;
        "status")
            show_status
            ;;
        *)
            echo "Usage: $0 [start|stop|restart|status]"
            echo "  start   - Start port forwarding (default)"
            echo "  stop    - Stop all port forwarding"
            echo "  restart - Restart port forwarding"
            echo "  status  - Show port forwarding status"
            exit 1
            ;;
    esac
}

main "$@"