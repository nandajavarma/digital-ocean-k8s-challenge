# Deployment

The setup of this architecture is based on [this
blogpost](https://medium.com/dzerolabs/using-tekton-and-argocd-to-set-up-a-kubernetes-native-build-release-pipeline-cf4f4d9972b0),
so please refer to that for more detailed exaplanation.

We have 4 main components needed to be setup for this GitOps setup:

- Cert manager: For TLS certification
- Ambassador Edge Stack: As the API gateway, to expose apps in the kubernetes cluster
- ArgoCD: For continuous deployment of apps to kubernetes cluster
- Tekton: For setting up pipelines that will do webhook triggered automated
  builds and invoking argoCD to deploy

Apart from the above setups, we use
[`kaniko`](https://github.com/GoogleContainerTools/kaniko) image to build the
docker container since using `docker build` inside a kubernetes cluster is not
considered safe.

Let us get started with the setup!

> For the sake of this exercise, I am setting up all of these in the same
> cluster as the application deployment cluster. In reality it is better to
> separate the argoCD setup from the cluster where to deploy the workload.

## Setup cert-manager

For this setup, I am using the
[`cert-manager`](https://github.com/sighupio/fury-kubernetes-ingress/tree/v1.10.0/katalog/cert-manager)
companent maintained by [`SIGHUP`](https://github.com/sighupio) as a part of
their Kubernetes distribution. To install run the command:

``` sh
$ kustomize build https://github.com/sighupio/fury-kubernetes-ingress/katalog/cert-manager\?ref\=v1.10.0 | kubectl apply -f-
```

Since it involves setup of CRDs that are to be installed in the same step, it
might be required to run the above command twice. You might still see a warning
about `ServiceMonitor` which is ignorable since it is not something we need for
this exercise, and to make it work, we will have to install another CRD.

## Setup Ambassador and configure TLS

To install Ambassador, you can run:

``` sh
$ kubectl apply -f https://www.getambassador.io/yaml/aes-crds.yaml && kubectl wait --for condition=established --timeout=90s crd -lproduct=aes && kubectl apply -f https://www.getambassador.io/yaml/aes.yaml && kubectl -n ambassador wait --for condition=available --timeout=90s deploy -lproduct=aes
```

You will see the following pods running in the `ambassador` namespace if
the above command was successful.

``` sh
$ kubectl get pods -n ambassador
NAME                                READY   STATUS    RESTARTS   AGE
ambassador-7b7f5f54c4-6mzgz         1/1     Running   0          10d
ambassador-agent-5fd9dbd766-72jqg   1/1     Running   0          10d
ambassador-redis-584cd89b45-5km45   1/1     Running   0          10d
```

To get the loadbalancer IP of ambbassador, you can run the following command:

``` sh
$ AMBASSADOR_IP=$(kubectl get -n ambassador service ambassador -o "go-template={{range .status.loadBalancer.ingress}}{{or .ip .hostname}}{{end}}")
```

### Configuring TLS

To configure TLS, I first added a DNS A mapping of the above `$AMBASSADOR_IP` to
a subdomain `cluster.nandaja.space`. Once this was done, all I had to do was to
create `ClusterIssuer`, `Certificate`, `Ambassador Mapping` and a `Service`. You
can find all this resource definition in the file
[ambassador-tls-issuer.yml](./ambassador/ambassador-tls-issuer.yml). To apply
it, run the command:

``` sh
$ kubectl apply -f ambassodar/ambassador-tls-issuer.yml
```

To check if certificates were issued correctly, you can run the following
command:

``` sh
kubectl describe certificates ambassador-certs -n ambassador
```

The above will produce an ouput, in the bottom of which, there will be a
`Status` section with following info:

``` sh
Status:
  Conditions:
    Last Transition Time:  2021-12-17T12:48:36Z
    Message:               Certificate is up to date and has not expired
    Observed Generation:   1
    Reason:                Ready
    Status:                True
    Type:                  Ready
```

All is good! Now all is left to do is updating ambassador to use this TLS. You
can find the configuration for this at
[ambassador-service.yml](./ambassador/ambassador-service.yml). Apply it as
follows:

``` sh
$ kubectl apply -f ambassador/ambassador-service.yml
```

And now ambassador should be happy! If you go to the `URL` you used to setup
TLS(in my case `cluster.nandaja.space`), you should be able to see the
ambassador landing page.

## ArgoCD

### Install ArgoCD in `argocd` namespace

``` sh
$ kubectl create ns argocd
$ kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.2.1/manifests/install.yaml 
```

This will create `CRD`s, `RoleBinding`s and a whole bunch of stuff needed for
argocd to work.

Once we are done with that, now we have to expose the argoCD using `ambassador`.
What we are trying to do is to point [`cluster.nandaja.space/argocd`](https://cluster.nandaja.space) to point to
our argocd setup. This involves updating a `Deployment` that was created in the
above command to add the --rootpath=/argo-cd flag to the argocd-server command,
creating a `Host` and `Mapping` resource for ambassador to route the requests.
The resources can be found in the file [`argocd.yml`](./argocd/argocd.yml).
Apply it using:

``` sh
$ kubectl apply -f ./argocd/argocd.yml
```

Once done, you should be able to go to `$AMBASSADOR_URL/argocd`(in mycase
`cluster.nandaja.space/argo-cd`) and see the landing page of `argocd`.

### Install argocd CLI

If you would like have a convienient way to work with argocd rather than using
UI for everything, I recommend installing `argocd` cli. Since I work on a mac,
for me it was just:

``` sh
$ brew install argocd
```

### Change password

To login to argocd (via UI or CLI), the default password is set as the hash of
the pod of deployment `argocd-server`. Unforunately, since we edited this.  

deployment above, the password is lost for good. We can patch the
`argocd-secret` to edit the password hash. So we will create a bcrypt hash of our
desired password and patch the secret with that.

``` sh
$ htpasswd -bnBC 10 "" banana | tr -d ':\n'
$2y$10$h9z7NRjy3bNH7MFgt8.pwumhHdn0sDVXmjvJ8iCIFlIo4zot6Y0K6
$ kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {
    "admin.password": "$2y$10$h9z7NRjy3bNH7MFgt8.pwumhHdn0sDVXmjvJ8iCIFlIo4zot6Y0K6", "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'
secret/arcocd-secret patched
```

You can try logging on to the UI at `cluster.nandaja.space/argo-cd`(that's
mine!), or via the argocd cli using the new password as follows:

``` sh
$ argocd login cluster.nandaja.space --grpc-web-root-path /argo-cd
```

Great! we are good with argo too! phew! You can see my setup of argo here:
[`cluster.nandaja.space/argocd`](https://cluster.nandaja.space).

## Install and setup tekton

We have to install tekton pipeline controllers & webhooks and tekton trigger
controllers & webhooks. To do this run the following commands:

``` sh
$ kubectl create ns tekton-pipelines
$ kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
$ kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
```

Please refer to tekton docs for more info.

### Setup PVC for tekton

Since tekton clone repos locally to build docker images, we need to allocate a
bit of storage for tekton. You can basically update the `ConfigMap` `config-artifact-pvc`
created by tekton to allocate this. You can find the configmap to replace it
with in [`pvc-config-map.yml`](./tekton/pvc-config-map.yml). Apply it using:

``` sh
kubectl replace -f ./tekton/pvc-config-map.yml
```

That's it folks! Our setup is complete.
