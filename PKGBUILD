# Maintainer: Henrique Abreu <hgabreu AT gmail.com>

pkgname=meeting-trigger
pkgver=0.0.1
pkgrel=1
pkgdesc="Monitor apps using the Mic (on pulseaudio) to trigger automations"
arch=('any')
url="https://github.com/hgabreu/meeting-trigger"
license=('GPL3')
depends=('bash' 'coreutils' 'findutils' 'grep' 'pulseaudio' 'sed' 'run-parts')
#source=("$pkgname::git+${url}.git#branch=main")
source=("local://$pkgname" "local://$pkgname.service")
md5sums=("SKIP" "SKIP")

build () {
	#cd "${srcdir}/${pkgname}" || exit 2
	cd "${srcdir}"
	sed -i -e "s/VERSION.*=.*/VERSION='${pkgver}'/g" "${pkgname}"
}

package() {
	#cd "${srcdir}/${pkgname}" || exit 2
	cd "${srcdir}"

	mkdir -p "${pkgdir}/usr/bin"
	cp ${pkgname} "${pkgdir}/usr/bin"
	chmod u=rwx,go=rx "${pkgdir}/usr/bin/${pkgname}"

	mkdir -p "${pkgdir}/usr/lib/systemd/user"
	cp ${pkgname}.service "${pkgdir}/usr/lib/systemd/user"
	chmod u=rw,go=r "${pkgdir}/usr/lib/systemd/user//${pkgname}.service"
}
