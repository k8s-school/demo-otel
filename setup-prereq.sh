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

# Function to install Helm using ktbx
install_helm() {
    print_info "Installing Helm using ktbx..."

    # Check if Helm is already installed
    if command -v helm &> /dev/null; then
        local helm_version
        helm_version=$(helm version --short --client | cut -d: -f2 | tr -d ' ')
        print_info "Helm is already installed: $helm_version"
        return 0
    fi

    # Install Helm using ktbx
    ktbx install helm

    # Verify installation
    if command -v helm &> /dev/null; then
        local helm_version
        helm_version=$(helm version --short --client | cut -d: -f2 | tr -d ' ')
        print_info "Helm installed successfully: $helm_version"
    else
        print_error "Helm installation failed"
        exit 1
    fi
}

# Function to create Kubernetes cluster
create_k8s_cluster() {
    print_info "Creating Kubernetes cluster with ktbx..."

    # Check if cluster already exists
    if kubectl config get-contexts 2>/dev/null | grep -q "$CONTEXT_NAME"; then
        print_warning "Cluster '$CLUSTER_NAME' already exists"
        read -p "Delete and recreate? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Deleting existing cluster..."
            ktbx delete cluster -n "$CLUSTER_NAME" || true
            sleep 5
        else
            print_info "Using existing cluster..."
            kubectl config use-context "$CONTEXT_NAME"
            return 0
        fi
    fi

    # Create new cluster
    print_info "Creating new Kubernetes cluster '$CLUSTER_NAME'..."
    ktbx create cluster -n "$CLUSTER_NAME"

    # Wait for cluster to be ready
    print_info "Waiting for cluster nodes to be ready..."
    kubectl wait --for=condition=ready node --all --timeout=300s

    print_info "Cluster '$CLUSTER_NAME' is ready"
}

# Function to verify prerequisites
verify_prerequisites() {
    print_info "Verifying prerequisites..."

    # Check ktbx
    check_command "ktbx"
    print_info "✓ ktbx is available"

    # Check kubectl
    check_command "kubectl"
    print_info "✓ kubectl is available"

    # Check cluster connectivity
    if kubectl cluster-info &> /dev/null; then
        print_info "✓ Kubernetes cluster is accessible"
        kubectl get nodes
    else
        print_error "✗ Cannot connect to Kubernetes cluster"
        return 1
    fi

    # Check Helm
    if command -v helm &> /dev/null; then
        helm version --short
        print_info "✓ Helm is available"
    else
        print_error "✗ Helm is not available"
        return 1
    fi
}

# Function to check system requirements
check_system_requirements() {
    print_info "Checking system requirements..."

    # Check available memory
    local mem_gb
    mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$mem_gb" -lt 6 ]; then
        print_warning "System has ${mem_gb}GB RAM, but OpenTelemetry demo requires at least 6GB"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_info "✓ System has sufficient memory (${mem_gb}GB)"
    fi

    # Check available disk space
    local disk_gb
    disk_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [ "$disk_gb" -lt 10 ]; then
        print_warning "Available disk space is ${disk_gb}GB, recommend at least 10GB"
    else
        print_info "✓ System has sufficient disk space (${disk_gb}GB available)"
    fi
}

# Main setup function
main() {
    case "${1:-setup}" in
        "setup")
            print_info "Starting OpenTelemetry demo prerequisites setup..."
            check_system_requirements
            install_helm
            create_k8s_cluster
            verify_prerequisites
            print_info "Prerequisites setup completed successfully!"
            print_info "You can now run './deploy-otel-demo.sh' to deploy the OpenTelemetry demo"
            ;;
        "verify")
            verify_prerequisites
            ;;
        "cluster-only")
            check_system_requirements
            create_k8s_cluster
            print_info "Kubernetes cluster setup completed!"
            ;;
        "helm-only")
            install_helm
            print_info "Helm installation completed!"
            ;;
        *)
            echo "Usage: $0 [setup|verify|cluster-only|helm-only]"
            echo "  setup       - Complete prerequisites setup (default)"
            echo "  verify      - Verify prerequisites are installed"
            echo "  cluster-only - Create Kubernetes cluster only"
            echo "  helm-only   - Install Helm only"
            exit 1
            ;;
    esac
}

main "$@"