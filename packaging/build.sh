#!/bin/sh
# Build the .rpm, .deb and Arch packages in clean containers.
#   packaging/build.sh [rpm] [deb] [arch]     (default: all three)
# Output: dist/. Needs podman or docker. Used by the release workflow too.
set -eu
cd "$(dirname "$0")/.."

V=$(cat VERSION)
grep -q "^Version: *$V\$" packaging/rpm/ak820-dongle-fix.spec || { echo "spec Version != $V" >&2; exit 1; }
grep -q "^pkgver=$V\$" packaging/arch/PKGBUILD || { echo "PKGBUILD pkgver != $V" >&2; exit 1; }

RT=$(command -v podman || command -v docker) || { echo "need podman or docker" >&2; exit 1; }
TARGETS=${*:-rpm deb arch}
NAME=ak820-dongle-linux-fix-$V

rm -rf dist && mkdir -p dist/work
# Source tarball from the tracked + new (not ignored) files, like a release tarball.
git ls-files -co --exclude-standard | grep -v '^dist/' |
	tar -czf "dist/work/$NAME.tar.gz" --transform "s#^#$NAME/#" -T -
cp -r packaging dist/work/
WORK=$(pwd)/dist/work

run() { "$RT" run --rm -v "$WORK:/w:Z" -e V="$V" -e NAME="$NAME" "$1" sh -euc "$2"; }

for t in $TARGETS; do
	echo "=== $t"
	case $t in
	rpm) run registry.fedoraproject.org/fedora:latest '
		dnf -y -q install rpm-build systemd-rpm-macros make >/dev/null
		mkdir -p ~/rpmbuild/SOURCES && cp /w/$NAME.tar.gz ~/rpmbuild/SOURCES/
		rpmbuild -ba --quiet /w/packaging/rpm/ak820-dongle-fix.spec
		cp ~/rpmbuild/RPMS/noarch/*.rpm ~/rpmbuild/SRPMS/*.rpm /w/' ;;
	deb) run docker.io/library/debian:stable-slim '
		apt-get -qq update && apt-get -qq install -y make >/dev/null
		cd /tmp && tar -xzf /w/$NAME.tar.gz && cd $NAME
		make DESTDIR=/tmp/root install
		install -Dm644 LICENSE /tmp/root/usr/share/doc/ak820-dongle-fix/copyright
		install -Dm644 README.md /tmp/root/usr/share/doc/ak820-dongle-fix/README.md
		sed -e "s/@VERSION@/$V/" -e "s/@DATE@/$(date -uR -d @$(stat -c %Y /w/$NAME.tar.gz))/" /w/packaging/deb/changelog |
			gzip -9n >/tmp/root/usr/share/doc/ak820-dongle-fix/changelog.Debian.gz
		mkdir -p /tmp/root/DEBIAN
		sed "s/@VERSION@/$V/" /w/packaging/deb/control >/tmp/root/DEBIAN/control
		for s in postinst prerm postrm; do install -m755 /w/packaging/deb/$s /tmp/root/DEBIAN/; done
		dpkg-deb --root-owner-group -Zxz --build /tmp/root /w/ak820-dongle-fix_${V}-1_all.deb' ;;
	arch) run docker.io/library/archlinux:latest '
		pacman -Syu --noconfirm --needed base-devel >/dev/null
		useradd -m builder
		mkdir /tmp/b && cp /w/packaging/arch/* /w/$NAME.tar.gz /tmp/b/ && chown -R builder /tmp/b
		su builder -c "cd /tmp/b && makepkg -f --noconfirm"
		cp /tmp/b/*.pkg.tar.zst /w/' ;;
	*) echo "unknown target $t" >&2; exit 2 ;;
	esac
done

mv dist/work/*.rpm dist/work/*.deb dist/work/*.pkg.tar.zst dist/ 2>/dev/null || true
rm -rf dist/work
(cd dist && sha256sum -- * > SHA256SUMS)
ls -l dist
