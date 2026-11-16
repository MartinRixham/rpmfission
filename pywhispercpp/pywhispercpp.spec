# Fedora's pywhispercpp, built against the whisper package's whisper.cpp
# instead of a bundled copy, so that it runs on the GPU through Vulkan. It
# replaces Fedora's python3-pywhispercpp, which bundles a CPU-only
# whisper.cpp tuned for the build machine's CPU (GGML_NATIVE).
#
# The sdist bundles whisper.cpp and pybind11 as git submodules; both are
# removed, except a small test model for the tests.

%global pypi_name pywhispercpp

# whisper's libraries are private and provide no sonames: require the package
%global __requires_exclude ^lib(whisper|ggml|ggml-base)\\.so.*$
# pip builds the extension in a temporary directory, from which no debug
# sources are collected
%undefine _debugsource_packages

Name:           %{pypi_name}
Version:        1.5.1
Release:        1%{?dist}
Summary:        Python bindings for whisper.cpp, accelerated with Vulkan

License:        MIT
URL:            https://github.com/absadiki/pywhispercpp
Source0:        https://files.pythonhosted.org/packages/source/p/%{pypi_name}/%{pypi_name}-%{version}.tar.gz

# Build against the installed whisper.cpp and pybind11 rather than the git
# submodules, with an RPATH to whisper's private library directory
Patch0:         pywhispercpp-system-whisper.patch
# Load the ggml backends, which the whisper package builds as modules
Patch1:         pywhispercpp-load-backends.patch

# As the whisper package
ExclusiveArch:  x86_64 aarch64

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  pybind11-devel
BuildRequires:  python3-devel
BuildRequires:  python3-pytest
BuildRequires:  whisper-devel

%description
pywhispercpp provides Python bindings for whisper.cpp with a simple Pythonic
API on top of it. This build uses the whisper package's whisper.cpp, which
runs on the GPU through Vulkan where there is a Vulkan driver.

%package -n     python3-%{pypi_name}
Summary:        %{summary}
# The binding is built against whisper.cpp's headers, whose API only grows
# (rpm -q prints "not installed" on stdout, so its output is kept only when
# it succeeds; whisper-devel is absent when the SRPM is built)
Requires:       whisper%{?_isa} >= %(rpm -q --qf '%%{version}' whisper-devel 2>/dev/null > /dev/null && rpm -q --qf '%%{version}' whisper-devel || echo 0)

%description -n python3-%{pypi_name}
pywhispercpp provides Python bindings for whisper.cpp with a simple Pythonic
API on top of it. This build uses the whisper package's whisper.cpp, which
runs on the GPU through Vulkan where there is a Vulkan driver.

%prep
%autosetup -p1 -n %{pypi_name}-%{version}
mv whisper.cpp/models/for-tests-ggml-tiny.en.bin tests/
rm -r whisper.cpp pybind11
sed -i 's|\./whisper\.cpp/models/|./tests/|' tests/test_c_api.py
# repairwheel bundles libraries into the wheel; it is not packaged, and not
# wanted
sed -i '/"repairwheel",/d' pyproject.toml
# The examples' shebangs
find pywhispercpp -name '*.py' -exec sed -i '/^#!/d' {} +

%generate_buildrequires
%pyproject_buildrequires

%build
# setup.py passes CMAKE_ARGS on to CMake
export CMAKE_ARGS="-Dwhisper_DIR=%{_libdir}/whisper/cmake/whisper"
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files -l %{pypi_name} _pywhispercpp
# setuptools-scm's version file, installed at the top of site-packages
rm -f %{buildroot}%{python3_sitearch}/_version.py \
    %{buildroot}%{python3_sitearch}/__pycache__/_version.*
# Example programs needing modules Fedora does not package (python-ffmpeg),
# or PyQt5, which would pull Qt 5 into every install
rm %{buildroot}%{_bindir}/pwcpp-{assistant,gui,livestream,recording}

%check
%pyproject_check_import -e 'pywhispercpp.examples*'
# The other tests download models
%pytest -v tests/test_c_api.py

%files -n python3-%{pypi_name} -f %{pyproject_files}
%doc README.md
%{_bindir}/pwcpp

%changelog
* Mon Nov 16 2026 Martin Rixham <martin.rixham@gmail.com> - 1.5.1-1
- Initial package
