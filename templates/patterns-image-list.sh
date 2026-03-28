#!/bin/bash
set -eu

REPO=quay.io/validatedpatterns
CHARTS=(acm clustergroup gitea golang-external-secrets openshift-external-secrets hashicorp-vault pattern-install)

for i in "${CHARTS[@]}"; do
	for j in $(skopeo list-tags docker://${REPO}/${i} | yq -r '.Tags[]'); do
		echo "${REPO}/${i}:${j}"
	done
done
