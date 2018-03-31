FROM alpine:3.7

ENV RUBY_MAJOR 2.3
ENV RUBY_VERSION 2.3.1
ENV BUNDLER_VERSION 1.16.0.pre.3
ENV RUBYGEMS_VERSION 2.6.13
ENV RAILS_VERSION 5.1.3


RUN set -ex \
  \
  && apk add --no-cache --virtual .ruby-builddeps \
    autoconf \
    bison \
    bzip2 \
    bzip2-dev \
    ca-certificates \
    coreutils \
    dpkg-dev dpkg \
    gcc \
    gdbm-dev \
    glib-dev \
    libc-dev \
    libffi-dev \
    openssl \
    openssl-dev \
    libxml2-dev \
    libxslt-dev \
    linux-headers \
    make \
    ncurses-dev \
    procps \
    readline-dev \
    ruby \
    tar \
    xz \
    yaml-dev \
    zlib-dev \
  \
  && wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz" \
  && mkdir -p /usr/src/ruby \
  && tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1 \
  && rm ruby.tar.xz \
  \
  && cd /usr/src/ruby \
  \
# hack in "ENABLE_PATH_CHECK" disabling to suppress:
#   warning: Insecure world writable dir
    && { \
      echo '#define ENABLE_PATH_CHECK 0'; \
      echo; \
      cat file.c; \
    } > file.c.new \
    && mv file.c.new file.c \
    \
    && autoconf \
    && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
# the configure script does not detect isnan/isinf as macros
  && export ac_cv_func_isnan=yes ac_cv_func_isinf=yes \
  && ./configure \
    --build="$gnuArch" \
    --disable-install-doc \
    --enable-shared \
    && make -j "$(nproc)" \
  && make install \
  \
  && runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
      | tr ',' '\n' \
      | sort -u \
      | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
  )" \
  && apk add --virtual .ruby-rundeps $runDeps \
    bzip2 \
    ca-certificates \
    libffi-dev \
    openssl-dev \
    procps \
    yaml-dev \
    zlib-dev \
  && apk del .ruby-builddeps \
  && cd / \
  && rm -r /usr/src/ruby \
  \
  && gem update --system "$RUBYGEMS_VERSION" \
  && gem install bundler --version "$BUNDLER_VERSION" --force \
  && rm -r /root/.gem/

ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
  BUNDLE_BIN="$GEM_HOME/bin" \
  BUNDLE_SILENCE_ROOT_WARNING=1 \
  BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $BUNDLE_BIN:$PATH

RUN apk add --update \
  build-base \
  libxml2-dev \
  libxslt-dev \
  git \
  nodejs \
  ffmpeg \
  ffmpegthumbnailer \
  && rm -rf /var/cache/apk/*

RUN bundle config build.nokogiri --use-system-libraries

RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
  && chmod 777 "$GEM_HOME" "$BUNDLE_BIN"

RUN gem install rails -v $RAILS_VERSION --no-ri --no-rdoc

CMD [ "/bin/sh" ]
