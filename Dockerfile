# syntax=docker/dockerfile:1.4

ARG FROM
FROM ${FROM}

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/var/lib/openstack/bin:$PATH

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
    python3-six \
    sudo \
    ubuntu-cloud-keyring
  apt-get clean
  rm -rf /var/lib/apt/lists/*
EOF

# Install Kuberentes repository
ADD --chmod=644 https://packages.cloud.google.com/apt/doc/apt-key.gpg /usr/share/keyrings/kubernetes-archive-keyring.gpg
COPY <<EOF /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Build the run-time image
ONBUILD ARG RELEASE
ONBUILD RUN <<EOF /bin/bash
  set -xe
  if [ "$(lsb_release -sc)" = "focal" ]; then
    if [[ "${RELEASE}" = "wallaby" || "${RELEASE}" = "xena" || "${RELEASE}" = "yoga" ]]; then
      echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu $(lsb_release -sc)-updates/${RELEASE} main" > /etc/apt/sources.list.d/cloudarchive.list
    else
      echo "${RELEASE} is not supported on $(lsb_release -sc)"
      exit 1
    fi
  elif [ "$(lsb_release -sc)" = "jammy" ]; then
    if [[ "${RELEASE}" = "yoga" ]]; then
      # NOTE(mnaser): Yoga shipped with 22.04, so no need to add an extra repository.
      echo "" > /etc/apt/sources.list.d/cloudarchive.list
    elif [[ "${RELEASE}" = "zed" ]]; then
      echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu $(lsb_release -sc)-updates/${RELEASE} main" > /etc/apt/sources.list.d/cloudarchive.list
    else
      echo "${RELEASE} is not supported on $(lsb_release -sc)"
      exit 1
    fi
  else
    echo "Unable to detect correct Ubuntu Cloud Archive repository for $(lsb_release -sc)"
    exit 1
  fi
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
