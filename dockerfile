FROM eclipse-temurin:22-jammy AS jauto_build
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates cmake gcc g++ make libc-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
ENV JAUTO_VER=1.0.0
# SHA256 of https://github.com/heshiming/jauto/archive/refs/tags/v1.0.0.tar.gz
# Pin set once after verifying the tarball from a trusted network. Bump if JAUTO_VER changes.
ENV JAUTO_SHA256=c17ecd6574c3f5898b63789dd7755b3d98905aade33502d9f0564b33aabac262
RUN curl --proto '=https' --tlsv1.2 --fail -L \
        https://github.com/heshiming/jauto/archive/refs/tags/v$JAUTO_VER.tar.gz \
        -o /tmp/jauto.tar.gz && \
    echo "$JAUTO_SHA256  /tmp/jauto.tar.gz" | sha256sum -c -
WORKDIR /tmp
RUN tar xfz jauto.tar.gz && \
    mkdir jauto_build && \
    cd jauto_build && \
    cmake ../jauto-$JAUTO_VER && \
    cmake --build .

FROM debian:bookworm-slim AS util_build
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libx11-dev libc-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
ADD utils /tmp/utils
WORKDIR /tmp/utils
RUN gcc show_text.c -O2 -lX11 -o show_text

FROM debian:bookworm-slim
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates sudo ed xvfb x11vnc x11-utils xdotool socat python3-websockify procps xfonts-scalable tzdata && \
    update-ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN useradd -ms /bin/bash -u 2000 ibg && \
    adduser ibg sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
WORKDIR /opt
# SHA256 of https://github.com/novnc/noVNC/archive/refs/tags/v1.3.0.tar.gz
ENV NOVNC_SHA256=ee8f91514c9ce9f4054d132f5f97167ee87d9faa6630379267e569d789290336
RUN curl --proto '=https' --tlsv1.2 --fail -L \
        "https://github.com/novnc/noVNC/archive/refs/tags/v1.3.0.tar.gz" -o novnc.tar.gz && \
    echo "$NOVNC_SHA256  novnc.tar.gz" | sha256sum -c - && \
    tar xfz novnc.tar.gz && \
    rm novnc.tar.gz

# Bake the IB Gateway installer at build time (resolves runtime MITM surface).
# `stable-standalone` is used (rather than `latest-standalone`) so the pinned hash is
# stable for a release window. Bump both URL and SHA together when refreshing.
ARG TARGETARCH
ENV IBG_INSTALLER_SHA256_AMD64=719b7c13c00450a98d62d780427cd6d856fda952cb7028dc5a38a7f40f4b43d3
ENV IBG_INSTALLER_SHA256_ARM64=60930396259ce8e0681c1faa515d38b785171cce0540283d88133de1d8987821
RUN if [ "$TARGETARCH" = "arm64" ]; then \
        URL="https://download2.interactivebrokers.com/installers/ibgateway/stable-standalone/ibgateway-stable-standalone-linux-arm.sh"; \
        SHA="$IBG_INSTALLER_SHA256_ARM64"; \
    else \
        URL="https://download2.interactivebrokers.com/installers/ibgateway/stable-standalone/ibgateway-stable-standalone-linux-x64.sh"; \
        SHA="$IBG_INSTALLER_SHA256_AMD64"; \
    fi && \
    curl --proto '=https' --tlsv1.2 --fail -L "$URL" -o /opt/ibgateway.sh && \
    echo "$SHA  /opt/ibgateway.sh" | sha256sum -c - && \
    chmod +x /opt/ibgateway.sh

USER ibg
WORKDIR /home/ibg
COPY --from=util_build /tmp/utils/show_text /bin
COPY --from=jauto_build /tmp/jauto_build/jauto.so /opt
ADD scripts /opt/ibga/
RUN sudo chmod a+rx /bin/show_text && \
    sudo chmod a+rx /opt/jauto.so && \
    sudo chmod a+rx /opt/ibga/*
EXPOSE 4000/tcp
EXPOSE 5800/tcp
ENTRYPOINT ["/opt/ibga/start.sh"]
