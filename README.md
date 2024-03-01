Repo for test and validate the issue on VSO using tenants.

### Prerequisites:
1. Install KIND
   From [KIND landing page](https://kind.sigs.k8s.io/docs/user/quick-start/)
   
3. Clone this repo:
   ```
   gh repo clone florintp-onboarding/vault-on-kind-raft3nodes
   cd vault-on-kind-raft3nodes
   ```
4. Observe the recorded session
   ```
   cat 139527.rec
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
   date ; kubectl get deployments -A
   date ; kubectl describe pod -n tenant-1
   date ; kubectl get sa -A
   date ; kubectl get crds
   ```
7. The similar output may be:
   ```
   Fri Mar  1 10:12:39 CET 2024
   NAMESPACE                NAME                                                         READY   STATUS              RESTARTS   AGE
   kns1                     vaultkns1-0                                                  1/1     Running             0          30m
   kns1                     vaultkns1-1                                                  1/1     Running             0          30m
   kns1                     vaultkns1-2                                                  1/1     Running             0          30m
   kns1                     vaultkns1-agent-injector-6fbf8d7db6-s9mtp                    1/1     Running             0          30m
   kns2                     vaultkns2-0                                                  1/1     Running             0          30m
   kns2                     vaultkns2-1                                                  1/1     Running             0          30m
   kns2                     vaultkns2-2                                                  1/1     Running             0          30m
   kns2                     vaultkns2-agent-injector-7f65575b56-rsq7d                    1/1     Running             0          30m
   tenant-1                 static-demo-66887f4f8f-nblt7                                 0/1     ContainerCreating   0          28m
   vault-secrets-operator   vault-secrets-operator-controller-manager-7f9b5577d6-hlgl2   2/2     Running             0          29m
   ```
