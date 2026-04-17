#!/bin/bash

# Set nginx ingress as default ingress class
echo "Setting nginx as default ingress class..."
kubectl patch ingressclass nginx -p '{"metadata": {"annotations":{"ingressclass.kubernetes.io/is-default-class":"true"}}}'

# Get the NodePort for the ingress controller
export NODE_PORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')

# Define the application URL
APP_URL="http://otel-demo.my-domain.com:$NODE_PORT"

# Display the URL
echo "Application URL: $APP_URL"

# Access the application
echo "Accessing application..."
curl "$APP_URL"