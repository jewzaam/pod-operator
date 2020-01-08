#!/bin/bash

set -e

# export some things we'll need to reuse
export GO111MODULE=on
export QUAY_USERNAME=nmalik
export GITHUB_USERNAME=jewzaam
export OP_VERSION=0.0.1
export OP_NAME=pod-operator
export OP_API_GROUP=pod.jewzaam.org
export OP_API_VERSION=v1alpha1
export OP_KIND=PodRequest

export STEP_NUMBER=1

cat << EOF > /tmp/podrequest.yaml
apiVersion: pod.jewzaam.org/v1alpha1
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
  - while :; do echo "Hello DevConf.CZ 2020!"; sleep 5; done
EOF

pause() {
  ps1
  echo "# ${STEP_NUMBER} ${1}"
  STEP_NUMBER=$((STEP_NUMBER+1))
  if [ "$2" != "" ];
  then
    ps1
    echo -n "${2}"
  fi
  read
  if [ "$3" != "" ];
  then
    eval "${3}"
  elif [ "$2" != "" ];
  then
    eval "${2}"
  fi
}

ps1() {
  echo -ne "\033[01;32m${USER} \033[01;34m$(basename $(pwd))\$ \033[00m"
}

echocmd() {
  echo $(ps1)$@
}

docmd() {
  echocmd $@
  $@
}

# ensure clean initial state
rm -rf $GOPATH/src/github.com/$GITHUB_USERNAME/pod-operator 2>&1 >/dev/null
kubectl delete project pod-operator 2>&1 >/dev/null
kubectl delete crds podrequests.pod.jewzaam.org 2>&1 >/dev/null
mkdir -p $GOPATH/src/github.com/$GITHUB_USERNAME 2>&1 >/dev/null
cd $GOPATH/src/github.com/$GITHUB_USERNAME 2>&1 >/dev/null
clear

CMD="operator-sdk new $OP_NAME"
pause "create Operator" "$CMD"
docmd cd $OP_NAME

pause "create Custom Resource Definition" "operator-sdk add api --kind=$OP_KIND" "operator-sdk add api --api-version=$OP_API_GROUP/$OP_API_VERSION --kind=$OP_KIND"

pause "create Controller" "operator-sdk add controller --kind=$OP_KIND" "operator-sdk add controller --api-version=$OP_API_GROUP/$OP_API_VERSION --kind=$OP_KIND"

pause "review Controller and edit CRD & Controller" "code ." "code $(pwd) $(find -name '*_controller.go') $(find -name '*_types.go')"

CMD="operator-sdk generate openapi"
pause "generate updated CRDs" "$CMD"

CMD="operator-sdk build quay.io/$QUAY_USERNAME/$OP_NAME:latest"
pause "build Operator" "$CMD"

CMD="docker push quay.io/$QUAY_USERNAME/$OP_NAME:latest"
pause "push Image" "$CMD"

CMD="sed -i \"s|REPLACE_IMAGE|quay.io/$QUAY_USERNAME/$OP_NAME:latest|g\" deploy/operator.yaml"
pause "set deployment image" "$CMD"
docmd grep image: deploy/operator.yaml

CMD="kubectl create namespace pod-operator"
pause "create namespace" "$CMD"

CMD="kubectl -n pod-operator create -f deploy/crds/*crd*.yaml -f deploy/service_account.yaml -f deploy/role.yaml -f deploy/role_binding.yaml -f deploy/operator.yaml"
pause "deploy Operator" "$CMD"

cat /tmp/podrequest.yaml
CMD="kubectl -n pod-operator create -f /tmp/podrequest.yaml"
pause "create PodRequest" "$CMD"

CMD="kubectl -n pod-operator wait --for=condition=Ready pod/busybox"
pause "wait for busybox Pod" "$CMD"

CMD="kubectl -n pod-operator logs busybox"
pause "review busybox logs" "$CMD"

CMD="kubectl -n pod-operator delete pod busybox"
pause "delete Pod (it's recreated)" "$CMD"

CMD="kubectl -n pod-operator delete podrequest busybox"
pause "delete PodRequest" "$CMD"

pause "done!"
kubectl delete namespace pod-operator
kubectl delete crds podrequests.pod.jewzaam.org

