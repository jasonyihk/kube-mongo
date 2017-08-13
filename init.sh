#!/usr/bin/env bash
set -eu

CMD_KUBE='kubectl --context kube-aws-k8s-uat-context' 
TMPFILE=$(mktemp)


openssl rand -base64 741 > $TMPFILE
$CMD_KUBE create secret -n database generic mongo-shared-secret --from-file=internal-auth-mongo-keyfile=$TMPFILE
rm $TMPFILE

$CMD_KUBE apply -n database -f k8s/
