#!/usr/bin/env bash
set -e

key_unset=false
if [ -z "$DOCUMENTER_KEY" ]; then
  echo '`DOCUMENTER_KEY` is missing'
  key_unset=true
fi

tok_unset=false
if [ -z "$GITHUB_TOKEN" ]; then
  echo '`GITHUB_TOKEN` is missing'
  tok_unset=true
fi

if $key_unset && $tok_unset; then
  echo 'either `GITHUB_TOKEN` or `DOCUMENTER_KEY` must be set for `Documenter` !'
  exit 1
fi

echo '== install system dependencies =='
sudo apt -y update
sudo apt -y install \
  texlive-{latex-{base,extra},binaries,pictures,luatex} \
  ttf-mscorefonts-installer \
  poppler-utils \
  ghostscript-x \
  qtbase5-dev \
  pdf2svg \
  gnuplot \
  g++

echo '== install fonts =='
mkdir -p ~/.fonts
repo="https://github.com/cormullion/juliamono"
ver="$(git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' "$repo.git" | tail -n 1 | awk '{ print $2 }' | sed 's,refs/tags/,,')"
url="$repo/releases/download/$ver/JuliaMono-ttf.tar.gz"
echo "downloading & extract url=$url"
wget -q "$url" -O - | tar -xz -C ~/.fonts
sudo fc-cache -vr
fc-list | grep 'JuliaMono'

echo "== install julia dependencies =="
if true; then
  export JULIA_DEBUG='Documenter,Literate,DemoCards'
  export DOCUMENTER_DEBUG=true  # Democards.jl
fi

export LD_PRELOAD=$(g++ --print-file-name=libstdc++.so)
export GKSwstype=nul  # Plots.jl/issues/3664
export COLORTERM=truecolor  # UnicodePlots.jl
export PLOTDOCS_ANSICOLOR=true
export JULIA_CONDAPKG_BACKEND=MicroMamba

julia='xvfb-run -a julia --color=yes --project=docs'

$julia -e 'using Pkg; Pkg.add(PackageSpec(url="https://github.com/JuliaPlots/Plots.jl", rev=split(ENV["GITHUB_REF"], "/", limit=3)[3], subdir="RecipesBase"));' #FIXME: not needed when registered
$julia -e 'using Pkg; Pkg.add(PackageSpec(url="https://github.com/JuliaPlots/Plots.jl", rev=split(ENV["GITHUB_REF"], "/", limit=3)[3], subdir="RecipesPipeline"));' #FIXME: not needed when registered
$julia -e 'using Pkg; Pkg.add(PackageSpec(url="https://github.com/JuliaPlots/Plots.jl", rev=split(ENV["GITHUB_REF"], "/", limit=3)[3], subdir="PlotsBase"));' #FIXME: not needed when registered
$julia -e '
  using Pkg; Pkg.add("CondaPkg")
  using CondaPkg; CondaPkg.resolve()
  libgcc = if Sys.islinux()
    # see discourse.julialang.org/t/glibcxx-version-not-found/82209/8
    # julia 1.8.3 is built with libstdc++.so.6.0.29, so we must restrict to this version (gcc 11.3.0, not gcc 12.2.0)
    # see gcc.gnu.org/onlinedocs/libstdc++/manual/abi.html
    specs = Dict(
      v"3.4.29" => ">=11.1,<12.1",
      v"3.4.30" => ">=12.1,<13.1",
      v"3.4.31" => ">=13.1,<14.1",
      # ... keep this up-to-date with gcc 14
    )[Base.BinaryPlatforms.detect_libstdcxx_version()]
    ("libgcc-ng$specs", "libstdcxx-ng$specs")
  else
    ()
  end
  CondaPkg.PkgREPL.add([libgcc..., "matplotlib"])
  CondaPkg.status()
'

echo "== build documentation for $GITHUB_REPOSITORY@$GITHUB_REF, triggered by $GITHUB_ACTOR on $GITHUB_EVENT_NAME =="
if [ "$GITHUB_REPOSITORY" == 'JuliaPlots/PlotDocs.jl' ]; then
  $julia -e 'using Pkg; Pkg.add(PackageSpec(name="Plots", rev="master"))'
  $julia docs/make.jl
elif [ "$GITHUB_REPOSITORY" == 'JuliaPlots/Plots.jl' ]; then
  $julia -e 'using Pkg; Pkg.add(PackageSpec(name="Plots", rev=split(ENV["GITHUB_REF"], "/", limit=3)[3])); Pkg.instantiate()'
  $julia docs/make.jl
else
  echo "something is wrong with $GITHUB_REPOSITORY"
  exit 1
fi
