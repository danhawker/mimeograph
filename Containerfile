FROM registry.access.redhat.com/ubi8/ubi-minimal:latest

USER 0
#################################################################################
# OC Binaries and Tools

ARG OC_DOWNLOAD=https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
ARG OC_MIRROR_DOWNLOAD=https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/oc-mirror.tar.gz
ARG JQ_DOWNLOAD=https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
ARG YQ_DOWNLOAD=https://github.com/mikefarah/yq/releases/download/v4.27.5/yq_linux_amd64
ARG AWSCLI_DOWNLOAD=https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip

#################################################################################
# DNF Package List
ARG DNF_PACKAGES="\
  vim \
  file \
  wget \
  tar \
  unzip \
  iputils \
  skopeo \
  bind-utils \
"
# MICRODNF Install Packages
ARG DNF_FLAGS="\
  -y --nodocs --setopt=install_weak_deps=0 --setopt=keepcache=0"

# MICRODNF Update & Install Packages
RUN microdnf install ${DNF_FLAGS} ${DNF_PACKAGES} ;\
    microdnf clean all

#################################################################################
# Get OpenShift bits
RUN curl -L -o oc.tgz "$OC_DOWNLOAD" ;\
  tar -zxvf oc.tgz -C /usr/local/bin oc kubectl ;\
  rm -f oc.tgz
# Add OC mirror plugin
RUN curl -L -o oc-mirror.tgz "${OC_MIRROR_DOWNLOAD}" ;\
  tar -zxvf oc-mirror.tgz -C /usr/local/bin oc-mirror ;\
  rm -f oc-mirror.tgz

RUN chmod -R +x /usr/local/bin

#################################################################################
# Add JQ
RUN curl -L -o /usr/local/bin/jq "$JQ_DOWNLOAD" ; chmod +x /usr/local/bin/jq
# Add YQ
RUN curl -L -o /usr/local/bin/yq "$YQ_DOWNLOAD" ; chmod +x /usr/local/bin/yq
# Add and install awscli
RUN curl -L -o awscli.zip "$AWSCLI_DOWNLOAD" ;\
  unzip awscli.zip -d /tmp;\
  cd /tmp/aws ;\
  ./install ;\
  /usr/local/bin/aws --version ;\
  rm -rf /tmp/aws

#################################################################################
# Finalize
RUN mkdir -p /root/.docker

RUN mkdir -p /mimeograph/{bundle,metadata}
COPY mimeograph.sh /usr/local/bin/mimeograph.sh

WORKDIR /root/mimeograph

#ENTRYPOINT ["/usr/local/bin/mimeograph.sh"]
#CMD ["/bin/bash"]