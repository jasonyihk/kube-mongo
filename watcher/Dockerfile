FROM alpine:3.6

LABEL maintainer <digital.innovation@infinitus-int.com>

ARG KUBE_VERSION=v1.7.3

ADD https://storage.googleapis.com/kubernetes-release/release/${KUBE_VERSION}/bin/linux/amd64/kubectl /usr/local/bin/kubectl

RUN set -x && \
    apk add --no-cache mongodb curl ca-certificates && \
    chmod +x /usr/local/bin/kubectl && \
    kubectl version --client

COPY mongo-watch.sh /mongo-watch.sh

RUN chmod +x /mongo-watch.sh

# COMMAND TO RUN WHEN RUNNING THE CONTAINER
CMD ["/mongo-watch.sh"]