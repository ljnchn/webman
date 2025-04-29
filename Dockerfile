ARG PHP_VERSION=8.3
ARG WITH_COMPOSER=true
ARG INSTALL_XDEBUG=false
ARG USE_CN_SOURCE=true

FROM php:${PHP_VERSION}-cli-alpine

# 设置时区
ENV TZ=Asia/Shanghai

# ===== 切换国内镜像源 + 安装依赖 =====
RUN if [ "$USE_CN_SOURCE" = "true" ] ; then \
        sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories ; \
    fi

# 安装基础依赖
RUN apk add --no-cache \
    tzdata \
    git \
    curl \
    wget \
    unzip \
    vim \
    bash \
    grep \
    autoconf \
    g++ \
    make \
    openssl-dev \
    linux-headers \
    libzip-dev libpng-dev libjpeg-turbo-dev libxml2-dev \
    freetype-dev libwebp-dev libevent-dev openssl-dev \
    && cp /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone

# 安装常用扩展依赖
RUN apk add --no-cache \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    oniguruma-dev \
    libxml2-dev \
    icu-dev \
    postgresql-dev \
    libmemcached-dev \
    libssh2-dev \
    libsodium-dev

# 安装常用 PHP 扩展
RUN docker-php-ext-configure gd --with-freetype --with-jpeg  --with-webp\
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    pdo_pgsql \
    mysqli \
    gd \
    bcmath \
    intl \
    opcache \
    zip \
    soap \
    sockets \
    pcntl \
    mbstring \
    exif

# 通过 PECL 安装额外扩展
RUN pecl install redis && docker-php-ext-enable redis; \
    pecl install amqp  && docker-php-ext-enable amqp; \
    pecl install event && docker-php-ext-enable event; \
    pecl install apcu  && docker-php-ext-enable apcu; \
    apk del .build-deps && rm -rf /tmp/pear

# 根据条件安装 Xdebug
RUN if [ "$INSTALL_XDEBUG" = "true" ] ; then \
        pecl install xdebug \
        && docker-php-ext-enable xdebug \
        && echo "xdebug.mode=develop,debug" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
        && echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
        && echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini; \
    fi

# 根据条件安装 Composer
RUN if [ "$WITH_COMPOSER" = "true" ] ; then \
        if [ "$USE_CN_SOURCE" = "true" ] ; then \
            curl -sS https://install.phpcomposer.com/installer | php -- --install-dir=/usr/local/bin --filename=composer ; \
        else \
            curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer ; \
        fi \
    fi

# ===== PHP 运行时配置 =====
RUN echo 'memory_limit=-1' > /usr/local/etc/php/conf.d/memory-limit.ini

# 工作目录
WORKDIR /app
# 拷贝项目代码
COPY . /app

# 端口与健康检查
EXPOSE 8787


# 启动 webman
CMD ["php", "start.php", "start"]
