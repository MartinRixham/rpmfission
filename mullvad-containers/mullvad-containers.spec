# A stand-in for the Mozilla VPN client's native messaging host, so that
# Firefox Multi-Account Containers offers Mullvad's SOCKS5 proxies in its
# Mozilla VPN server picker. Mozilla VPN runs on Mullvad's servers, and the
# extension only ever turns a server's socksName into
# socks://<socksName>.mullvad.net:1080, so any Mullvad connection will do,
# such as WireGuard set up in NetworkManager.
#
# The protocol is the extension's (js/background/mozillaVpnBackground.js in
# its 8.x releases): it sends {"t":"status"} and {"t":"servers"}, and reads
# back the VPN state (StateOn/StateOff) and the server list by country and
# city. The shim answers from Mullvad's public relay list, and reports the
# VPN on while Mullvad's in-tunnel proxy, 10.64.0.1:1080, accepts
# connections.
#
# Archful only because the manifest goes in %%{_libdir}; nothing is compiled.

Name:           mullvad-containers
Version:        1
Release:        1%{?dist}
Summary:        Mullvad servers in Firefox Multi-Account Containers

License:        MIT

Source0:        mozillavpn-shim

# Nothing to debug
%global debug_package %{nil}

BuildRequires:  python3

Requires:       python3
# Owns %%{_libdir}/mozilla/native-messaging-hosts, the only system directory
# Fedora's Firefox reads manifests from on 64-bit (not /usr/lib)
Requires:       mozilla-filesystem
# Both install a native messaging host named mozillavpn
Conflicts:      mozilla-vpn
Conflicts:      mozillavpn

%description
Lets Firefox Multi-Account Containers send each container through a
different Mullvad server, picked by country and city in the container's
settings, without the Mozilla VPN client. It stands in for the client's
native messaging host, listing Mullvad's SOCKS5 proxies, which are reachable
while connected to Mullvad by any means, such as WireGuard in
NetworkManager.

In the extension's preferences, allow the native messaging and proxy
permissions, then restart Firefox. The extension still calls the servers
Mozilla VPN's.

%prep

%build

%install
install -D -p -m 0755 %{SOURCE0} \
    %{buildroot}%{_libexecdir}/%{name}/mozillavpn-shim
install -d %{buildroot}%{_libdir}/mozilla/native-messaging-hosts
cat > %{buildroot}%{_libdir}/mozilla/native-messaging-hosts/mozillavpn.json <<EOF
{
  "name": "mozillavpn",
  "description": "Mullvad servers for Multi-Account Containers' Mozilla VPN integration",
  "path": "%{_libexecdir}/%{name}/mozillavpn-shim",
  "type": "stdio",
  "allowed_extensions": ["@testpilot-containers"]
}
EOF

%check
python3 -m json.tool \
    %{buildroot}%{_libdir}/mozilla/native-messaging-hosts/mozillavpn.json > /dev/null
# A status request gets a status reply, framed as native messaging is. With
# no network, as in mock, the VPN is off.
python3 - %{buildroot}%{_libexecdir}/%{name}/mozillavpn-shim <<'EOF'
import json, struct, subprocess, sys
p = subprocess.Popen([sys.executable, "-I", sys.argv[1]],
                     stdin=subprocess.PIPE, stdout=subprocess.PIPE)
req = json.dumps({"t": "status"}).encode()
p.stdin.write(struct.pack("@I", len(req)) + req)
p.stdin.flush()
(n,) = struct.unpack("@I", p.stdout.read(4))
msg = json.loads(p.stdout.read(n))
p.kill()
assert msg["t"] == "status" and msg["status"]["vpn"] in ("StateOn", "StateOff"), msg
EOF

%files
%dir %{_libexecdir}/%{name}
%{_libexecdir}/%{name}/mozillavpn-shim
%{_libdir}/mozilla/native-messaging-hosts/mozillavpn.json

%changelog
* Fri Nov 13 2026 Martin Rixham <martin.rixham@gmail.com> - 1-1
- Initial package
