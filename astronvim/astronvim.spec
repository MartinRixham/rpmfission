# AstroNvim as the system-wide Neovim config. Only the init.lua is packaged:
# lazy.nvim fetches AstroNvim and its plugins per user, on first start, so
# nothing is downloaded or compiled here. The URL is not AstroNvim's GitHub
# repository, so that the update workflow does not compare its releases with
# this Version.

Name:           astronvim
Version:        6
Release:        1%{?dist}
Summary:        AstroNvim as the system-wide Neovim configuration

License:        MIT
URL:            https://astronvim.com

Source0:        astronvim.lua

BuildArch:      noarch

# AstroNvim 6 needs Neovim 0.12, and lazy.nvim clones the plugins with git on
# first start
Requires:       neovim >= 0.12
Requires:       git-core
# The icons
Recommends:     droid-sans-mono-nerd-fonts
# Pickers, and nvim-treesitter compiling parsers
Recommends:     ripgrep
Recommends:     fd-find
Recommends:     tree-sitter-cli
Recommends:     gcc
# The C and C++ language server. The config uses this one rather than
# Mason's, which has no aarch64 build.
Recommends:     clang-tools-extra

# The config was installed by zellij before
Conflicts:      zellij < 0.46.0-4

%description
Installs AstroNvim as the system-wide Neovim configuration, which Neovim uses
for users who have no ~/.config/nvim/init.lua. AstroNvim and its plugins are
installed per user, into ~/.local/share/nvim, on the first start of Neovim,
which needs network access.

Its icons need a Nerd Font in the terminal, such as Droid Sans Mono Nerd Font.

%prep

%build

%install
install -Dpm 0644 %{SOURCE0} %{buildroot}%{_sysconfdir}/xdg/nvim/init.lua

%files
%dir %{_sysconfdir}/xdg/nvim
%config(noreplace) %{_sysconfdir}/xdg/nvim/init.lua

%changelog
* Sun Nov 22 2026 Martin Rixham <martin.rixham@gmail.com> - 6-1
- Initial package, split out of zellij
