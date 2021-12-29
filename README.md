# GitOps pipeline using ArgoCD and Tekton

This is a demo of a kubernetes-native build/deploy pipeline using `Ambassador`,
`tekton` and `argocd`. The architecture of this pipeline is based of [this
blogpost](https://medium.com/dzerolabs/using-tekton-and-argocd-to-set-up-a-kubernetes-native-build-release-pipeline-cf4f4d9972b0).

For the purpose of demonstration, the workload I will be automating deployment
of, is [my personal blog](https://github.com/nandajavarma/blog). The repo of the
blog already has the kubernetes configurations necessary to deploy it in the
`deployment` directory.

A gist of how the pipeline would work is as follows:

- we have an API gateway setup for our cluster with ambassador.
- we have argocd and tekton setup in the cluster.
- we will have written tekton pipeline to automate build and deploy of an app.
- argocd will have two active `Applications`, one for the blog itself and
  another for the tekton pipeline that we just wrote.
- When someone push a change to the `main` branch of `blog`, a webhook is called
  from `github` to `tekton`, that trigger the pipeline and it build the `docker` image and push
  it to a registry using `kaniko`
- The `blog` Application on argo is synced to use the latest updates

> We will only use one k8s cluster for the deployment of argocd and that of the
> workload(blog). I'm sure you already know it, but this is not a great real
> life practice.

## Setup the Kubernetes cluster

We use terraform to setup a Kubernetes cluster on digital ocean. The
configuration needed to setup the cluster using terraform on DigitalOcean are
present in the [`terraform`](./terraform) directory. Please refer the
[`README`](./terraform/README.md) to setup a cluster using this configuration.
Once you have setup the cluster, move on to the next step to setup the
infrastructure for the pipeline.

## Install and setup ambassador, tekton and argocd

The configurations and steps to be followed to setup the infrastructure pipeline
can be found in the [`deployment`](./deployment) directory. Move on to the
[`README`](./deployment/README.md) there to complete the setup before moving forward.

## Create namespace and secrets for the pipeline

We are almost ready to get started with the pipeline code. We just are in short
of creating a namespace for the pipeline resources. We will also create secrets in the
same namespace that would give access to resources in that namespace to docker
regusernameistry we use, argocd installation and github.

The configuration for this is already bundled inside
[`manifests/config`](./manifests/config), but before we apply this, we have to
create env files used by this config as follows:

1. Docker registry secrets

    For the purpose of this demonstration, I will be using the container registry on
    digitalocean. We will use this to push the image built by tekton using kaniko. To give
    tekton to push, we first have to create a kubernetes secret with `username` and
    `password` both corresponding to Digitalocean registry.

    Go  to `Container Registry` on the navbar of DigitalOcean, go with the `Free`
    plan for this demo, Create a private container registry to add your images to.
    Once the registry is created, to access it, you can create a simple Digital
    Ocean `API` token(say `$DIGITAL_OCEAN_TOKEN`). Try logging in to registry using
    it:

    ``` sh
    $ docker loging -u $DIGITAL_OCEAN_TOKEN -p $DIGITAL_OCEAN_TOKEN registry.digitalocean.com
    Login Succeeded
    ```

    To create a secret from this, first create a file
    `manifests/config/git_app_secrets.env` with following data:

    ``` sh
    $ cat manifests/config/git_app_secrets.env
    username=<put your do token here>
    password=<put your do token here>
    ```

1. ArgoCD user credentials

    We have to let pipelines to access argoCD. You should already have username and
    password of argocd from the installation step. give the details in the file
    `./manifests/config/argocd_secrets.env` as follows:

    ``` sh
    $ cat ./manifests/config/argocd_secrets.env
    ARGOCD_USERNAME=admin
    ARGOCD_PASSWORD=banana
    ```

1. Github user credentials

    In case our repository is private, it is important to give the pipeline access
    to that. Create a personal access token on github. Add the following to the file
    `./manifests/config/git_app_secrets.env`:

    ``` sh
    $ cat ./manifests/config/git_app_secrets.env
    username=nandajavarma
    password=ghp_blahblahblahblah
    ```

Once we have all of the above set, it is time to create namespace and the
secrets under it, you can do that by running the command:

``` sh
$ kustomize build ./manifests/config/  | kubectl apply -f-
namespace/tekton-argocd-pipeline created
secret/argocd-env-secret created
secret/basic-docker-user-pass created
secret/basic-git-app-repo-user-pass created
```

## Create tekton reources, triggers, tasks and pipeline

## Add repos to argocd

## See the magic in action
