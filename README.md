# Franklin Templates

Templates for [Franklin](https://github.com/JuliaDocs/Franklin.jl), the static-site generator in Julia.

Most of these templates are adapted from existing, popular templates with minor modifications to accommodate Franklin's content.

**NOTE**: these templates should be seen as _starting points_, they are far from perfect.
PRs to help improve them will be very welcome, thanks!
Most importantly they are designed to be simple to adjust to your needs.

## List of templates

Get an idea for which template you like using [this preview](https://tlienart.github.io/FranklinTemplates.jl/).
The grid below keeps track of their name, license, the kind of navbar they have and whether they require Javascript.

| Name | Source | License | Navbar | JS  |
| ---- | ------ | ------- | ----- | --- |
| `"sandbox"`  | N/A    | MIT     | N/A | No |
| `"sandbox-extended"`  | N/A    | MIT     | N/A | No |
| `"basic"`  | N/A    | MIT     | Top | No |
| `"jemdoc"` | [jemdoc](https://github.com/jem/jemdoc) | N/A | Side | No |
| `"hypertext"` | [grav theme hypertext](https://github.com/artofthesmart/hypertext) | [MIT](https://github.com/artofthesmart/hypertext/blob/master/LICENSE) | Top | No |
| `"pure-sm"` | [pure css](https://purecss.io/layouts/side-menu/) | [Yahoo BSD](https://github.com/pure-css/pure-site/blob/master/LICENSE.md) | Side | No |
| `"vela"` | [grav theme vela](https://github.com/danzinger/grav-theme-vela) | [MIT](https://github.com/danzinger/grav-theme-vela/blob/develop/LICENSE) | Side (collapsable) | Yes |
| `"tufte"` | [Tufte CSS](https://github.com/edwardtufte/tufte-css), and a bit of [Lawler.io](https://github.com/Eiriksmal/lawler-dot-io) for the menu | [both](https://github.com/edwardtufte/tufte-css/blob/gh-pages/LICENSE)  [MIT](https://github.com/Eiriksmal/lawler-dot-io/blob/main/license.md) | Side | No |
| `"hyde"` | [Hyde](https://github.com/poole/hyde) | [MIT](https://github.com/poole/hyde/blob/master/LICENSE.md) | Side | No |
| `"lanyon"` | [Lanyon](https://github.com/poole/lanyon) | [MIT](https://github.com/poole/lanyon/blob/master/LICENSE.md) | Side (collapsable) | No |
| `"just-the-docs"` | [Just the docs](https://github.com/pmarsceill/just-the-docs) | [MIT](https://github.com/pmarsceill/just-the-docs/blob/master/LICENSE.txt) | Side/Top | No |
| `"minimal-mistakes"` | [Minimal mistakes](https://github.com/mmistakes/minimal-mistakes) | [MIT](https://github.com/mmistakes/minimal-mistakes/blob/master/LICENSE) | Side/Top | No |
| `"celeste"` | [Celeste](https://github.com/nicoelayda/celeste) | [MIT](https://github.com/nicoelayda/celeste/blob/master/LICENSE) | Top | No |
| `"bootstrap5"` | [Bootstrap5](https://getbootstrap.com/docs/5.3/getting-started/introduction/) | [MIT](https://github.com/twbs/bootstrap/blob/main/LICENSE) | Top | No |
| `"academic"` | [Jon Barron](https://jonbarron.info/) | N/A | No | No |

## Modifying or adding a template

The package contains a few utils to make it easier to modify or add templates.
Now if it was just a bunch of fixes to an existing template, you can just push those changes to your fork and open a PR.
If it's a new template that you're working on, you can also do that but there's a few extra things you need to do:

1. in `FranklinTemplates/src/FranklinTemplates.jl` add the name of your template in the list
1. in `FranklinTemplates/docs/make.jl` add the name of your template with a description in the list
1. in `FranklinTemplates/docs/thumb` add a screenshot of your template in `png` format with **exactly** an 850x850 dimension
1. in `FranklinTemplates/docs/index_head.html` add a CSS block following the other examples

To locally see changes quickly, use [Changing a single template](#user-content-changing-a-single-template).
To change all templates at the same time, use [Changing multiple templates](#user-content-changing-multiple-templates).

### Changing a single template

1. clone a fork of this package wherever you usually do things, typically `~/.julia/dev/`
1. checkout the package in development mode with `] dev FranklinTemplates`
1. `cd` to a sensible workspace and do one of
    1. `using FranklinTemplates; newsite("newTemplate")` to start working on `newTemplate` more or less from scratch,
    1. `using FranklinTemplates; newsite("newTemplate", template="jemdoc")` to start working on `newTemplate` using some other template as starting point,
    1. `using FranklinTemplates; modify("jemdoc")` to quickly start working on an existing template in order to fix it.
1. change things, fix things, etc.
1. bring your changes into your fork with `addtemplate("path/to/your/work")`
    1. if the template doesn't exist, it will just add the folder removing things that are duplicate from `templates/common/`.
    1. if the template exists, it will just adjust what needs to be adjusted.

### Changing multiple templates

1. clone a fork of this package wherever you usually do things, typically `~/.julia/dev/`
1. checkout the package in development mode with `] dev FranklinTemplates`
1. start serving the preview website with `using FranklinTemplates; FranklinTemplates.serve_templates()`

Thanks!!

## Misc

* Current version of KaTeX: [0.16.0](https://github.com/KaTeX/KaTeX/releases/tag/v0.16.0)
* Current version of highlight: [11.5.1](https://github.com/highlightjs/highlight.js/releases/tag/10.7.1) (with `css`, `C`, `C++`, `yaml`, `bash`, `ini,TOML`, `markdown`, `html,xml`, `r`, `julia`, `julia-repl`, `plaintext`, `python` and the minified `github` theme).
* Current version of Plotly (used in `sandbox-extended`): 1.58.4

## Notes

This package contains a copy of the relevant KaTeX files and highlight.js files;
- the KaTeX files are basically provided "as is", completely unmodified; you could download your own version of the files from the [original repo](https://github.com/KaTeX/KaTeX) and replace the files in `_libs/katex`,
- the Highlight.js files are _essentially_ provided "as is" for a set of languages, there is a small modification in the `highlight.pack.js` file to highlight julia shell and pkg prompt (see next section). You can also download your own version of files from the [original source](https://highlightjs.org) where you might want to
    - specify languages you want to highlight if other than the default list above
    - specify the "style" (we use github but you could use another sheet)

**Note**: in Franklin's `optimize` pass, by default the **full library** `highlight.js` is called to pre-render highlighting; this bypasses the `highlight.pack.js` file and, in particular, supports highlighting for **all** languages. In other words, the `highlight.pack.js` file is relevant only when you preview your site locally with `serve()` or if you don't intend to apply the prerendering step.

### Maintenance

- if update `highlight.min.js`, look for `julia>`, and replace with something like

```
{name:"Julia REPL",contains:[{className:"meta.prompt",begin:/^julia>/,relevance:10,starts:{end:/^(?![ ]{6})/,
subLanguage:"julia"}},{className:"meta.pkg",begin:/^\(.*\) pkg>/,relevance:10,starts:{end:/^(?![ ]{6})/,
subLanguage:"julia"}},{className:"meta.shell",begin:/^shell>/,relevance:10,starts:{end:/^(?![ ]{6})/,
subLanguage:"julia"}}],aliases:["jldoctest"]}
```

(copying the case for `julia` and adding a case for pkg and for shell, see also the CSS for `.hljs-meta.pkg_` etc.)

- for testing all layouts jointly (you'll need to have `PlotlyJS` and `Hyperscript` installed)

### Testing before release

```julia
include("docs/make.jl")
import LiveServer
LiveServer.serve(dir="docs/build")
```

* check that all templates have a thumbnail
* check that in basic - more goodies, the shell, pkg and julia prompts are highlighted properly (in case of update of highlight)
* check that math displays properly (in case of update of katex)
