FROM registry.access.redhat.com/rhel7-atomic

LABEL name="Mimeograph"
LABEL maintainer="Dan Hawker <dhawker@redhat.com>"
LABEL description="Container Copying and Syncronisation Tool that leverages Skopeo (https://github.com/containers/skopeo)"

ENV OC_DOWNLOAD https://github.com/openshift/origin/releases/download/v3.9.0/openshift-origin-client-tools-v3.9.0-191fece-linux-64bit.tar.gz
ENV JQ_DOWNLOAD https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64

# Add pre-reqs using microdnf
# Skopeo is in Extras. 
# JQ is in EPEL, so I've downloaded it and bundled in the source.
# I've added wget, bind-utils and iputils for easier debugging.
RUN microdnf --enablerepo=rhel-7-server-rpms --enablerepo=rhel-7-server-extras-rpms install skopeo wget bind-utils iputils --nodocs ;\
    microdnf clean all

WORKDIR /

# Add OC client tools
RUN curl -L -o oc.tgz "$OC_DOWNLOAD" ;\
  tar -zxvf oc.tgz -C /usr/bin openshift-origin-client-tools-v3.9.0-191fece-linux-64bit/oc --strip-components 1

# Add JQ
RUN curl -L -o /usr/bin/jq "$JQ_DOWNLOAD" ; chmod +x /usr/bin/jq 

COPY config.json /config.json 
#COPY jq /usr/bin/jq
COPY mimeograph.sh /usr/bin/mimeograph.sh

#CMD ["/usr/bin/skopeo", "--help"]
#CMD ["inspect", "docker://registry.access.redhat.com/rhel7-atomic"]

#ENTRYPOINT ["/usr/bin/skopeo"]
ENTRYPOINT ["/usr/bin/mimeograph.sh"]
