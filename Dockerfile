FROM ubuntu:16.04
MAINTAINER Makoto Kato <m_kato@ga2.so-net.ne.jp>

# For latest git
RUN apt-get update
RUN apt-get install -y software-properties-common
RUN add-apt-repository ppa:git-core/ppa
RUN apt-get update
RUN apt-get install -y git

# dos2unix is used to normalize generated files from windows
RUN apt-get install -y dos2unix

# Livegrep (Bazel is needed for Livegrep builds, OpenJDK 8 required for bazel)
RUN apt-get install -y unzip openjdk-8-jdk libssl-dev

# Install Bazel 0.16.1
# Note that bazel unzips itself so we can't just pipe it to sudo bash.
RUN apt-get install -y curl
WORKDIR /work/bazel
RUN curl -sSfL -O https://github.com/bazelbuild/bazel/releases/download/0.16.1/bazel-0.16.1-installer-linux-x86_64.sh && \
    chmod +x bazel-0.16.1-installer-linux-x86_64.sh && \
    ./bazel-0.16.1-installer-linux-x86_64.sh
WORKDIR /work

# pygit2
RUN apt-get install -y python-virtualenv python-dev libffi-dev cmake

# Other
RUN apt-get install -y parallel realpath unzip python-pip

# Nginx
RUN apt-get install -y nginx

RUN apt-get install pkg-config

# Install codesearch.
WORKDIR /work
RUN rm -rf livegrep
RUN git clone -b mozsearch-version3 https://github.com/mozsearch/livegrep
# The last two options turn off the bazel sandbox, which doesn't work
# inside an LDX container.
WORKDIR /work/livegrep
RUN bazel build //src/tools:codesearch --spawn_strategy=standalone --genrule_strategy=standalone && \
    install bazel-bin/src/tools/codesearch /usr/local/bin
WORKDIR /work

# Remove ~2G of build artifacts that we don't need anymore
RUN rm -rf .cache/bazel

# Install AWS scripts.
RUN pip install boto3

# Install pygit2.
RUN apt-get install -y wget
RUN rm -rf libgit2-0.27.1
RUN wget -nv https://github.com/libgit2/libgit2/archive/v0.27.1.tar.gz
RUN tar xf v0.27.1.tar.gz
RUN rm -rf v0.27.1.tar.gz
WORKDIR /work/libgit2-0.27.1
RUN cmake . && \
    make && \
    make install
WORKDIR /work
RUN ldconfig
RUN pip install pygit2

#
RUN apt-get install -y gettext-base sudo

RUN apt-get clean

# Install gRPC python libs and generate the python modules to communicate with the codesearch server
RUN pip install grpcio grpcio-tools

RUN mkdir livegrep-grpc
RUN python -m grpc_tools.protoc --python_out=livegrep-grpc --grpc_python_out=livegrep-grpc -I /work/livegrep/src/proto /work/livegrep/src/proto/livegrep.proto

ENV USER mozsearch
ENV HOME /home/${USER}

RUN useradd --uid 1000 -m ${USER}

USER ${USER}
WORKDIR ${HOME}

RUN mkdir -p "/home/mozsearch/.local/lib/python2.7/site-packages"
RUN echo "/work/livegrep-grpc" > "/home/mozsearch/.local/lib/python2.7/site-packages/livegrep.pth"

# Install Rust. We need rust nightly to use the save-analysis
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH=$PATH:/home/mozsearch/.cargo/bin
RUN rustup install nightly
RUN rustup default nightly
RUN rustup uninstall stable

USER root
ADD start.sh /work

ENV SHELL=/bin/bash
