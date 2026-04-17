#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="otel-demo"
CONTEXT_NAME="kind-otel-demo"
NAMESPACE="otel-demo"
DEMO_RELEASE_NAME="my-otel-demo"
DEMO_CHART_VERSION="0.40.3"

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

# Function to check if command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed or not in PATH"
        exit 1
    fi
}

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}

    print_info "Waiting for pods to be ready in namespace $namespace (timeout: ${timeout}s)..."
    kubectl wait --for=condition=ready pod --all -n "$namespace" --timeout="${timeout}s" || {
        print_warning "Some pods may still be starting. Checking status..."
        kubectl get pods -n "$namespace"
        return 1
    }
}

# Function to check prerequisites
check_requirements() {
    print_info "Checking prerequisites..."

    # Check if prereq script exists
    if [ ! -f "./setup-prereq.sh" ]; then
        print_error "Prerequisites script './setup-prereq.sh' not found"
        print_info "Please ensure setup-prereq.sh is in the same directory"
        exit 1
    fi

    # Check required commands
    if ! command -v "ktbx" &> /dev/null; then
        print_error "ktbx is not installed. Please run './setup-prereq.sh' first"
        exit 1
    fi

    if ! command -v "kubectl" &> /dev/null; then
        print_error "kubectl is not available. Please run './setup-prereq.sh' first"
        exit 1
    fi

    if ! command -v "helm" &> /dev/null; then
        print_error "helm is not installed. Please run './setup-prereq.sh' first"
        exit 1
    fi

    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please run './setup-prereq.sh' first"
        exit 1
    fi

    print_info "✓ All prerequisites are met"
}

# Function to ensure cluster connection
ensure_cluster() {
    print_info "Ensuring cluster connectivity..."

    # Make sure we're connected to the right cluster
    if kubectl config get-contexts 2>/dev/null | grep -q "$CONTEXT_NAME"; then
        kubectl config use-context "$CONTEXT_NAME"
        print_info "✓ Connected to cluster '$CLUSTER_NAME'"
    else
        print_error "Cluster '$CLUSTER_NAME' not found. Please run './setup-prereq.sh' first"
        exit 1
    fi
}

# Function to setup Helm
setup_helm() {
    print_info "Setting up Helm repository..."

    # Add OpenTelemetry Helm repository
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo update
}

# Function to deploy OpenTelemetry demo
deploy_demo() {
    print_info "Deploying OpenTelemetry demo..."

    # Install or upgrade demo
    print_info "Installing/upgrading OpenTelemetry demo (version $DEMO_CHART_VERSION)..."
    helm upgrade --install "$DEMO_RELEASE_NAME" open-telemetry/opentelemetry-demo \
        --version "$DEMO_CHART_VERSION" \
        --create-namespace \
        -n "$NAMESPACE" \
        -f values-ingress.yaml

    # Wait for deployment to be ready
    wait_for_pods "$NAMESPACE" 600

    # Add ingress host to /etc/hosts
    print_info "Adding otel-demo.my-domain.com to /etc/hosts..."
    NODE_IP=$(kubectl get nodes otel-demo-worker -o=jsonpath='{.status.addresses[0].address}')
    txeh_bin=$(which txeh)
    if [ -z "$txeh_bin" ]; then
        print_error "txeh is not installed. Please install txeh to manage /etc/hosts entries"
    else
        print_info "Using txeh to add host entry for otel-demo.my-domain.com"
        sudo $txeh_bin add "$NODE_IP" otel-demo.my-domain.com
    fi
}

# Function to setup port forwarding
setup_port_forwarding() {
    print_info "Setting up port forwarding..."

    # Kill any existing port-forward processes
    pkill -f "kubectl port-forward" || true
    sleep 2

    # Start port forwarding in background
    print_info "Starting port forwarding for web store (http://localhost:8080)..."
    kubectl port-forward -n "$NAMESPACE" svc/frontend-proxy 8080:8080 > /dev/null 2>&1 &

    # Start port forwarding for other services
    local grafana_service
    grafana_service=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$grafana_service" ]; then
        print_info "Starting port forwarding for Grafana (http://localhost:3000)..."
        kubectl port-forward -n "$NAMESPACE" "svc/$grafana_service" 3000:80 > /dev/null 2>&1 &
    fi

    local jaeger_service
    jaeger_service=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=jaeger -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$jaeger_service" ]; then
        print_info "Starting port forwarding for Jaeger (http://localhost:16686)..."
        kubectl port-forward -n "$NAMESPACE" "svc/$jaeger_service" 16686:16686 > /dev/null 2>&1 &
    fi

    sleep 3
}

# Function to run tests
run_tests() {
    print_info "Running basic tests..."

    # Test if services are responding
    local max_attempts=30
    local attempt=1

    print_info "Testing web store availability..."
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:8080 > /dev/null; then
            print_info "✓ Web store is accessible at http://localhost:8080"
            break
        fi
        print_info "Attempt $attempt/$max_attempts - Waiting for web store..."
        sleep 5
        ((attempt++))
    done

    if [ $attempt -gt $max_attempts ]; then
        print_error "✗ Web store is not accessible after ${max_attempts} attempts"
        return 1
    fi

    # Test Grafana if available
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        print_info "✓ Grafana is accessible at http://localhost:3000"
    fi

    # Test Jaeger if available
    if curl -s http://localhost:16686 > /dev/null 2>&1; then
        print_info "✓ Jaeger is accessible at http://localhost:16686"
    fi
}

# Function to show status
show_status() {
    print_info "Deployment status:"
    echo
    kubectl get pods -n "$NAMESPACE"
    echo
    kubectl get svc -n "$NAMESPACE"
    echo
    print_info "Access URLs:"
    echo "  • Web Store: http://localhost:8080"
    echo "  • Grafana: http://localhost:3000"
    echo "  • Jaeger: http://localhost:16686"
    echo
    print_info "To stop port forwarding: pkill -f 'kubectl port-forward'"
    print_info "To delete the demo: helm uninstall $DEMO_RELEASE_NAME -n $NAMESPACE"
    print_info "To delete the cluster: ktbx delete cluster -n $CLUSTER_NAME"
}

# Function to cleanup
cleanup() {
    print_info "Cleaning up..."
    read -p "Delete the cluster? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pkill -f "kubectl port-forward" || true
        ktbx delete cluster -n "$CLUSTER_NAME" || true
        print_info "Cleanup completed"
    else
        print_info "Cluster preserved. Use 'ktbx delete cluster -n $CLUSTER_NAME' to delete manually"
    fi
}

# Main function
main() {
    case "${1:-deploy}" in
        "deploy")
            check_requirements
            ensure_cluster
            setup_helm
            deploy_demo
            setup_port_forwarding
            run_tests
            show_status
            ;;
        "test")
            run_tests
            ;;
        "status")
            show_status
            ;;
        "cleanup")
            cleanup
            ;;
        "port-forward")
            setup_port_forwarding
            print_info "Port forwarding started"
            ;;
        *)
            echo "Usage: $0 [deploy|test|status|cleanup|port-forward]"
            echo "  deploy      - Full deployment (default)"
            echo "  test        - Run tests only"
            echo "  status      - Show deployment status"
            echo "  cleanup     - Clean up resources"
            echo "  port-forward - Setup port forwarding only"
            exit 1
            ;;
    esac
}

# Trap to cleanup port forwarding on exit
trap 'pkill -f "kubectl port-forward" 2>/dev/null || true' EXIT

main "$@"