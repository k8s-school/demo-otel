# Label selector: e2e
export DEMO_OTEL_DIR=/home/fjammes/src/github.com/k8s-school/demo-otel
export DEMO_OTEL_VERSION=e1af5c3
export DEMO_OTEL_WORKBRANCH=main
export CIUX_IMAGE_REGISTRY=
export CIUX_IMAGE_NAME=demo-otel
# Image which contains latest code source changes DEMO_OTEL_VERSION
export CIUX_IMAGE_TAG=e1af5c3
export CIUX_IMAGE_URL=/demo-otel:e1af5c3
# True if CIUX_IMAGE_URL need to be built
export CIUX_BUILD=true
# Promoted image is the image which will be push if CI run successfully
export CIUX_PROMOTED_IMAGE_URL=/demo-otel:e1af5c3