#!/bin/bash
set -xe -o pipefail

BASE=/var/cache/docker

declare -A REGISTRIES
REGISTRIES[docker.io]=https://registry-1.docker.io
REGISTRIES[quay.io]=https://quay.io
REGISTRIES[ghcr.io]=https://ghcr.io
REGISTRIES[registry.redhat.io]=https://registry.redhat.io

declare -A PORTS
PORTS[docker.io]=5000
PORTS[quay.io]=5001
PORTS[ghcr.io]=5002
PORTS[registry.redhat.io]=5003


declare -A AUTH
AUTH[docker.io]=""
AUTH[quay.io]=""
AUTH[ghcr.io]=""
AUTH[registry.redhat.io]="
  username: foo
  password: bar"

podman stop --all; podman rm --all; rm -rf /var/cache/docker/config

mkdir -p /var/log/docker
mkdir -p "${BASE}"/{config,cache} 2>/dev/null || /bin/true
mkdir -p "${BASE}/config/certs" 2>/dev/null || /bin/true
cp -vf fw.int.rhx.crt fw.int.rhx.key "${BASE}/config/certs"

AUTH=""
for i in "${!REGISTRIES[@]}"; do
  mkdir "${BASE}/config/${i}" 2> /dev/null || /bin/true
  mkdir "${BASE}/cache/${i}" 2> /dev/null || /bin/true
  cat > "${BASE}/config/${i}/config.yml" <<EOF
version: 0.1
log:
  level: debug
  formatter: text
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
proxy:
  remoteurl: ${REGISTRIES[$i]}
  ${AUTH[$i]}
http:
  addr: :${PORTS[$i]}
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 30s
    threshold: 10
EOF
  podman run -d --name docker_cache_${i} -it --net host \
    --security-opt label=disable \
    --log-driver k8s-file \
    --log-opt path=/var/log/docker/${i}.log \
    -v "${BASE}/config/${i}":/etc/docker/registry/ \
    -v "${BASE}/cache/${i}":/var/lib/registry \
    -v "${BASE}/config/certs":/certs \
    -e REGISTRY_HTTP_SECRET=yomama \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/fw.int.rhx.crt \
    -e REGISTRY_HTTP_TLS_KEY=/certs/fw.int.rhx.key \
    docker.io/registry:latest
done
