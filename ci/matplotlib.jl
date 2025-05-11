using Pkg
Pkg.add("CondaPkg")

using CondaPkg
CondaPkg.resolve()

_compatible_libstdcxx_ng_versions = [
    (v"3.4.28", ">=10.1,<11.1"),  # gcc-10
    (v"3.4.29", ">=11.1,<12.1"),  # gcc-11
    (v"3.4.30", ">=12.1,<13.1"),  # gcc-12
    (v"3.4.31", ">=13.1,<14.1"),  # gcc-13
    (v"3.4.32", ">=14.1,<15.1"),  # gcc-14
    (v"3.4.33", ">=15.1,<16.1"),  # gcc-15
    (v"3.4.34", ">=16.1,<17.1"),  # gcc-16
    (v"3.4.35", ">=17.1,<18.1"),  # gcc-17
    (v"3.4.36", ">=18.1,<19.1"),  # gcc-18
    (v"3.4.37", ">=19.1,<20.1"),  # gcc-19
    (v"3.4.38", ">=20.1,<21.1"),  # gcc-20
    (v"3.4.39", ">=21.1,<22.1"),  # gcc-21
    (v"3.4.40", ">=22.1,<23.1"),  # gcc-22
    # ... keep this up-to-date with gcc 23
]

libgcc = if Sys.islinux()
    # see discourse.julialang.org/t/glibcxx-version-not-found/82209/8
    # julia 1.8.3 is built with libstdc++.so.6.0.29, so we must restrict to this version (gcc 11.3.0, not gcc 12.2.0)
    # see gcc.gnu.org/onlinedocs/libstdc++/manual/abi.html
    max_minor_version = maximum(t -> Int(t[1].patch), _compatible_libstdcxx_ng_versions)
    specs = Dict(versions)[Base.BinaryPlatforms.detect_libstdcxx_version(max_minor_version)]
    ("libgcc-ng$specs", "libstdcxx-ng$specs")  
else
    ()
end

CondaPkg.PkgREPL.add([libgcc..., "matplotlib>=3.4"])  # "openssl>=3.4"
CondaPkg.status()
