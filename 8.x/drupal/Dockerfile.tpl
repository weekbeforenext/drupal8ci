# https://hub.docker.com/r/juampynr/drupal8ci/~/dockerfile/
# https://github.com/docker-library/drupal/blob/master/$DRUPAL_TAG/apache/Dockerfile
FROM drupal:$DRUPAL_TAG-apache

LABEL maintainer="dev-drupal.com"

# Install composer.
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Install needed programs for next steps.
RUN apt-get update && apt-get install --no-install-recommends -y \
  apt-transport-https \
  gnupg2 \
  software-properties-common \
  sudo \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Nodejs, Yarn, programs for next steps and php extensions.
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - \
  && curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
  && apt-get update && apt-get install --no-install-recommends -y \
  nodejs \
  yarn \
  chromium \
  imagemagick \
  libmagickwand-dev \
  libnss3-dev \
  libxslt-dev \
  mariadb-client \
  jq \
  shellcheck \
  git \
  unzip \
  && curl -fsSL https://github.com/mikefarah/yq/releases/download/2.4.0/yq_linux_amd64 -o /usr/local/bin/yq \
  && chmod +x /usr/local/bin/yq \
  # Install xsl, mysqli, xdebug, imagick.
  && docker-php-ext-install xsl mysqli \
  && pecl install imagick xdebug \
  && docker-php-ext-enable imagick xdebug \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir /var/www/.composer /var/www/.node \
  && chmod 777 /var/www

WORKDIR /var/www/.composer

# Put a turbo on composer, install phpqa + tools + Robo + Coder.
# Install Drupal dev third party and upgrade Php-unit.
COPY composer.json /var/www/.composer/composer.json
RUN composer install --no-ansi -n --profile --no-suggest \
  && ln -sf /var/www/.composer/vendor/bin/* /usr/local/bin \
  && mkdir -p /var/www/html/vendor/bin/ \
  && ln -sf /var/www/.composer/vendor/bin/* /var/www/html/vendor/bin/ \
  && composer clear-cache \
  && rm -rf /var/www/.composer/cache/*

# [TEMPORARY] Patch nightwatch for upgrade and profile install support.
WORKDIR /var/www/html/

RUN curl -fsSL https://www.drupal.org/files/issues/2019-07-02/3059356-12-nightwatch-upgrade.patch -o 3059356-12-nightwatch-upgrade.patch \
  && patch -p1 < 3059356-12-nightwatch-upgrade.patch \
  # Patch for Nightwatch to install Drupal with a profile.
  && curl -fsSL https://www.drupal.org/files/issues/2019-02-05/3017176-7.patch -o 3017176-7.patch \
  && patch -p1 < 3017176-7.patch \
  && rm -f 3059356-12-nightwatch-upgrade.patch \
  && rm -f 3017176-7.patch

COPY nightwatch.conf.js /var/www/html/core/nightwatch.conf.js

# Add Drupal 8 Node tools / linters / Sass / Nightwatch.
WORKDIR /var/www/.node

RUN cp /var/www/html/core/package.json /var/www/.node \
  && npm install --no-audit \
  && npm install --no-audit git://github.com/sasstools/sass-lint.git#develop \
  && yarn install \
  && ln -s /var/www/.node/node_modules/.bin/* /usr/local/bin \
  && ln -s /var/www/.node/node_modules /var/www/html/core/node_modules \
  && npm cache clean --force \
  && rm -rf /tmp/*

COPY run-tests.sh /scripts/run-tests.sh
COPY start-chrome.sh /scripts/start-chrome.sh
RUN chmod +x /scripts/*.sh

# Remove Apache logs to stdout from the php image (used by Drupal inage).
RUN rm -f /var/log/apache2/access.log \
  && chown -R www-data:www-data /var/www/.composer /var/www/.node

# Fix Php performances.
RUN mv /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini \
  && sed -i "s#memory_limit = 128M#memory_limit = 512M#g" /usr/local/etc/php/php.ini \
  && sed -i "s#max_execution_time = 30#max_execution_time = 90#g" /usr/local/etc/php/php.ini \
  && sed -i "s#;max_input_nesting_level = 64#max_input_nesting_level = 512#g" /usr/local/etc/php/php.ini

#### Specific part for the included Drupal 8 code in this image.
COPY .env.nightwatch /var/www/html/core/.env

WORKDIR /var/www/html

# Install Drupal dev and PHP 7 update for PHPunit, see
# https://github.com/drupal/drupal/blob/8.7.x/composer.json#L56
RUN composer run-script drupal-phpunit-upgrade --no-ansi \
  && composer clear-cache \
  && npm cache clean --force \
  && rm -rf /tmp/*
