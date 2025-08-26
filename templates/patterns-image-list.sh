#!/bin/bash
set -eu

REPO=quay.io/hybridcloudpatterns
CHARTS=(acm clustergroup gitea golang-external-secrets hashicorp-vault pattern-install)

for i in "${CHARTS[@]}"; do
	for j in $(skopeo list-tags docker://${REPO}/${i} | yq -r '.Tags[]'); do
		echo "${REPO}/${i}:${j}"
	done
done
