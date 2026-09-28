# Builds rootfs.tar for the linux/arm/v5 image.
# docker build -f buildroot/Dockerfile --output type=local,dest=. buildroot
FROM debian:trixie AS build
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential file wget cpio unzip rsync bc git ca-certificates \
      python3 perl patch bzip2 xz-utils \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m br
USER br
WORKDIR /home/br
ARG BR_VERSION=2026.05.3
# proxy_config.cfg uses the prometheus-exporter service
RUN git clone --depth 1 -b "${BR_VERSION}" https://gitlab.com/buildroot.org/buildroot.git \
 && echo 'HAPROXY_MAKE_OPTS += USE_PROMEX=1' >> buildroot/package/haproxy/haproxy.mk \
 && grep -q -- '-fwrapv' buildroot/package/haproxy/haproxy.mk
COPY --chown=br overlay overlay
COPY --chown=br wa_armv5_defconfig buildroot/configs/
RUN make -C buildroot wa_armv5_defconfig \
 && make -C buildroot

FROM scratch
COPY --from=build /home/br/buildroot/output/images/rootfs.tar /
