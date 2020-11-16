# Borrowed from https://github.com/boot2docker/boot2docker/blob/17.03.x/Dockerfile#L222-L255
FROM debian:stable-slim

RUN set -eux; \
        apt-get update; \
        apt-get -y install \
                automake \
                make \
                build-essential \
                curl \
                gcc \
                unzip \
        ; \
        rm -rf /var/lib/apt/lists/*

ENV ROOTFS /rootfs

RUN mkdir -p $ROOTFS

# Install build dependencies for VMware Tools
RUN apt-get update && apt-get install -y \
        autoconf \
        libdumbnet-dev \
        libdumbnet1 \
        libfuse-dev \
        libfuse2 \
        libglib2.0-0 \
        libglib2.0-dev \
        libmspack-dev \
        libssl-dev \
        libtirpc-dev \
        libtirpc1 \
        libtool \
    && rm -rf /var/lib/apt/lists/*

# Build VMware Tools
ENV OVT_VERSION stable-10.3.10

RUN curl --retry 10 -fsSL "https://github.com/vmware/open-vm-tools/archive/${OVT_VERSION}.tar.gz" | tar -xz --strip-components=1 -C /

# Compile user space components, we're no longer building kernel module as we're
# now bundling FUSE shared folders support.
RUN cd /open-vm-tools && \
    autoreconf -i && \
    ./configure --disable-multimon --disable-docs --disable-tests --with-gnu-ld \
                --without-kernel-modules --without-procps --without-gtk2 \
                --without-gtkmm --without-pam --without-x --without-icu \
                --without-xerces --without-xmlsecurity --without-ssl && \
    make LIBS="-ltirpc" CFLAGS="-Wno-implicit-function-declaration" && \
    make DESTDIR=$ROOTFS install &&\
    /open-vm-tools/libtool --finish $ROOTFS/usr/local/lib

# Building the Libdnet library for VMware Tools.
ENV LIBDNET libdnet-1.12
RUN curl -fL -o /tmp/${LIBDNET}.zip https://github.com/dugsong/libdnet/archive/${LIBDNET}.zip && \
    unzip /tmp/${LIBDNET}.zip -d /vmtoolsd && \
    cd /vmtoolsd/libdnet-${LIBDNET} && ./configure --build=i486-pc-linux-gnu && \
    make && \
    make install && make DESTDIR=$ROOTFS install

# Horrible hack again
RUN ln -sT libdnet.1 "$ROOTFS/usr/local/lib/libdumbnet.so.1" \
	&& readlink -f "$ROOTFS/usr/local/lib/libdumbnet.so.1"

# TCL 7 doesn't ship with libtirpc.so.1 Dummy it up so the VMware tools work again, taken from:
# https://github.com/boot2docker/boot2docker/issues/1157#issuecomment-211647607
RUN ln -sT libtirpc.so "$ROOTFS/usr/local/lib/libtirpc.so.1" \
	&& readlink -f "$ROOTFS/usr/local/lib/libtirpc.so.1"

# verify that all the above actually worked (at least producing a valid binary, so we don't repeat issue #1157)
RUN LD_LIBRARY_PATH='/lib:/usr/local/lib:/rootfs/usr/local/lib'

ENTRYPOINT ["sleep", "3600"]
