Example operator used for DevConf.CZ 2020 presentation.

# Create the Operator

```bash
# export some things we'll need to reuse
export GO111MODULE=on
export QUAY_USERNAME=nmalik
export GITHUB_USERNAME=jewzaam
export OP_VERSION=0.0.1
export OP_NAME=pod-operator
export OP_API_GROUP=pod.jewzaam.org
export OP_API_VERSION=v1alpha1
export OP_KIND=PodRequest

# bootstrap the operator
mkdir -p $GOPATH/src/github.com/$GITHUB_USERNAME
cd $GOPATH/src/github.com/$GITHUB_USERNAME
operator-sdk new $OP_NAME
cd $OP_NAME

# generate CRD and Controller
operator-sdk add api --api-version=$OP_API_GROUP/$OP_API_VERSION --kind=$OP_KIND
operator-sdk add controller --api-version=$OP_API_GROUP/$OP_API_VERSION --kind=$OP_KIND
```

# Build and Push the Operator's Image

```bash
# build operator
operator-sdk build quay.io/$QUAY_USERNAME/$OP_NAME:$OP_VERSION

# tag image
docker tag quay.io/$QUAY_USERNAME/$OP_NAME:$OP_VERSION quay.io/$QUAY_USERNAME/$OP_NAME:latest

# push operator images
docker push quay.io/$QUAY_USERNAME/$OP_NAME:$OP_VERSION
docker push quay.io/$QUAY_USERNAME/$OP_NAME:latest
```

# Deploy the Operator

```bash
sed -i "s|REPLACE_IMAGE|quay.io/$QUAY_USERNAME/$OP_NAME:latest|g" deploy/operator.yaml

kubectl new-project pod-operator

kubectl create -f deploy/crds/*crd*.yaml
kubectl create -f deploy/service_account.yaml
kubectl create -f deploy/role.yaml
kubectl create -f deploy/role_binding.yaml
kubectl create -f deploy/operator.yaml
```

# Verify the Operator

## Create a PodRequest

```bash
# create the PodRequest
echo 'apiVersion: pod.jewzaam.org/v1alpha1
kind: PodRequest
metadata:
  name: busybox
  namespace: pod-operator
spec:
  name: busybox
  image: busybox
  command:
  - /bin/sh
  - -ec
  - while :; do echo "."; sleep 5; done' | kubectl create -f -

# verify it’s doing what we expected
kubectl logs busybox -f
```

## Delete a PodRequest

```bash
# delete and verify it's gone
kubectl delete podrequest busybox

# verify it's gone (or terminating)
kubectl get pods -l app=busybox
```