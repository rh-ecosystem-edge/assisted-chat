FROM registry.access.redhat.com/ubi9/python-311:latest

USER 0
RUN yum install -y jq patch curl tar gzip && yum clean all
RUN pip install yq
RUN pip install git+https://github.com/lightspeed-core/lightspeed-evaluation.git#subdirectory=lsc_agent_eval
RUN curl -fsSL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz -o /tmp/oc.tar.gz \
    && tar -xzf /tmp/oc.tar.gz -C /usr/local/bin oc kubectl \
    && chmod +x /usr/local/bin/oc /usr/local/bin/kubectl \
    && rm -f /tmp/oc.tar.gz
RUN mkdir -p /opt/app-root/src
WORKDIR /opt/app-root/src
COPY . .
RUN chmod 755 test/prow/entrypoint.sh
