#!/usr/bin/env bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

#set -e
cat <<EOF | kubectl -n kns2 exec -i vaultkns2-0 -- sh -e
vault secrets disable kvv2/
vault secrets enable -path=kvv2 kv-v2
vault kv put kvv2/secret username="db-readonly-username-old" password="db-secret-password-tenant-2-old"
cat <<EOT > /tmp/policy.hcl
path "kvv2/*" {
  capabilities = ["read"]
}
EOT
vault policy write static-demo /tmp/policy.hcl
# setup the necessary auth backend
vault auth enable kubernetes || true
vault write auth/kubernetes/config \
    kubernetes_host=https://kubernetes.default.svc
vault write auth/kubernetes/role/static-demo \
    bound_service_account_names=default \
    bound_service_account_namespaces=tenant-1,tenant-2 \
    policies=static-demo \
    ttl=1h
EOF

cat <<EOF | kubectl -n kns1 exec -i vaultkns1-0 -- sh -e
vault secrets disable kvv2/
vault secrets enable -path=kvv2 kv-v2
vault kv put kvv2/secret username="db-readonly-username" password="db-secret-password"
cat <<EOT > /tmp/policy.hcl
path "kvv2/*" {
  capabilities = ["read"]
}
EOT
vault policy write static-demo /tmp/policy.hcl
# setup the necessary auth backend
vault auth enable kubernetes || true
vault write auth/kubernetes/config \
    kubernetes_host=https://kubernetes.default.svc
vault write auth/kubernetes/role/static-demo \
    bound_service_account_names=default \
    bound_service_account_namespaces=tenant-1,tenant-2 \
    policies=static-demo \
    ttl=1h
EOF

for ns in tenant-{1,2} ; do
    # kubectl delete namespace --wait --timeout=30s "${ns}" &> /dev/null || true
    kubectl create namespace "${ns}"
done

