# Maintainer: Henrique Abreu <hgabreu AT gmail.com>

pkgname=meeting-trigger
pkgver=1.0.1
pkgrel=1
pkgdesc="Monitor apps using the mic (on pulseaudio) to trigger automations"
arch=('any')
url="https://github.com/hgabreu/meeting-trigger"
license=('GPL3')
depends=('bash' 'coreutils' 'findutils' 'grep' 'pulseaudio' 'sed' 'run-parts')
source=("${url}/archive/refs/tags/v${pkgver}.tar.gz")
md5sums=("SKIP")

package() {
	cd "${srcdir}/${pkgname}-${pkgver}"
	./install.sh "${pkgdir}"
}
