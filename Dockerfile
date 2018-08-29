FROM registry.access.redhat.com/rhel7-atomic

MAINTAINER Dan Hawker <dhawker@redhat.com>

# Add pre-reqs using microdnf
# Skopeo is in Extras. I've added wget, bind-utils and iputils for easier debugging.
RUN microdnf --enablerepo=rhel-7-server-rpms --enablerepo=rhel-7-server-extras-rpms install skopeo wget bind-utils iputils --nodocs ;\
    microdnf clean all

#CMD ["/usr/bin/skopeo", "--help"]
CMD ["inspect", "docker://registry.access.redhat.com/rhel7-atomic"]

ENTRYPOINT ["/usr/bin/skopeo"]
