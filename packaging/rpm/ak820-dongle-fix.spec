Name:           ak820-dongle-fix
Version:        1.0.0
Release:        1%{?dist}
Summary:        Keep the Ajazz AK820 Pro 2.4G receiver working after keyboard sleep
License:        MIT
URL:            https://github.com/druby-luke/ak820-dongle-linux-fix
Source0:        %{url}/archive/v%{version}/ak820-dongle-linux-fix-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  make
BuildRequires:  systemd-rpm-macros
Requires:       systemd-udev
Requires:       coreutils

%description
The Ajazz AK820 Pro 2.4G receiver (SONiX 0c45:fdfd "2.4G Dongle") stops
working on Linux after the keyboard has slept, because nothing reads its two
vendor HID interfaces. This package adds a udev rule and a sandboxed systemd
service that keep those interfaces polled, the way Windows does.

%prep
%autosetup -n ak820-dongle-linux-fix-%{version}

%build
# Nothing to build: shell script, udev rule and systemd unit.

%install
%make_install LIBEXECDIR=%{_libexecdir}/%{name} UDEVRULESDIR=%{_udevrulesdir} UNITDIR=%{_unitdir} BINDIR=%{_bindir}

%post
systemctl daemon-reload >/dev/null 2>&1 || :
udevadm control --reload >/dev/null 2>&1 || :
if [ $1 -gt 1 ]; then
    systemctl try-restart 'ak820-dongle-keepalive@*.service' >/dev/null 2>&1 || :
fi
%{_libexecdir}/%{name}/ak820-dongle-keepalive trigger >/dev/null 2>&1 || :
if [ -e /etc/udev/rules.d/70-ak820-dongle-keepalive.rules ]; then
    echo "ak820-dongle-fix: an older manual install exists in /etc; remove it with the repo's uninstall.sh"
fi

%preun
if [ $1 -eq 0 ]; then
    systemctl stop 'ak820-dongle-keepalive@*.service' >/dev/null 2>&1 || :
fi

%postun
systemctl daemon-reload >/dev/null 2>&1 || :
udevadm control --reload >/dev/null 2>&1 || :

%files
%license LICENSE
%doc README.md
%{_bindir}/ak820-dongle-diagnose
%{_libexecdir}/%{name}/
%{_udevrulesdir}/70-ak820-dongle-keepalive.rules
%{_unitdir}/ak820-dongle-keepalive@.service

%changelog
* Fri Nov 27 2026 Luke <11366524+druby-luke@users.noreply.github.com> - 1.0.0-1
- First packaged release
