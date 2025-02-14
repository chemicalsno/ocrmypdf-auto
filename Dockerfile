FROM ubuntu:22.04 AS base

FROM base AS builder

ENV LANG=C.UTF-8

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        build-essential \
        ca-certificates \
        curl \
        git \
        libleptonica-dev \
        libtool \
        zlib1g-dev \
    && mkdir /usr/src/jbig2 \
    && cd /usr/src/jbig2 \
    && curl -L https://github.com/agl/jbig2enc/archive/ea6a40a2cbf05efb00f3418f2d0ad71232565beb.tar.gz --output jbig2.tgz \
    && tar xzf jbig2.tgz --strip-components=1 \
    && ./autogen.sh \
    && ./configure \
    && make \
    && make install

RUN git clone https://github.com/ImageMagick/ImageMagick.git /usr/src/ImageMagick \
    && cd /usr/src/ImageMagick \
    && git checkout $(git tag --sort=-v:refname | head -n 1) \
    && ./configure --enable-shared \
    && make -j$(nproc) \
    && make install \
    && ldconfig

FROM base AS final

ENV LANG=C.UTF-8

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ghostscript \
        gosu \
        liblept5 \
        pngquant \
        python3-venv \
        python3-pip \
        qpdf \
        tesseract-ocr \
        tesseract-ocr-eng \
        tesseract-ocr-osd \
        unpaper \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv --system-site-packages /appenv \
    && . /appenv/bin/activate \
    && pip install --upgrade pip \
    && pip install --no-cache-dir \
        plumbum==1.9.0 \
        ocrmypdf==16.9.0 \
        watchdog==6.0.0 \
        requests==2.32.3

COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /usr/local/lib/ /usr/local/lib/

COPY src/ /app/

RUN groupadd -g 1000 docker && \
    useradd -u 1000 -g docker -N --home-dir /app docker && \
    mkdir /config /input /output /ocrtemp /archive && \
    chown -Rh docker:docker /app /config /input /output /ocrtemp /archive && \
    chmod 755 /app/docker-entrypoint.sh

VOLUME ["/config", "/input", "/output", "/ocrtemp", "/archive"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
