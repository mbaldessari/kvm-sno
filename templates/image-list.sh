#!/bin/bash
set -euo pipefail

CATALOG_IMAGE="quay.io/openshift-storage-scale/openshift-fusion-access-catalog:latest"
TMP_DIR=$(mktemp -d)
BUNDLE_LIST_FILE="bundle-images.txt"
ALL_IMAGES_FILE="/tmp/all-images.txt"

# Step 1: Pull the catalog image (assumes it's locally accessible)
podman pull "$CATALOG_IMAGE"

# Step 2: Extract the SQLite database from the catalog image
CONTAINER_ID=$(podman create "$CATALOG_IMAGE")
podman cp "$CONTAINER_ID":/database/index.db "$TMP_DIR/index.db"
podman rm "$CONTAINER_ID"

# Step 3: Query the bundle images from the database
sqlite3 "$TMP_DIR/index.db" "SELECT bundlepath FROM operatorbundle;" > "$BUNDLE_LIST_FILE"

# Step 4: Pull and extract related images from each bundle
> "$ALL_IMAGES_FILE"

while read -r bundle_image; do
    echo "Processing bundle: $bundle_image"
    podman pull "$bundle_image"

    # Extract and inspect the bundle image to get the ClusterServiceVersion (CSV)
    BUNDLE_TMP=$(mktemp -d)
    container=$(podman create "$bundle_image")
    podman cp "$container":/manifests "$BUNDLE_TMP/"
    podman rm "$container"

    # Use jq to extract related images from CSV
    for csv in "$BUNDLE_TMP"/manifests/*.clusterserviceversion.yaml; do
        if [[ -f "$csv" ]]; then
            # yq eval '.spec.relatedImages[].image' "$csv" 2>/dev/null || true
            yq eval '.spec.relatedImages[].image, .spec.install.spec.deployments[].spec.template.spec.containers[].image' "$csv" 2>/dev/null || true

        fi
    done >> "$ALL_IMAGES_FILE"

    # Clean up
    rm -rf "$BUNDLE_TMP"
done < "$BUNDLE_LIST_FILE"

# Add bundle images themselves to the list
cat "$BUNDLE_LIST_FILE" >> "$ALL_IMAGES_FILE"

# Remove duplicates
sort -u "$ALL_IMAGES_FILE" -o "$ALL_IMAGES_FILE"

echo "Image list saved to: $ALL_IMAGES_FILE"
