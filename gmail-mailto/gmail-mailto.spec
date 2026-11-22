# Registers Gmail as a handler for mailto: links, so that GNOME offers it
# under Settings, Apps, Default Apps, Mail. The handler opens Gmail's compose
# window in the default browser. Nothing is compiled.

Name:           gmail-mailto
Version:        1
Release:        1%{?dist}
Summary:        Gmail as the mail app for mailto: links

License:        MIT

Source0:        gmail-mailto
Source1:        gmail-mailto.desktop

BuildArch:      noarch

BuildRequires:  desktop-file-utils
BuildRequires:  python3

Requires:       python3
Requires:       xdg-utils

%description
Lets Gmail handle mailto: links, so that clicking an email address in any
app opens a new message in Gmail, in the default browser, with the address,
subject and body filled in.

To make it the default, choose Gmail under Settings, Apps, Default Apps,
Mail, or run:

    xdg-mime default gmail-mailto.desktop x-scheme-handler/mailto

%prep

%build

%install
install -D -p -m 0755 %{SOURCE0} %{buildroot}%{_bindir}/gmail-mailto
desktop-file-install --dir=%{buildroot}%{_datadir}/applications %{SOURCE1}

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/gmail-mailto.desktop
# The link reaches Gmail encoded, with xdg-open stubbed out to print it
mkdir stub
cat > stub/xdg-open <<'EOF'
#!/bin/sh
echo "$1"
EOF
chmod +x stub/xdg-open
out=$(PATH=$PWD/stub:$PATH %{buildroot}%{_bindir}/gmail-mailto \
    'mailto:a@example.com?subject=Hi there&body=x&y')
test "$out" = 'https://mail.google.com/mail/?extsrc=mailto&url=mailto%%3Aa%%40example.com%%3Fsubject%%3DHi%%20there%%26body%%3Dx%%26y'

%files
%{_bindir}/gmail-mailto
%{_datadir}/applications/gmail-mailto.desktop

%changelog
* Sun Nov 22 2026 Martin Rixham <martin.rixham@gmail.com> - 1-1
- Initial package
