# Used by the distro packages. For a manual install, use install.sh instead.
PREFIX       ?= /usr
BINDIR       ?= $(PREFIX)/bin
LIBEXECDIR   ?= $(PREFIX)/libexec/ak820-dongle-fix
UDEVRULESDIR ?= $(PREFIX)/lib/udev/rules.d
UNITDIR      ?= $(PREFIX)/lib/systemd/system
DESTDIR      ?=

.PHONY: install
install:
	install -Dm755 src/ak820-dongle-keepalive $(DESTDIR)$(LIBEXECDIR)/ak820-dongle-keepalive
	install -Dm644 src/70-ak820-dongle-keepalive.rules $(DESTDIR)$(UDEVRULESDIR)/70-ak820-dongle-keepalive.rules
	install -d $(DESTDIR)$(UNITDIR)
	sed 's#/usr/local/libexec/ak820-dongle-fix#$(LIBEXECDIR)#' src/ak820-dongle-keepalive@.service \
		> $(DESTDIR)$(UNITDIR)/ak820-dongle-keepalive@.service
	chmod 644 $(DESTDIR)$(UNITDIR)/ak820-dongle-keepalive@.service
	install -Dm755 diagnose.sh $(DESTDIR)$(BINDIR)/ak820-dongle-diagnose
