FROM ocp/ubi-python-311:9

RUN yum install -y jq patch
RUN pip install git+https://github.com/lightspeed-core/lightspeed-evaluation.git#subdirectory=lsc_agent_eval
RUN mkdir -p /opt/app-root/src
WORKDIR /opt/app-root/src
COPY . .

ENTRYPOINT [ "/opt/app-root/src/test/prow/entrypoint.sh" ]