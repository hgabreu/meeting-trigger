#!/bin/bash
source PKGBUILD

# get maintainer from PKGBUILD comment and escape bash expansion in checkinstall
maintainer=$(grep -oPm 1 '(?<=Maintainer: ).*$' PKGBUILD|sed 's/[<>]/\\\0/g')

# translate dependencies from Arch to Ubuntu
deps=$(sed 's/pulseaudio/pulseaudio-utils/; s/run-parts/debianutils/; s/ /,/g'  <<<${depends[*]})

checkinstall -Dy --pkgname "$pkgname" --pkgversion "$pkgver" --pkgrelease "$pkgrel" --pkgsource "$url" --maintainer "$maintainer" --provides "$pkgname" --requires "$deps" ./install.sh
