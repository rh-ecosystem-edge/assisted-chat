FROM registry.access.redhat.com/ubi9/python-311:1-1779945715

USER 0
RUN yum install -y jq patch vim && yum clean all
RUN pip install yq google-cloud-aiplatform
RUN pip install --no-deps git+https://github.com/lightspeed-core/lightspeed-evaluation.git@e439782824ac1f04555fa476ffac441591e0138b#subdirectory=lsc_agent_eval && \
    pip install -r https://raw.githubusercontent.com/lightspeed-core/lightspeed-evaluation/e439782824ac1f04555fa476ffac441591e0138b/lsc_agent_eval/requirements.txt
RUN mkdir -p /opt/app-root/src
WORKDIR /opt/app-root/src
COPY . .
RUN chmod 755 test/prow/entrypoint.sh
RUN chmod 755 test/scripts/*.sh
