# OpenTelemetry Demo Lab

This repository contains scripts to deploy and test the OpenTelemetry demo on Kubernetes using ktbx and ciux.

## Prerequisites

- Linux system with at least 6GB RAM
- Go installed (for ktbx)
- Docker installed
- sudo access (for Helm installation)

## Quick Start

1. **Install dependencies with ciux:**
   ```bash
   ciux ignite .
   ```

2. **Setup prerequisites (install Helm and create Kubernetes cluster):**
   ```bash
   ./setup-prereq.sh
   ```

3. **Deploy the OpenTelemetry demo:**
   ```bash
   ./deploy-otel-demo.sh
   ```

4. **Access the applications:**
   - Web Store: http://localhost:8080
   - Grafana: http://localhost:3000
   - Jaeger: http://localhost:16686

## Scripts Overview

### `setup-prereq.sh`
Handles prerequisites installation and cluster setup:
- `./setup-prereq.sh` - Complete setup (default)
- `./setup-prereq.sh verify` - Verify prerequisites
- `./setup-prereq.sh cluster-only` - Create cluster only
- `./setup-prereq.sh helm-only` - Install Helm only

### `deploy-otel-demo.sh`
Deploys and manages the OpenTelemetry demo:
- `./deploy-otel-demo.sh` - Full deployment (default)
- `./deploy-otel-demo.sh test` - Run tests only
- `./deploy-otel-demo.sh status` - Show deployment status
- `./deploy-otel-demo.sh cleanup` - Clean up resources
- `./deploy-otel-demo.sh port-forward` - Setup port forwarding only

## Troubleshooting

### Helm Installation Issues
If Helm installation fails due to sudo permissions, you can install Helm manually:
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Port Forwarding Issues
If port forwarding stops working, restart it:
```bash
./deploy-otel-demo.sh port-forward
```

### Cluster Issues
If cluster connectivity issues occur:
```bash
ktbx cluster use otel-demo
kubectl cluster-info
```

## Cleanup

To remove everything:
```bash
./deploy-otel-demo.sh cleanup
```

## Architecture

The OpenTelemetry demo consists of multiple microservices that generate telemetry data (traces, metrics, logs) which are collected by the OpenTelemetry Collector and sent to various backends like Jaeger for tracing and Prometheus/Grafana for metrics.

## References

- [OpenTelemetry Demo](https://opentelemetry.io/docs/demo/)
- [Kubernetes Deployment Guide](https://opentelemetry.io/docs/demo/kubernetes-deployment/)