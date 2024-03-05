Repo for test and validate the issue on VSO using tenants.

### Prerequisites:
1. Install KIND
   From [KIND landing page](https://kind.sigs.k8s.io/docs/user/quick-start/)
   
3. Clone this repo:
   ```
   gh repo clone florintp-onboarding/vault-on-kind-raft3nodes
   cd vault-on-kind-raft3nodes
   ```
4. Observe the recorded sessions
   ```
   #Broken one: cat 139527.rec
   cat 139527-2.rec
   ```


### Steps to reproduce the issue at will (optional)
1. Create a file containing and add the RAW data of a valide Vault license as `vault_licence.hclic`
2. Execute the script:
   ```
   bash replication_2xvault.sh
   ```
   
3. Install the latest VSO
   ````
   helm repo update

   helm install vault-secrets-operator hashicorp/vault-secrets-operator \
    --create-namespace \
    --namespace vault-secrets-operator
   ````
   
4. Execute the script to create tenants and namespaces
   ```
   bash setup.sh
   ```
   
5. Apply the example in static.yaml:
   ```
   kubectl apply -f static.yaml
   ```

6. Check the state of the POD from deployed application and observe that it is still in <bold>ContainerCreating</code> state:
   ```
   date ;kubectl get pods -A |egrep 'NAME|vault|tenant'
   date ; kubectl get crds
   date ;kubectl -n kns1 exec -i vaultkns1-0 -- vault kv get -format=json  kvv2/secret |jq -r '.data.data'
   date ;kubectl -n kns2 exec -i vaultkns2-0 -- vault kv get -format=json  kvv2/secret |jq -r '.data.data'
   kubectl exec -ti -n tenant-1 $(kubectl get pods -n tenant-1|grep Runn)  -- cat  /etc/secrets/password
   echo
   kubectl exec -ti -n tenant-2 $(kubectl get pods -n tenant-2|grep Runn)  -- cat  /etc/secrets/password
   echo
   ```
   (Optional checks)
   ```
   date ; kubectl get deployments -A
   date ; kubectl describe pod -n tenant-1
   date ; kubectl get sa -A
 
   ```
7. The similar output may be:
````
Tue Mar  5 10:55:08 CET 2024
NAMESPACE                NAME                                                         READY   STATUS    RESTARTS   AGE
kns1                     vaultkns1-0                                                  1/1     Running   0          6m33s
kns1                     vaultkns1-1                                                  1/1     Running   0          6m32s
kns1                     vaultkns1-2                                                  1/1     Running   0          6m32s
kns1                     vaultkns1-agent-injector-6fbf8d7db6-r6k9n                    1/1     Running   0          6m33s
kns2                     vaultkns2-0                                                  1/1     Running   0          5m54s
kns2                     vaultkns2-1                                                  1/1     Running   0          5m53s
kns2                     vaultkns2-2                                                  1/1     Running   0          5m53s
kns2                     vaultkns2-agent-injector-7f65575b56-knrrr                    1/1     Running   0          5m54s
tenant-1                 static-demo-858ccf5897-bglqq                                 1/1     Running   0          107s
tenant-2                 static-demo-old-66cfc4bb7d-ppxnr                             1/1     Running   0          107s
vault-secrets-operator   vault-secrets-operator-controller-manager-7f9b5577d6-lg9hf   2/2     Running   0          5m19s
Tue Mar  5 10:55:08 CET 2024
NAME                                          CREATED AT
hcpauths.secrets.hashicorp.com                2024-03-05T09:49:49Z
hcpvaultsecretsapps.secrets.hashicorp.com     2024-03-05T09:49:49Z
secrettransformations.secrets.hashicorp.com   2024-03-05T09:49:49Z
vaultauths.secrets.hashicorp.com              2024-03-05T09:49:49Z
vaultconnections.secrets.hashicorp.com        2024-03-05T09:49:49Z
vaultdynamicsecrets.secrets.hashicorp.com     2024-03-05T09:49:49Z
vaultpkisecrets.secrets.hashicorp.com         2024-03-05T09:49:49Z
vaultstaticsecrets.secrets.hashicorp.com      2024-03-05T09:49:49Z
Tue Mar  5 10:55:09 CET 2024
{
  "password": "db-secret-password",
  "username": "db-readonly-username"
}
Tue Mar  5 10:55:09 CET 2024
{
  "password": "db-secret-password-tenant-2-old",
  "username": "db-readonly-username-old"
}
db-secret-password
db-secret-password-tenant-2-old
````
8. Cleanup
   ````
   bash cleanup.sh
   ````
