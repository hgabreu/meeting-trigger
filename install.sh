#!/bin/bash
# meeting-trigger installation script
# can take optional 1st parameter as directory to install instead of /

source PKGBUILD

# create "bin" with version from PKGBUILD
sed -e "s/VERSION.*=.*/VERSION='${pkgver}'/g" "${pkgname}.sh" > "${pkgname}"

# install files in proper locations (optionally under dir provided as 1st parameter)
install -Dm 755 "${pkgname}" -t "$1/usr/bin"
install -Dm 644 "${pkgname}.service" -t "$1/usr/lib/systemd/user"

# clean up "bin"
rm "${pkgname}"
