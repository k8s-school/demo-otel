#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INGRESS_NAMESPACE="ingress-nginx"
RELEASE_NAME="ingress-nginx"

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

# Function to install ingress controller
install_ingress() {
    print_info "Installing NGINX Ingress Controller..."

    # Check prerequisites
    check_command "kubectl"
    check_command "helm"

    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    # Add ingress-nginx Helm repository
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update

    # Install or upgrade NGINX Ingress Controller
    print_info "Installing/upgrading NGINX Ingress Controller..."
    helm upgrade --install "$RELEASE_NAME" ingress-nginx/ingress-nginx \
        --namespace "$INGRESS_NAMESPACE" \
        --create-namespace \
        --values values-ingress.yaml

    # Wait for deployment to be ready
    print_info "Waiting for NGINX Ingress Controller to be ready..."
    kubectl wait --namespace "$INGRESS_NAMESPACE" \
        --for=condition=available deployment \
        --selector=app.kubernetes.io/instance=ingress-nginx \
        --timeout=300s

    print_info "✓ NGINX Ingress Controller is ready"

    # Show service details
    print_info "Service details:"
    kubectl get svc -n "$INGRESS_NAMESPACE" ingress-nginx-controller

    # Get NodePort details
    local http_port https_port
    http_port=$(kubectl get svc ingress-nginx-controller -n "$INGRESS_NAMESPACE" -o jsonpath="{.spec.ports[?(@.name=='http')].nodePort}" 2>/dev/null || echo "N/A")
    https_port=$(kubectl get svc ingress-nginx-controller -n "$INGRESS_NAMESPACE" -o jsonpath="{.spec.ports[?(@.name=='https')].nodePort}" 2>/dev/null || echo "N/A")

    print_info "Access ports:"
    echo "  • HTTP: $http_port"
    echo "  • HTTPS: $https_port"
}

install_ingress