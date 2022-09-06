# syntax=docker/dockerfile:1.4

ARG FROM
FROM ${FROM}

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/var/lib/openstack/bin:$PATH

# Install Kuberentes repository
ARG BUILDOS
ARG BUILDARCH
ARG KUBECTL_VERSION=v1.25.0
ADD --chmod=755 https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${BUILDOS}/${BUILDARCH}/kubectl /usr/local/bin/kubectl

# Install run-time dependencies
RUN <<EOF bash -xe
  apt-get update
  apt-get install -y --no-install-recommends \
    ca-certificates \
    libpython3.8 \
    lsb-release \
    netbase \
    python3 \
    python3-distutils \
    sudo \
    ubuntu-cloud-keyring
  apt-get clean
  rm -rf /var/lib/apt/lists/*
EOF

# Build the run-time image
ONBUILD ARG RELEASE
ONBUILD RUN <<EOF
  echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu $(lsb_release -sc)-updates/${RELEASE} main" \
    > /etc/apt/sources.list.d/cloudarchive-${RELEASE}.list
EOF
ONBUILD ARG PROJECT
ONBUILD RUN <<EOF
  groupadd -g 42424 ${PROJECT}
  useradd -u 42424 -g 42424 -M -d /var/lib/${PROJECT} -s /usr/sbin/nologin -c "${PROJECT} User" ${PROJECT}
  mkdir -p /etc/${PROJECT} /var/log/${PROJECT} /var/lib/${PROJECT} /var/cache/${PROJECT}
  chown -Rv ${PROJECT}:${PROJECT} /etc/${PROJECT} /var/log/${PROJECT} /var/lib/${PROJECT} /var/cache/${PROJECT}
EOF
ONBUILD COPY --from=bindep --link /runtime-dist-packages /runtime-dist-packages
ONBUILD ARG DIST_PACKAGES=""
ONBUILD RUN <<EOF
  apt-get update
  apt-get install -y --no-install-recommends $(cat /runtime-dist-packages) ${DIST_PACKAGES} ;\
  apt-get clean ;\
  rm -rf /var/lib/apt/lists/*
EOF
ONBUILD COPY --from=builder --link /var/lib/openstack /var/lib/openstack
