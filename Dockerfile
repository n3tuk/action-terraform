FROM dhi.io/alpine-base:3.24-alpine3.24-dev

LABEL org.opencontainers.image.title="action-terraform"

# NOTE: Allow the package versions to be the latest as this is a build environment and we want the latest to always be
#       used for security and bug fixes.

# hadolint ignore=DL3018
RUN apk add --no-cache --update \
    bash \
    ca-certificates \
    coreutils \
    curl \
    git \
    grep \
    jq \
    tar

ENV TFSWITCH_VERSION=1.19.0
ENV TFSWITCH_SHA256=f1502b83f35ddce7f5bb25a2a2ca3fa4c56930e5f8f7a423cea0bdef384fb61b
ENV TFSWITCH_URL=https://github.com/warrensbox/terraform-switcher/releases/download/v${TFSWITCH_VERSION}/terraform-switcher_v${TFSWITCH_VERSION}_linux_amd64.tar.gz

# NOTE: Due to the way HashiCorp have rotated their GPG key used to sign releases, many utilities, including tfswitch,
#       are failing the verify the signatures and the download. Therefore we must manually install a custom copy of the
#       key with the expired version of the key removed.
#       See:
#         https://github.com/warrensbox/terraform-switcher/issues/746
#         https://github.com/hashicorp/terraform/issues/38404#issuecomment-4280202105
RUN mkdir -p /usr/cache/tfswitch/.terraform.versions
COPY assets/terraform.asc /usr/cache/tfswitch/.terraform.versions/terraform_72D7468F.asc

RUN curl --silent --remote-name --location ${TFSWITCH_URL} && \
    echo "${TFSWITCH_SHA256} terraform-switcher_v${TFSWITCH_VERSION}_linux_amd64.tar.gz" | sha256sum -c - && \
    tar xzf terraform-switcher_v${TFSWITCH_VERSION}_linux_amd64.tar.gz -C /usr/bin/ tfswitch && \
    mv /usr/bin/tfswitch /usr/bin/tfswitch_${TFSWITCH_VERSION} && \
    chmod 755 /usr/bin/tfswitch_${TFSWITCH_VERSION} && \
    ln -sf /usr/bin/tfswitch_${TFSWITCH_VERSION} /usr/bin/tfswitch && \
    rm terraform-switcher_v${TFSWITCH_VERSION}_linux_amd64.tar.gz && \
    mkdir -p /usr/cache/tfswitch && \
    tfswitch --install=/usr/cache/tfswitch --bin=/usr/bin/terraform --latest

ENV TFLINT_VERSION=0.64.0
ENV TFLINT_SHA256=cca9d13e2e1d7a2c627af60ff899a3c9b74212899416aeb96ec764d2ef954537
ENV TFLINT_URL=https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip

RUN curl --silent --remote-name --location ${TFLINT_URL} && \
    echo "${TFLINT_SHA256} tflint_linux_amd64.zip" | sha256sum -c - && \
    unzip tflint_linux_amd64.zip -d /usr/bin/ tflint && \
    mv /usr/bin/tflint /usr/bin/tflint_${TFLINT_VERSION} && \
    chmod 755 /usr/bin/tflint_${TFLINT_VERSION} && \
    ln -sf /usr/bin/tflint_${TFLINT_VERSION} /usr/bin/tflint

ENV HCLEDIT_VERSION=0.2.18
ENV HCLEDIT_SHA256=5974db4486a7e7ecbcbce8b96cb77051419575858d0fc97d73af536b18baabe7
ENV HCLEDIT_URL=https://github.com/minamijoyo/hcledit/releases/download/v${HCLEDIT_VERSION}/hcledit_${HCLEDIT_VERSION}_linux_amd64.tar.gz

RUN curl --silent --remote-name --location ${HCLEDIT_URL} && \
    echo "${HCLEDIT_SHA256} hcledit_${HCLEDIT_VERSION}_linux_amd64.tar.gz" | sha256sum -c - && \
    tar xzf hcledit_${HCLEDIT_VERSION}_linux_amd64.tar.gz -C /usr/bin/ hcledit && \
    mv /usr/bin/hcledit /usr/bin/hcledit_${HCLEDIT_VERSION} && \
    chmod 755 /usr/bin/hcledit_${HCLEDIT_VERSION} && \
    ln -sf /usr/bin/hcledit_${HCLEDIT_VERSION} /usr/bin/hcledit && \
    rm hcledit_${HCLEDIT_VERSION}_linux_amd64.tar.gz && \
    mkdir -p /usr/cache/tfswitch && \
    tfswitch --log-level=WARN --install=/usr/cache/tfswitch --bin=/usr/bin/terraform --latest

ENV GOMPLATE_VERSION=5.2.0
ENV GOMPLATE_SHA256=a235564c12f12e755c06e3ab2af414ab1e3f5b1f142eb82ea2d8086145670a81
ENV GOMPLATE_URL=https://github.com/hairyhenderson/gomplate/releases/download/v${GOMPLATE_VERSION}/gomplate_linux-amd64

RUN curl --silent --remote-name --location ${GOMPLATE_URL} && \
    echo "${GOMPLATE_SHA256} gomplate_linux-amd64" | sha256sum -c - && \
    mv gomplate_linux-amd64 /usr/bin/gomplate_${GOMPLATE_VERSION} && \
    chmod 755 /usr/bin/gomplate_${GOMPLATE_VERSION} && \
    ln -sf /usr/bin/gomplate_${GOMPLATE_VERSION} /usr/bin/gomplate

ENV TASK_VERSION=3.52.0
ENV TASK_SHA256=02c679ffae53dca791804847d78b31731615894e292948397c971c87ac9e95bd
ENV TASK_URL=https://github.com/go-task/task/releases/download/v${TASK_VERSION}/task_linux_amd64.tar.gz

RUN curl --silent --remote-name --location ${TASK_URL} && \
    echo "${TASK_SHA256} task_linux_amd64.tar.gz" | sha256sum -c - && \
    tar xzf task_linux_amd64.tar.gz -C /usr/bin/ task && \
    mv /usr/bin/task /usr/bin/task_${TASK_VERSION} && \
    chmod 755 /usr/bin/task_${TASK_VERSION} && \
    ln -sf /usr/bin/task_${TASK_VERSION} /usr/bin/task

# Remove curl (its no longer required after downloading these applications) as we want to minimize the attack surface of
# the image by removing unnecessary packages.
RUN apk del --no-cache curl

# NOTE: All GitHub Actions are expected to run as the root user during normal operation, so creating and using non-root
#       users can risk breaking the actions, especially where files or directories are created and owned by the root
#       user. Therefore, we will not create a non-root user in this image.
WORKDIR /data

COPY scripts /data/scripts
ENTRYPOINT ["/data/scripts/bin/run"]
