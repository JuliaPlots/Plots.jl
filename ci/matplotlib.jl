using Pkg
Pkg.add("CondaPkg")

using CondaPkg
CondaPkg.resolve()

libgcc = if Sys.islinux()
    # see discourse.julialang.org/t/glibcxx-version-not-found/82209/8
    # julia 1.8.3 is built with libstdc++.so.6.0.29, so we must restrict to this version (gcc 11.3.0, not gcc 12.2.0)
    # see gcc.gnu.org/onlinedocs/libstdc++/manual/abi.html
    specs = Dict(
        v"3.4.29" => ">=11.1,<12.1",
        v"3.4.30" => ">=12.1,<13.1",
        v"3.4.31" => ">=13.1,<14.1",
        v"3.4.32" => ">=14.1,<15.1",
        v"3.4.33" => ">=15.1,<16.1",
        # ... keep this up-to-date with gcc 16
    )[Base.BinaryPlatforms.detect_libstdcxx_version()]
    ("libgcc-ng$specs", "libstdcxx-ng$specs")
else
    ()
end

CondaPkg.PkgREPL.add([libgcc..., "matplotlib"])
CondaPkg.status()
