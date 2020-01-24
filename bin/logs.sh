#!/bin/bash

TMP_FILE=/tmp/operator.log
TMP_FILE_OLD=${TMP_FILE}.old

rm $TMP_FILE_OLD
touch $TMP_FILE_OLD

PS1="\033[01;32m${USER}\033[01;34m\$ \033[00m"

while true;
do
    rm $TMP_FILE
    touch $TMP_FILE
    
    OP_POD_NAME=""
    
    OP_POD_NAME=$(kubectl get pods -n pod-operator -l name=pod-operator --no-headers 2>/dev/null | awk '{print $1}')

    if [ "$OP_POD_NAME" == "" ];
    then
        echo "Waiting for pod-operator logs..." >> $TMP_FILE
    else
        CMD="kubectl -n pod-operator logs -f $OP_POD_NAME"
        echo -e "$PS1$CMD" >> $TMP_FILE

        kubectl -n pod-operator wait --for=condition=Ready pod/$OP_POD_NAME >/dev/null
        kubectl -n pod-operator logs $OP_POD_NAME | grep -v "Skip" | jq -c 'del(.level) | del(.logger) | del(.["Pod.Namespace"]) | del(.["Request.Namespace"]) | del(.["Request.Name"]) | .ts |= round' >> $TMP_FILE
    fi

    diff $TMP_FILE $TMP_FILE_OLD
    if [ "$?" != "0" ];
    then
        # all in the name of making a visually appealing demo, this reduces flickering of the text
        clear
        cat $TMP_FILE | grep -v "^{"
        cat $TMP_FILE | grep "^{" | jq -c
        cp $TMP_FILE $TMP_FILE_OLD
    fi
    sleep 1s
done
