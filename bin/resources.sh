#!/bin/bash

TMP_FILE=/tmp/resources.log

PS1="\033[01;32m${USER}\033[01;34m\$ \033[00m"

while true;
do
    rm $TMP_FILE
    touch $TMP_FILE
    
    CMD="kubectl -n pod-operator get pods"
    echo -e "$PS1$CMD" >> $TMP_FILE
    eval $CMD 2>&1 | sed 's/^\([^ ]*[ ]*[^ ]*[ ]*[^ ]*\).*/\1/g' 2>> $TMP_FILE >> $TMP_FILE

    echo "" >> $TMP_FILE
    CMD="kubectl -n pod-operator get podrequests"
    echo -e "$PS1$CMD" >> $TMP_FILE
    eval $CMD 2>> $TMP_FILE >> $TMP_FILE
    
    clear
    cat $TMP_FILE
    sleep 1s
done
