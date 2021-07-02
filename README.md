# ansible-builder-shipwright

Creation of Ansible execution environments using [Ansible Builder](https://github.com/ansible/ansible-builder) and [Shipwright](https://github.com/ansible/ansible-builder)

## Overview

Shipwright is a framework for building container images within Kubernetes. Ansible Execution environments are container images that are produced through the Ansible Builder project to enable the execution of Ansible automation using [ansible-runner](https://github.com/ansible/ansible-runner). Builds are achieved by creating a custom Shipwright `ClusterBuildStrategy` with the logic to produce container based Ansible Execution environments which are then published to a container registry. 

## Installation

Use the following steps to install Shipwright and the `ClusterBuildStrategy` to your environment

1. Install Tekton/OpenShift Pipelines. In an OpenShift environment, this can be achieved in OperatorHub by installing either OpenShift Pipelines.
2. Install Shipwright

```
kubectl apply --filename https://github.com/shipwright-io/build/releases/download/v0.5.1/release.yaml

kubectl apply --filename https://github.com/shipwright-io/build/releases/download/nightly/default_strategies.yaml
```

Confirm the operator is running in the `build-operator` project

```
kubectl get pods -n shipwright-build
```

3. Install the `ansible-builder` `ClusterBuildStrategy` by cloning this repository and adding the `ClusterBuildStrategy` to your environment

```
git clone https://github.com/sabre1041/ansible-builder-shipwright
cd ansible-builder-shipwright
kubectl apply -f resources/ansible-builder-clusterbuildstrategy.yml
```

## Example

To demonstrate how an Ansible Execution environment can be produced and published to a container registry using Shipwright, an example implementation is provided within this repository.

1. Create a new Namespace called `ansible-builder-shipwright` and change the current context into the namespace

```
kubectl create namespace ansible-builder-shipwright
kubectl config set-context --current --namespace=ansible-builder-shipwright
```

2. Register the Shipwright Build

```
kubectl create -f example/ansible-builder-build.yml
```

Confirm that the Build has been registered properly

```
kubectl get builds.shipwright.io ansible-builder-example

NAME                                        REGISTERED   REASON                        BUILDSTRATEGYKIND      BUILDSTRATEGYNAME   CREATIONTIME
ansible-builder-example                     True         Succeeded                     ClusterBuildStrategy   ansible-builder     4h32m
```

3. Create a _ServiceAccount_ called `ansible-builder-shipwright` that will be used to execute the build.

```
kubectl apply -f resources/serviceaccount.yml
```

4. Create a _Secret_ called `ansible-ee-images` containing credentials to access the Ansible Automation Platform images from the authenticated registry by replacing your _username_ and _password_ and executing the following command:

```
kubectl create secret docker-registry ansible-ee-images --docker-username=<username> --docker-password=<password> --docker-server=quay.io
```

5. Patch the `ansible-builder-shipwright` _ServiceAccount_ with the `ansible-ee-images` _Secret_ so that the build will be able to access the protected images

```
kubectl patch serviceaccount ansible-builder-shipwright  -p '{"secrets": [{"name": "ansible-ee-images"}]}'
```

6. Grant Access to the `privileged` SCC (OpenShift) to the `ansible-builder-shipwright` _ServiceAccount_

Elevated permissions through the use of a privileged container is needed during the build process and when running on OpenShift, access to the `privileged` Security Context Constraint is required. Grant the `ansible-builder-shipwright` ServiceAccount previously created access to the SCC by creating a _RoleBinding_ by executing the following command:

```
kubectl apply -f resources/privileged-scc-rolebinding.yml
```

7. In order for the `ansible-builder-shipwright` _ServiceAccount_ to be able to push to OpenShift's internal registry, execute the following command to create a new _Rolebinding_ called `ansible-builder-shipwright-image-pusher`:

```
kubectl apply -f resources/edit-rolebinding.yml
```

8. Start a new Build by creating a `BuildRun`

```
kubectl create -f example/ansible-builder-buildrun.yml
```

9. Monitor the progress of the BuildRun

You can monitor the progress of the build which is executed using a Tekton `TaskRun` if you have the Tekton CLI (`tkn`) installed on your machine

```
tkn taskrun logs -f -L
```

The above command will display the logs for the most recent TaskRun

Once the build is complete, an image will be published to OpenShift's internal image registry. Alternatively, the produced image can also be stored in an external registry, such as quay.io by modifying the `ansible-builder-example` Build resource and modifying the `output.image` field.

10. Verify the newly created Ansible Execution Environment

Confirm the functionality of the newly created Execution Environment by starting a pod that will list all pods within this namespace using the [k8s_info](https://docs.ansible.com/ansible/latest/collections/community/kubernetes/k8s_info_module.html) module from the [community.kubernetes collection](https://galaxy.ansible.com/community/kubernetes), execute the following command:

```
kubectl run -it ansible-builder-shipwright-example-ee --image=image-registry.openshift-image-registry.svc:5000/ansible-builder-shipwright/ansible-builder-shipwright-example-ee:latest --serviceaccount=ansible-builder-shipwright --rm --restart=Never -- ansible-runner run --hosts localhost -m community.kubernetes.k8s_info -a "api_key={{ lookup('file', '/var/run/secrets/kubernetes.io/serviceaccount/token') }} ca_cert=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt host=https://kubernetes.default.svc kind=Pod  namespace=ansible-builder-shipwright validate_certs=yes" /tmp/ansible-runner
```
