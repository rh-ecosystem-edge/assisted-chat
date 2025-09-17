FROM registry.access.redhat.com/ubi9/python-311:latest

USER 0
RUN yum install -y jq patch vim
RUN pip install yq
RUN pip install git+https://github.com/lightspeed-core/lightspeed-evaluation.git#subdirectory=lsc_agent_eval
RUN mkdir -p /opt/app-root/src
WORKDIR /opt/app-root/src
COPY . .
RUN chmod 755 test/prow/entrypoint.sh
RUN chmod 755 test/scripts/*.sh
