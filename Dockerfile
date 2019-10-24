# Dockerfile may have two Arguments: tag, branch
# tag - tag for the Base image, (e.g. 1.10.0-py3 for tensorflow)
# branch - user repository branch to clone (default: master, other option: test)

ARG tag=1.12.0-py3

# Base image, e.g. tensorflow/tensorflow:1.12.0-py3
FROM tensorflow/tensorflow:${tag}

LABEL maintainer="Lara Lloret Iglesias <lloret@ifca.unican.es>"
LABEL version="0.1"
LABEL description="DEEP as a Service Container: Plants Classification"

# Add container's metadata to appear along the models metadata
ENV CONTAINER_MAINTAINER "Lara Lloret Iglesias <lloret@ifca.unican.es>"
ENV CONTAINER_VERSION "0.1"
ENV CONTAINER_DESCRIPTION "DEEP as a Service Container: Plants Classification"

# python version
ARG pyVer=python3

# What user branch to clone (!)
ARG branch=master

# Install ubuntu updates and python related stuff
# link python3 to python, pip3 to pip, if needed
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
         git \
         curl \
         wget \
         $pyVer-setuptools \
         $pyVer-pip \
         psmisc \
         $pyVer-wheel && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/* && \
    if [ "$pyVer" = "python3" ] ; then \
       if [ ! -e /usr/bin/pip ]; then \
          ln -s /usr/bin/pip3 /usr/bin/pip; \
       fi; \
       if [ ! -e /usr/bin/python ]; then \
          ln -s /usr/bin/python3 /usr/bin/python; \
       fi; \
    fi && \
    python --version && \
    pip --version

# Set LANG environment
ENV LANG C.UTF-8

# Set the working directory
WORKDIR /srv

# Install rclone
RUN wget https://downloads.rclone.org/rclone-current-linux-amd64.deb && \
    dpkg -i rclone-current-linux-amd64.deb && \
    apt install -f && \
    mkdir /srv/.rclone/ && touch /srv/.rclone/rclone.conf && \
    rm rclone-current-linux-amd64.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*

# Install FLAAT (FLAsk support for handling Access Tokens)
RUN pip install --no-cache-dir flaat && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*

# Disable FLAAT authentication by default
ENV DISABLE_AUTHENTICATION_AND_ASSUME_AUTHENTICATED_USER yes

# Install DEEPaaS from PyPi:
RUN pip install --no-cache-dir deepaas && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*

# Useful tool to debug extensions loading
RUN pip install --no-cache-dir entry_point_inspector && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*

# Install user app:
RUN git clone -b $branch https://github.com/deephdc/image-classification-tf && \
    cd image-classification-tf && \
    pip install --no-cache-dir -e . && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/* && \
    cd ..

# Download network weights

## Trained on Plantnet
#ENV SWIFT_CONTAINER https://cephrgw01.ifca.es:8080/swift/v1/plants-tf/
#ENV MODEL_TAR plants.tar.xz

# Trained on iNaturalist
ENV SWIFT_CONTAINER https://cephrgw01.ifca.es:8080/swift/v1/inaturalist_plants-tf/
ENV MODEL_TAR inaturalist_plants.tar.xz

RUN curl -o ./image-classification-tf/models/${MODEL_TAR} \
    ${SWIFT_CONTAINER}${MODEL_TAR}

RUN cd image-classification-tf/models && \
        tar -xf ${MODEL_TAR}

# Install JupyterLab
RUN pip install --no-cache-dir jupyterlab && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*

# Configure JupyterLab and use /bin/bash for JupyterLab terminal
ENV JUPYTER_CONFIG_DIR /srv/.jupyter/
COPY jupyter/jupyter_notebook_config.py /srv/.jupyter/
COPY jupyter/run_jupyter.sh /srv/.jupyter/
RUN chmod a+x /srv/.jupyter/run_jupyter.sh
ENV SHELL /bin/bash

# Open DEEPaaS port
EXPOSE 5000

# Open Monitoring port
EXPOSE 6006

# Open JupyterLab port
EXPOSE 8888

# Account for OpenWisk functionality (deepaas >=0.4.0) + proper docker stop
CMD ["deepaas-run", "--openwhisk-detect", "--listen-ip", "0.0.0.0", "--listen-port", "5000"]
