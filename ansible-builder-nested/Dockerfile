FROM registry.redhat.io/ansible-automation-platform-24/ansible-builder-rhel9:3.0

ENV BUILDAH_ISOLATION=chroot
ENV HOME=/home/builder

COPY --chown=0:0 entrypoint.sh /entrypoint.sh

RUN microdnf --disableplugin=subscription-manager install -y shadow-utils buildah && \
    microdnf update -y && \   
    microdnf clean all && \
    mkdir ${HOME} && \
    chmod +x /entrypoint.sh && \
    groupadd -r builder -g 1001 && \
    useradd -u 1001 -r -s /sbin/nologin -g 1001 -g root -G 1001 -m -d /home/builder -c "Builder user" builder  && \
    touch /etc/subgid /etc/subuid && \
    chmod -Rf g=u /etc/subuid /etc/subgid /etc/passwd /etc/group /home/builder && \
    chown -Rf 1001:0 /etc/subuid /etc/subgid /etc/passwd /etc/group /home/builder

USER 1001

WORKDIR /home/builder

ENTRYPOINT [ "/entrypoint.sh" ]
