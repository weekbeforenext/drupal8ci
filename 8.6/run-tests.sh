#!/bin/bash
set -e

export PATH=$PATH:~/.composer/vendor/bin;

red=$'\e[1;31m'
grn=$'\e[1;32m'
end=$'\e[0m'
__error=0

if [ -x "$(command -v php)" ]; then
  php -v | grep built
else
  printf "%sPhp missing!%s\\n" "${red}" "${end}"
  __error=1
fi

if [ -x "$(command -v apache2)" ]; then
  apache2 -v | grep version
  a2query -s 000-default
else
  printf "%sApache missing!%s\\n" "${red}" "${end}"
  __error=1
fi

if [ -x "$(command -v mysql)" ]; then
  mysql -V
else
  printf "%sMysql client missing!%s\\n" "${red}" "${end}"
  __error=1
fi

if [ -x "$(command -v robo)" ]; then
  robo -V
else
  printf "%srobo missing!%s\\n" "${red}" "${end}"
  __error=1
fi

if [ -x "$(command -v yarn)" ]; then
  yarn versions | grep 'versions'
else
  printf "%syarn missing!%s\\n" "${red}" "${end}"
  __error=1
fi

if [ -x "$(command -v docker)" ]; then
  docker --version
else
  printf "%sdocker missing!%s\\n" "${red}" "${end}"
  __error=1
fi

if [ -x "$(command -v phpqa)" ]; then
  phpqa tools
else
  printf "%sphpqa missing!%s\\n" "${red}" "${end}"
  __error=1
fi

if [ -x "$(command -v phpcs)" ]; then
  phpcs -i
else
  printf "%phpcs missing!%s\\n" "${red}" "${end}"
  __error=1
fi

if [ $__error = 1 ]; then
  printf "\\n%s[ERROR] Tests failed!%s\\n\\n" "${red}" "${end}"
  exit 1
fi

exit 0