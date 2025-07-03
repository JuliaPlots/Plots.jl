using Pkg
Pkg.add("CondaPkg")

using CondaPkg
CondaPkg.resolve()

# table adapted from `4. Symbol versioning on the libstdc++.so binary` in
# gcc.gnu.org/onlinedocs/libstdc++/manual/abi.html
# see also github.com/gcc-mirror/gcc/blob/master/libstdc%2B%2B-v3/config/abi/pre/gnu.ver
_compatible_libstdcxx_ng_versions = [
    (v"3.4.34", (">=15.1", "<16.1")),  # NOTE: hypothetical upper bound
    (v"3.4.33", (">=14.1", "<15.1")),
    (v"3.4.32", (">=13.2", "<14.1")),
    (v"3.4.31", (">=13.1", "<13.2")),
    (v"3.4.30", (">=12.1", "<13.1")),
    (v"3.4.29", (">=11.1", "<12.1")),
    (v"3.4.28", (">=9.3", "<11.1")),
    (v"3.4.27", (">=9.2", "<9.3")),
    (v"3.4.26", (">=9.1", "<9.2")),
    (v"3.4.25", (">=8.1", "<9.1")),
    (v"3.4.24", (">=7.2", "<8.1")),
    (v"3.4.23", (">=7.1", "<7.2")),
    (v"3.4.22", (">=6.1", "<7.1")),
    (v"3.4.21", (">=5.1", "<6.1")),
    (v"3.4.20", (">=4.9", "<5.1")),
    (v"3.4.19", (">=4.8.3", "<4.9")),
]
libgcc = if Sys.islinux()
    # see discourse.julialang.org/t/glibcxx-version-not-found/82209/8
    # julia 1.8.3 is built with libstdc++.so.6.0.29, so we must restrict to this version (gcc 11.3.0, not gcc 12.2.0)
    versions = Dict(_compatible_libstdcxx_ng_versions)
    lo, hi = extrema(keys(versions))
    _, ub = versions[Base.BinaryPlatforms.detect_libstdcxx_version(Int(hi.patch))]
    specs = ">=$(VersionNumber(lo.major, lo.minor)),$ub"
    ("libgcc-ng$specs", "libstdcxx-ng$specs")
else
    ()
end

CondaPkg.PkgREPL.add([libgcc..., "matplotlib>=3.4"])  # "openssl>=3.4"
CondaPkg.status()
