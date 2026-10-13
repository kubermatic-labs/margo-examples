# Tools image for the example packages: LinkML for the Margo schema, PyYAML for the checks.
# Built once by hack/tools.sh, so nothing has to be installed on the host.
FROM python:3.12-slim

ARG LINKML_VERSION=1.12.0
RUN pip install --no-cache-dir "linkml==${LINKML_VERSION}"

WORKDIR /work
