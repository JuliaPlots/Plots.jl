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

if true; then
  export JULIA_DEBUG='Documenter,Literate,DemoCards'
  export DOCUMENTER_DEBUG=true  # Democards.jl
fi

export LD_PRELOAD=$(g++ --print-file-name=libstdc++.so)
export GKSwstype=nul  # Plots.jl/issues/3664
export MPLBACKEND=agg
export COLORTERM=truecolor  # UnicodePlots.jl
export PLOTDOCS_ANSICOLOR=true
export JULIA_CONDAPKG_BACKEND=MicroMamba

julia_project() {
  xvfb-run -a julia --color=yes --project=docs "$@"
}

banner() {
  echo "running action $GITHUB_ACTION with workflow $GITHUB_WORKFLOW for $GITHUB_REPOSITORY@$GITHUB_REF"
  echo "triggered by actor $GITHUB_ACTOR on event $GITHUB_EVENT_NAME"
  echo "commit SHA is $GITHUB_SHA"
}

install_ubuntu_deps() {
  echo '== install system dependencies =='
  banner
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
}

install_and_precompile_julia_deps() {
  echo "== install julia dependencies =="
  banner
  JULIA_PKG_PRECOMPILE_AUTO=0 julia_project ci/matplotlib.jl
  echo '== precompile docs dependencies =='
  julia_project docs/make.jl none
}

build_documenter_docs() {
  echo "== build documentation =="
  banner
  # export PLOTDOCS_PACKAGES='UnicodePlots'
  # export PLOTDOCS_PUSH_PREVIEW=true
  # export PLOTDOCS_EXAMPLES=1
  julia_project docs/make.jl all
}
