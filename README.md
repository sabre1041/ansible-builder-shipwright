# Ansible Builder Shipwright Demo

Creation of Ansible execution environments using [Ansible Builder](https://github.com/ansible/ansible-builder) and [OpenShift Builds](https://docs.openshift.com/builds/1.1/about/overview-openshift-builds.html) based on the [ShipWright framework](https://github.com/shipwright-io/build).

## Overview

OpenShift Builds and the underlying ShipWright project is a framework for building container images within Kubernetes. Ansible Execution environments are container images that are produced through the Ansible Builder project to enable the execution of Ansible automation using [ansible-runner](https://github.com/ansible/ansible-runner). Builds are achieved by creating a custom Shipwright `ClusterBuildStrategy` with the logic to produce container based Ansible Execution environments which are then published to a container registry.

## Prerequisites

Clone the project repository repository

```
git clone https://github.com/sabre1041/ansible-builder-shipwright
cd ansible-builder-shipwright
```

## Installation

The installation and configurations can either be completed manually or automated through an Ansible playbook. THe following steps will be performed:

1. Installation of [OpenShift Builds](https://docs.openshift.com/builds/1.1/installing/installing-openshift-builds.html)
2. Creation of a `ClusterBuildStrategy` for building Ansible Execution Environments
3. Creation of a new namespace to perform testing
4. Creation of a new `Build` to leverage the _ClusterBuildStrategy_ and a sample Execution Environment
5. Creation of policies to enable the Execution Environment build process

Both installation scenarios will be outlined which account the above set of tasks.The steps associated with the manual installation will be detailed first to illustrate the actions that will be automated using Ansible.

### Manual

Shipwright can be installed using an Operator or by applying manifests.

#### Installing Using the Operator

The OpenShift Builds Operator is available in OperatorHub and facilitates a seamless deployment into OpenShift.

1. Deploy the OpenShift Builds Operator:

```shell
kubectl apply -f resources/operator/olm
```

2. Wait until the Operator deploys and the `ShipwrightBuild` CR has been registered

```shell
until kubectl wait --for condition=established crd/shipwrightbuilds.operator.shipwright.io &>/dev/null; do sleep 5; done
```

3. Create the `ShipwrightBuild` resource

```shell
kubectl apply -f resources/operator/instance
```

#### Custom Build Strategy

Install the `ansible-builder` `ClusterBuildStrategy` by cloning this repository and adding the `ClusterBuildStrategy` to your environment.

Add the `ClusterBuildStrategy`

```
kubectl apply -f resources/clusterbuildstrategy/ansible-builder-clusterbuildstrategy.yml
```

#### Example

To demonstrate how an Ansible Execution environment can be produced and published to a container registry using Shipwright, an example implementation is provided within this repository.

1. Create a new Namespace called `ansible-builder-shipwright` and change the current context into the namespace

```shell
kubectl create namespace ansible-builder-shipwright
kubectl config set-context --current --namespace=ansible-builder-shipwright
```

2. Register the Shipwright Build

```shell
kubectl create -f example/ansible-builder-build.yml
```

Confirm that the Build has been registered properly

```shell
kubectl get builds.shipwright.io ansible-builder-example

NAME                                        REGISTERED   REASON                        BUILDSTRATEGYKIND      BUILDSTRATEGYNAME   CREATIONTIME
ansible-builder-example                     True         Succeeded                     ClusterBuildStrategy   ansible-builder     4h32m
```

3. Create a _ServiceAccount_ called `ansible-builder-shipwright` that will be used to execute the build.

```shell
kubectl apply -f resources/policies/serviceaccount.yml
```

4. Create a _Secret_ called `ansible-ee-images` containing credentials to access the Ansible Automation Platform images from the Red Hat Container Catalog or your authenticated registry by replacing your _username_ and _password_ and optionally _server_ by executing the following command:

```shell
kubectl create secret docker-registry ansible-ee-images --docker-username=<username> --docker-password=<password> --docker-server=registry.redhat.io
```

5. Patch the `ansible-builder-shipwright` _ServiceAccount_ with the `ansible-ee-images` _Secret_ so that the build will be able to access the protected images

```shell
kubectl patch serviceaccount ansible-builder-shipwright  -p '{"secrets": [{"name": "ansible-ee-images"}]}'
```

6. In order to perform non-privileged builds in OpenShift, a custom `SecurityContextConstraint` called `rootless-builds` provides the ability to leverage the necessary Linux capabilities to perform the builds.

Create the SCC and associated `ClusterRole` so that entities running within the cluster will be able to use the newly created SCC.

```shell
kubectl apply -f resources/policies/rootless-builds-scc.yml
kubectl apply -f resources/policies/rootless-builds-scc-clusterrole.yml
```

7. Grant Access to the `rootless-builds` SCC to the `ansible-builder-shipwright` _ServiceAccount_

```shell
kubectl apply -f resources/policies/rootless-builds-scc-rolebinding.yml
```

7. In order for the `ansible-builder-shipwright` _ServiceAccount_ to be able to push to OpenShift's internal registry, execute the following command to create a new _Rolebinding_ called `ansible-builder-shipwright-image-builder`:

```
kubectl apply -f resources/policies/image-builder-rolebinding.yml
```

### Ansible

Ansible can instead be used to accomplish the each of the preceding steps to simplify the installation process. The Ansible based assets can be found in the directory called `ansible` and the setup process is located in a file called `setup.yml` in the `ansible/playbooks` directory.

As part of the execution, the following extra variable must be provided at runtime:

* `container_registry_username` - Username for the Red Hat Container Catalog
* `container_registry_password` - Password for the Red Hat Container Catalog
* `container_registry_server` - Hostname for the Red Hat Container Catalog (defaults to `registry.redhat.io`)

The execution can either be performed locally using Ansible or through the use of an Execution Environment using `ansible-navigator`.

When running locally, ensure that you have the required dependencies installed

```shell
ansible-galaxy collection install -r ansible/requirements.yml
```

With the necessary tooling available, execute the following command to perform the setup process:

```shell
ansible-playbook ansible/playbooks/setup.yml -e container_registry_username="<username>" -e container_registry_password="<password>"
```

Alternatively, the same task can be accomplished using `ansible-navigator` by executing the following command:

```shell
ansible-navigator run ansible/playbooks/setup.yml --mode=stdout --eev ~/.kube:/opt/.kube --senv KUBECONFIG=/opt/.kube/config  -e container_registry_username="<username>" -e container_registry_password="<password>"
```

## Building an Execution Environment

With the Shipwright components now configured, let's build a sample Execution Environment. Similar to the installation, the execution can be accomplished either manually or by using Ansible.

### Manual

1. Start a new Build by creating a `BuildRun`

```shell
kubectl create -f example/ansible-builder-buildrun.yml
```

2. Monitor the progress of the BuildRun

You can monitor the progress of the build by using the `shp buildrun logs` command. Ensure that you have the Shipwright CLI (`shp`) installed on your machine

```shell
shp buildrun logs $(kubectl get buildruns.shipwright.io --sort-by=.metadata.creationTimestamp -o jsonpath='{ .items[-1:].metadata.name }') -F
```

The above command will display the logs for the most recent TaskRun

Once the build is complete, an image will be published to OpenShift's internal image registry. Alternatively, the produced image can also be stored in an external registry, such as quay.io by modifying the `ansible-builder-example` Build resource and modifying the `.spec.output.image` field.

### Ansible

Use the following commands to execute the build process using Ansible or `ansible-navigator`.

When using Ansible, execute the following:

```shell
ansible-playbook ansible/playbooks/build-ee.yml
```

When using `ansible-navigator`, execute the following:

```shell
ansible-navigator run ansible/playbooks/build-ee.yml --mode=stdout --eev ~/.kube:/opt/.kube --senv KUBECONFIG=/opt/.kube/config
```

## Verification

Verify the newly created Ansible Execution Environment

Confirm the functionality of the newly created Execution Environment by starting a pod that will list all pods within this namespace using the [k8s_info](https://docs.ansible.com/ansible/latest/collections/community/kubernetes/k8s_info_module.html) module from the [kubernetes.core collection](https://galaxy.ansible.com/kubernetes/core).

First, create a _Role_ and _RoleBinding_ with the necessary permissions to query the API:

```shell
kubectl apply -f resources/testing
```

Next, execute the following command to validate the Execution Environment:

```shell
kubectl run -n ansible-builder-shipwright -it ansible-builder-shipwright-example-ee --image=image-registry.openshift-image-registry.svc:5000/ansible-builder-shipwright/ansible-builder-shipwright-example-ee:latest --overrides "{ \"spec\": { \"serviceAccount\": \"ansible-builder-shipwright\" } }" --rm --restart=Never -- ansible-runner run --hosts localhost -m kubernetes.core.k8s_info -a "api_key={{ lookup('file', '/var/run/secrets/kubernetes.io/serviceaccount/token') }} ca_cert=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt host=https://kubernetes.default.svc kind=Pod  namespace=ansible-builder-shipwright validate_certs=yes" /tmp/ansible-runner
```

All of the pods in the _ansible-builder-shipwright_ Namespace will be displayed with the help from the `k8s_info` module from the `kubernetes.core` collection that wsa included in the Execution Environment as a result of the Shipwright build.s
