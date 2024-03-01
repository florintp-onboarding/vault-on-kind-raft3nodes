#!/bin/bash
# https://support.hashicorp.com/hc/en-us/articles/20953204088083-How-To-Setup-Readiness-Liveness-Probes-with-Replication
# https://developer.hashicorp.com/vault/api-docs/system/health
# https://github.com/hashicorp/vault-helm/blob/main/values.yaml
# https://github.com/hashicorp/vault-helm/blob/main/values.yaml#L532
# https://github.com/hashicorp/vault-helm/blob/main/values.yaml#L514
# https://support.hashicorp.com/hc/en-us/articles/17924778977427-What-is-resolver-discover-servers-option-and-when-it-should-be-used
# https://developer.hashicorp.com/vault/docs/configuration/replication#resolver_discover_servers
# https://developer.hashicorp.com/vault/api-docs/system/replication/replication-performance#primary_api_addr
# https://developer.hashicorp.com/vault/docs/platform/k8s/helm/examples/enterprise-dr-with-raft
#
export REPLICAS=3
export C_REPLICAS=$(( $REPLICAS + 1 ))
export N_REPLICAS=$(( $REPLICAS - 1 ))
export VAULT_LICENSE=$(cat ./vault_license.hclic)

loginfo() {
 local timestamp
 timestamp=$(date +"%Y-%m-%d %H:%M:%S")
 printf '\n%s'  "[$timestamp] $message"
 echo "$@"
}

function delete_kind () {
  local _cluster="${1}"
  kind delete cluster --name=kind${_cluster} 
  return 0
}

function create_kind() {
  local _cluster="${1}"
  cat > workers.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: kind1
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
- role: worker
- role: worker
EOF
  kind create cluster --name=kind${_cluster}  --config=workers.yaml
  kubectl cluster-info --context kind-kind${_cluster} 
  return 0
}

function create_license() {
  local _ns="${1}"
  kubectl delete namespace ${_ns} &>/dev/null
  kubectl create namespace ${_ns}
 
  kubectl create secret generic \
          vault-license \
          -n "${_ns}" \
   	 --from-literal='VAULT_LICENSE='${VAULT_LICENSE} &>/dev/null
  #	 --from-literal='VAULT_LICENSE='${VAULT_LICENSE} 
  return
}


function create_vault() {
  local _ns="${1}"
  helm install vault${_ns} hashicorp/vault \
    --set='server.image.repository=hashicorp/vault-enterprise' \
    --set='server.image.tag=1.15.5-ent' \
    --set='server.ha.enabled=true' \
    --set='server.ha.replicas='${REPLICAS?} \
    --set='server.ha.raft.enabled=true' \
    --set='server.logLevel=trace' \
    --set='server.enterpriseLicense.secretName=vault-license' \
    --set='server.enterpriseLicense.secretKey=VAULT_LICENSE' \
    --set='server.affinity=' \
    --namespace "${_ns?}"
  #  --create-namespace 
  
  loginfo "
  $(kubectl get pods -n ${_ns} |egrep -i 'vault|^NAME')"
  
  loginfo '# Waiting for All Vault PODs to reach into Running state:'
  while [ $(kubectl get pods -n ${_ns?} -o json|jq -r '.items[]|{pod:.metadata.name, state:.status.phase}|select ( .state == "Running" )|.pod' |wc -l|awk '{print $1}') -lt ${C_REPLICAS} ] ; do
    #loginfo '# Waiting for all Vault PODs ...'
    printf '\r%s' "$(date)"
    sleep 1
  done
  loginfo "# All Vault PODs are in Running state!
  $(kubectl get pods -n ${_ns?} |egrep -i 'vault|^NAME')"
  
  loginfo "# Waiting for Vault process to start on POD."
  sleep 1
  
  while [ "Z$(kubectl exec -n ${_ns?} -ti "vault${_ns}-0" -- pgrep vault 2>/dev/null|wc -l|awk '{print $1}')" == "Z" ] ; do
    printf '\r%s' "$(date)" &&  sleep 1
    kubectl exec -n ${_ns?} -ti vault${_ns}-0 -- pgrep vault 2>/dev/null|wc -l|awk '{print $1}'
  done
  loginfo "PID Vault: $(kubectl exec -n ${_ns?} -ti vault${_ns}-0 -- pgrep vault)"
  
  loginfo "
  $(kubectl get pods -n ${_ns?} |egrep -i 'vault|^NAME')"
  
  local kunseal
  export kunseal=$(kubectl exec -n ${_ns?} -ti vault${_ns}-0 -- vault operator init -t 1 -n 1 -format=json)
  echo "$kunseal" > init-keys_${_ns}.json
  sleep 3
  
  for key in $(echo "$kunseal"|jq -r '.unseal_keys_b64[]') ; do
    loginfo "Seal state: $(kubectl exec -n ${_ns?} -ti vault${_ns}-0 -- vault status 2>/dev/null |grep 'Sealed'|grep 'false'|wc -l|awk '{print $1}') "
    if [ $(kubectl exec -n ${_ns?} -ti vault${_ns}-0 -- vault status 2>/dev/null |grep 'Sealed'|grep 'false'|wc -l|awk '{print $1}') -eq 1 ]
    then
  	 :
    else
       #loginfo "Unsealing vault-0 with Key $key"
       kubectl exec -n ${_ns?} -ti vault${_ns}-0 -- vault operator unseal $key |grep 'Unseal Progress'
    fi
  done
  
  loginfo "
  $(kubectl get pods -n ${_ns?} |egrep -i 'vault|^NAME')"


  export ROOT_TOKEN1=$(echo "$kunseal"|jq -r '.root_token')
  kubectl exec  -n "${_ns}" -ti vault${_ns}-0 -- vault login ${ROOT_TOKEN1?}
  kubectl exec  -n "${_ns}" -ti vault${_ns}-0 -- vault operator raft list-peers

  # JOIN NODES to VAULT CLUSTER (replicas-1)
  #kubectl exec -ti vault-1 -- vault operator raft join http://vault-0.vault-internal:8200
  #kubectl exec -ti vault-1 -- vault operator unseal
  for nodeid in $(seq 1 ${N_REPLICAS}) ; do
    loginfo "JOINING node vault${_ns}-${nodeid}"
    kubectl exec -n ${_ns?} -ti "vault${_ns}-${nodeid}" -- vault operator raft join http://vault${_ns}-0.vault${_ns}-internal:8200
    loginfo "Seal state: $(kubectl exec -n ${_ns?} -ti "vault${_ns}-${nodeid}" -- vault status 2>/dev/null |grep 'Sealed'|grep 'false'|wc -l|awk '{print $1}') "
    for key in $(echo "$kunseal"|jq -r '.unseal_keys_b64[]') ; do
    if [ $(kubectl exec -n ${_ns?} -ti "vault${_ns}-${nodeid}" -- vault status 2>/dev/null |grep 'Sealed'|grep 'false'|wc -l|awk '{print $1}') -eq 1 ]
    then
       # Already unsealed
       kubectl exec -n ${_ns?} -ti vault${_ns}-${nodeid} -- vault status
       :
     else
      #loginfo "Unsealing vault-${nodeid}  with Key $key"
      kubectl exec -n ${_ns?} -ti vault${_ns}-${nodeid} -- vault operator unseal $key &>/dev/null |grep 'Unseal Progress'
     fi
    done
  
  done
  return 0
}

delete_kind 139527
create_kind 139527

helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update hashicorp

for i in $(seq 2) ; do
  create_license kns${i}
  #[ -t ] && kubectl get secret vault-license -n ${NAMESPACE} -o json
  #[ -t ] && kubectl get secret vault-license -n default -o json
  create_vault "kns${i}"
done

read x
exit

