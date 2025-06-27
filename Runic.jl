# Runic.jl

*A code formatter with rules set in stone.*

[![Test](https://github.com/fredrikekre/Runic.jl/actions/workflows/Test.yml/badge.svg?branch=master&event=push)](https://github.com/fredrikekre/Runic.jl/actions/workflows/Test.yml)
[![codecov](https://codecov.io/gh/fredrikekre/Runic.jl/graph/badge.svg?token=GWKJKBZ5FB)](https://codecov.io/gh/fredrikekre/Runic.jl)
[![code style: runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)

Runic is a formatter for the [Julia programming language](https://julialang.org/) built on
top of [JuliaSyntax.jl](https://github.com/JuliaLang/JuliaSyntax.jl).


Similarly to [`gofmt`](https://pkg.go.dev/cmd/gofmt), Runic have *no configuration*. The
formatting rules are set in stone (although not yet complete). This approach is something
that is appreciated by most Go programmers, see for example the following
[quote](https://www.youtube.com/watch?v=PAAkCSZUG1c&t=523s):

> Gofmt's style is no one's favorite, yet gofmt is everyone's favorite.


### Table of contents

 - [Quick start](#quick-start)
 - [Installation](#installation)
 - [Usage](#usage)
    - [CLI](#cli)
    - [Editor integration](#editor-integration)
    - [Git integration](#git-integration)
    - [Adopting Runic formatting](#adopting-runic-formatting)
       - [Ignore formatting commits in git blame](#ignore-formatting-commits-in-git-blame)
       - [Badge](#badge)
 - [Checking formatting](#checking-formatting)
    - [Github Actions](#github-actions)
    - [Git hooks](#git-hooks)
 - [Version policy](#version-policy)
 - [Formatting specification](#formatting-specification)

## Quick start

Copy-pasteable setup commands for the impatient:

```sh
# Install Runic
julia --project=@runic -e 'using Pkg; Pkg.add("Runic")'
# Install the runic shell script
curl -fsSL -o ~/.local/bin/runic https://raw.githubusercontent.com/fredrikekre/Runic.jl/refs/heads/master/bin/runic
chmod +x ~/.local/bin/runic
# Install the git-runic shell script
curl -fsSL -o ~/.local/bin/git-runic https://raw.githubusercontent.com/fredrikekre/Runic.jl/refs/heads/master/bin/git-runic
chmod +x ~/.local/bin/git-runic
```

Assuming `~/.local/bin` is in your `PATH` you can now invoke `runic`, e.g.:

```sh
runic --version # Show version info
runic --help    # Show documentation
```

```sh
# Format all files in-place in the current directory (recursively)
# !! DON'T DO THIS FROM YOUR HOME DIRECTORY !!
runic --inplace .
```

## Installation

Runic can be installed with Julia's package manager:

```sh
julia -e 'using Pkg; Pkg.add("Runic")'
```

For CLI usage and editor integration (see [Usage](#usage)) it is recommended to install
Runic in a separate project such as e.g. the shared project `@runic`:

```sh
julia --project=@runic -e 'using Pkg; Pkg.add("Runic")'
```

The main interface to Runic is the command line interface (CLI) through the `main` function:

```sh
julia --project=@runic -e 'using Runic; exit(Runic.main(ARGS))' -- <args>
```

To simplify the invocation of the CLI it is recommended to install the
[`runic`](https://github.com/fredrikekre/Runic.jl/blob/master/bin/runic) shell script into a
directory in your `PATH`. This can be done with the following commands (replace the two
occurrences of `~/.local/bin` if needed):

```sh
# Download the script into ~/.local/bin
curl -fsSL -o ~/.local/bin/runic https://raw.githubusercontent.com/fredrikekre/Runic.jl/refs/heads/master/bin/runic
# Make the script executable
chmod +x ~/.local/bin/runic
# Verify the installation
runic --version
```

> [!NOTE]
> Alternatively you can can add a shell alias to your shell startup file. The drawback of
> this approach is that runic can only be invoked from the shell and not by other programs.
> ```sh
> alias runic="julia --project=@runic -e 'using Runic; exit(Runic.main(ARGS))' --"
> # alias runic="julia --project=@runic -m Runic"
> ```

> [!NOTE]
> In Julia 1.12 and later the `main` function can be invoked with the `-m` flag, i.e.:
> ```sh
> julia --project=@runic -m Runic <args>
> ```

## Usage

### CLI

The CLI is the main interface to Runic. `runic --help` will show all available options
(output included below). Some example invocations are listed here.

Format a single file in place:
```sh
runic --inplace file.jl
```

Format all files in a directory (recursively) in place:
```sh
runic --inplace src/
```

Verify formatting of all files in a directory with verbose and diff output:
```sh
runic --check --diff --verbose src/
```

Format the content of standard in and print the result to standard out:
```sh
echo "1+1" | runic
```

Output of `runic --help` for a complete list of options:

```
$ runic --help
NAME
       Runic.main - format Julia source code

SYNOPSIS
       julia -m Runic [<options>] <path>...

DESCRIPTION
       `Runic.main` (typically invoked as `julia -m Runic`) formats Julia source
       code using the Runic.jl formatter.

OPTIONS
       <path>...
           Input path(s) (files and/or directories) to process. For directories,
           all files (recursively) with the '*.jl' suffix are used as input files.
           If no path is given, or if path is `-`, input is read from stdin.

       -c, --check
           Do not write output and exit with a non-zero code if the input is not
           formatted correctly.

       -d, --diff
           Print the diff between the input and formatted output to stderr.
           Requires `git` to be installed.

       --help
           Print this message.

       -i, --inplace
           Format files in place.

       --lines=<start line>:<end line>
           Limit formatting to the line range <start line> to <end line>. Multiple
           ranges can be formatted by specifying multiple --lines arguments.

       -o <file>, --output=<file>
           File to write formatted output to. If no output is given, or if the file
           is `-`, output is written to stdout.

       -v, --verbose
           Enable verbose output.

       --version
           Print Runic and julia version information.
```

In addition to the CLI there is also the two function `Runic.format_file` and
`Runic.format_string`. See their respective docstrings for details.

### Editor integration

Most code editors have code formatting capabilities and many can be configured to use Runic.
Example configuration for some editors are given in the following sections.

 - [Neovim](#neovim)
 - [VS Code](#vs-code)
 - [Emacs](#emacs)
 - [Helix](#helix)

> [!IMPORTANT]
> Note that these configurations depend on third party plugins. They works as advertised but
> use it at your own risk.

#### Neovim

Runic can be used as a formatter in [Neovim](https://neovim.io/) using
[conform.nvim](https://github.com/stevearc/conform.nvim). Refer to the conform.nvim
repository for installation and setup instructions.

Runic is not (yet) available directly in conform so the following configuration needs
to be passed to the setup function. This assumes Runic is installed in the `@runic` shared
project as suggested in the [Installation](#installation) section above. Adjust the
`--project` flag if you installed Runic somewhere else.

```lua
require("conform").setup({
    formatters = {
        runic = {
            command = "julia",
            args = {"--project=@runic", "--startup-file=no", "-e", "using Runic; exit(Runic.main(ARGS))"},
        },
    },
    formatters_by_ft = {
        julia = {"runic"},
    },
    default_format_opts = {
        -- Increase the timeout in case Runic needs to precompile
        -- (e.g. after upgrading Julia and/or Runic).
        timeout_ms = 10000,
    },
})
```

Note that conform (and thus Runic) can be used as `formatexpr` for the `gq` command. This is
enabled by adding the following to your configuration:
```lua
vim.o.formatexpr = "v:lua.require('conform').formatexpr()"
```

#### VS Code

Runic can be used as a formatter in [VS Code](https://code.visualstudio.com/) using the
extension [Custom Local Formatters](https://marketplace.visualstudio.com/items?itemName=jkillian.custom-local-formatters&ssr=false#overview).

After installing the extension you can configure Runic as a local formatter by adding the
following entry to your `settings.json`. This assumes Runic is installed in the `@runic`
shared project as suggested in the [Installation](#installation) section above. Adjust the
`--project` flag if you installed Runic somewhere else.

```json
"customLocalFormatters.formatters": [
    {
      "command": "julia --project=@runic --startup-file=no -e 'using Runic; exit(Runic.main(ARGS))'",
      "languages": ["julia"]
    }
]
```

Using the "Format Document" VS Code command will now format the file using Runic. Note that
the first time you execute the command you will be prompted to select a formatter since the
Julia language extension also comes with a formatter.

> [!NOTE]
> If you've installed Julia with [juliaup](https://github.com/JuliaLang/juliaup), the
> `julia` executable might not be available in `PATH` within VS Code, causing formatting to
> fail. In that case, you can find the full path of the `julia` executable using `which
> julia` (typically something like `${HOME}/.juliaup/bin/julia` with default juliaup
> settings), and then replace `julia` in the command in `settings.json` with the full path.

#### Emacs

Runic can be used as a formatter in [Emacs](https://www.gnu.org/software/emacs/) using [apheleia](https://github.com/radian-software/apheleia).
Refer to the apheleia repository for installation and setup instruction. 

Runic is not (yet) available directly in apheleia so the
following configuration needs to be added to your `.emacs`.
This assumes Runic is installed in the `@runic` shared project as suggested in the
[Installation](#installation) section above. Adjust the `--project` flag if you installed
Runic somewhere else.

```
(push `(runic . ("julia" "--project=@runic" "--startup-file=no" "-e" "using Runic; exit(Runic.main(ARGS))" "--")) apheleia-formatters)
(push '(julia-mode . runic) apheleia-mode-alist)
```

#### Helix

Runic can be used as a formatter in [Helix](https://helix-editor.com/). Configure Helix's
`:format` command to use Runic for julia code by adding the following to the
`languages.toml` configuration file. This assumes Runic is installed in the `@runic` shared
project as suggested in the [Installation](#installation) section above. Adjust the
`--project` flag if you installed Runic somewhere else.

```
[[language]]
name = "julia"
auto-format = false
formatter = { command = "julia" , args = ["--project=@runic", "--startup-file=no", "-e", "using Runic; exit(Runic.main(ARGS))"] }
```

### Git integration

The [`git-runic`](https://github.com/fredrikekre/Runic.jl/blob/master/bin/git-runic)
script (a modified version of
[`git-clang-format`](https://github.com/llvm/llvm-project/blob/main/clang/tools/clang-format/git-clang-format))
provides a convenient way to apply Runic formatting incrementally to a code
base by limiting formatting to lines that are added or modified in each commit.
The script can be installed with the following commands (replace the two
occurrences of `~/.local/bin` if needed):

```sh
# Download the script into ~/.local/bin
curl -fsSL -o ~/.local/bin/git-runic https://raw.githubusercontent.com/fredrikekre/Runic.jl/refs/heads/master/bin/git-runic
# Make the script executable
chmod +x ~/.local/bin/git-runic
# Verify the installation
git runic -h
```

### Adopting Runic formatting

Here is a checklist for adopting Runic formatting wholesale in a project:

 - Format all existing files with `runic -i <path>` and commit the changes in separate
   commit. This commit can be ignored in `git blame` (see [Ignore formatting commits in git
   blame](#ignore-formatting-commits-in-git-blame)).
 - Configure automatic checks (see [Checking formatting](#checking-formatting)) to ensure
   future changes adhere to the formatting rules.
 - Optionally add a badge to the repository README, see [Badge](#badge).

Alternatively Runic formatting can be adopted incrementally by using the
`git-runic` integration, see [Git integration](#git-integration) for details.

#### Ignore formatting commits in git blame

When setting up Runic formatting for a repository for the first time (or when upgrading to a
new version of Runic) the formatting commit will likely result in a large diff with mostly
non functional changes such as e.g. whitespace. Since the diff is large it is likely that it
will show up and interfere when using [`git-blame`](https://git-scm.com/docs/git-blame). To
ignore commits during `git-blame` you can i) add them to a file `.git-blame-ignore-revs` and
ii) tell git to use this file as ignore file by running

```
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

See the [git-blame
documentation](https://git-scm.com/docs/git-blame#Documentation/git-blame.txt---ignore-revs-fileltfilegt)
for details.

For example, such a file may look like this:
```
# Adding Runic formatting
<commit hash of formatting commit>

# Upgrading Runic from 1.0 to 2.0
<commit hash of formatting commit>
```

#### Badge

If you want to show that your project is formatted with Runic you can add the following
badge in the repository README:

```markdown
[![code style: runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)
```

The badge looks like this:
[![code style: runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)

## Checking formatting

Runic has a check-mode that verifies whether files are correctly formatted or not. This mode
is enabled with the `--check` flag. In check mode Runic will exit with a non-zero code if
any of the input files are incorrectly formatted. As an example, the following invocation
can be used:

```sh
git ls-files -z -- '*.jl' | xargs -0 --no-run-if-empty julia --project=@runic -m Runic --check --diff
```

This will run Runic's check mode (`--check`) on all `.jl` files in the repository and print
the diff (`--diff`) if the files are not formatted correctly. If any file is incorrectly
formatted the exit code will be non-zero.


### Github Actions

You can use [`fredrikekre/runic-action`](https://github.com/fredrikekre/runic-action) to run
Runic on Github Actions:

```yaml
name: Runic formatting
on:
  push:
    branches:
      - 'master'
      - 'release-'
    tags:
      - '*'
  pull_request:
jobs:
  runic:
    name: Runic
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # - uses: julia-actions/setup-julia@v2
      #   with:
      #     version: '1'
      # - uses: julia-actions/cache@v2
      - uses: fredrikekre/runic-action@v1
        with:
          version: '1'
```

See [`fredrikekre/runic-action`](https://github.com/fredrikekre/runic-action) for details.

> [!IMPORTANT]
> Please be aware of Runic's [version policy](#version-policy) when configuring the version.
> Pinning to a major release (as above with `version: '1'`) may cause occasional CI failures
> whenever there is a new minor release of Runic that happens to impact your code base. When
> this happens you simply have to i) re-run Runic on the new version, ii) commit the result,
> and iii) add the commit to
> [the ignore list](#ignore-formatting-commits-in-git-blame). This is still recommended
> since minor releases should be relatively rare, and if you use Runic you presumably want
> these minor bugfixes to be applied to your code base.
> The alternative is to pin to a minor version and manually upgrade to new minor versions.

### Git hooks

Runic can be used together with [`pre-commit`](https://pre-commit.com/) using
[`fredrikekre/runic-pre-commit`](https://github.com/fredrikekre/runic-pre-commit). After
installing `pre-commit` you can add the following to your `.pre-commit-config.yaml` to run
Runic before each commit:

```yaml
repos:
  - repo: https://github.com/fredrikekre/runic-pre-commit
    rev: v1.0.0
    hooks:
      - id: runic
```

See [`fredrikekre/runic-pre-commit`](https://github.com/fredrikekre/runic-pre-commit) for
details.

If you don't want to use `pre-commit` you can also use a plain git hook. Here is an example
hook (`.git/hooks/pre-commit`):

```sh
#!/usr/bin/env bash

# Redirect output to stderr.
exec 1>&2

# Run Runic on added and modified files
git diff-index -z --name-only --diff-filter=AM master | \
    grep -z '\.jl$' | \
    xargs -0 --no-run-if-empty julia --project=@runic -m Runic --check --diff
```

## Version policy

Runic adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Semantic
versioning is easy to apply and understand when it comes to the API (e.g. the [CLI](#cli)
and public methods of the Runic library) but it is less clear how to apply it to changes in
the formatted output. Runic makes the following policy:

 - **Patch releases** are fully backwards compatible, i.e. there should be *no* changes in
   formatted output between e.g. `1.0.x` and `1.0.(x + 1)`. Patch releases are therefore
   limited to fixing bugs that caused the formatter to error.
 - **Minor releases** may contain changes to the formatting that come as a result of fixing
   *specification bugs*. A specification bug is a bug that causes output that is not in line
   with the [formatting specification](#formatting-specification). For example, the spec
   says that Runic formats spaces around operators. Fixing a bug that causes some operator
   to be formatted without spaces is therefore allowed in a minor release.
 - **Major releases** will contain formatting changes resulting from non backwards
   compatible changes to the specification. No such changes are planned at the moment.

## Formatting specification

This is a list of things that Runic currently is doing:

 - [Toggle formatting](#toggle-formatting)
 - [Line width limit](#line-width-limit)
 - [Newlines in blocks](#newlines-in-blocks)
 - [Indentation](#indentation)
 - [Explicit `return`](#explicit-return)
 - [Spaces around operators, assignment, etc](#spaces-around-operators-assignment-etc)
 - [Spaces around keywords](#spaces-around-keywords)
 - [Multiline listlike expressions](#multiline-listlike-expressions)
 - [Spacing in listlike expressions](#spacing-in-listlike-expressions)
 - [Trailing semicolons](#trailing-semicolons)
 - [Literal floating point numbers](#literal-floating-point-numbers)
 - [Literal hex and oct numbers](#literal-hex-and-oct-numbers)
 - [Parentheses around operator calls in colon](#parentheses-around-operator-calls-in-colon)
 - [`in` instead of `∈` and `=`](#in-instead-of--and-)
 - [Braces around right hand side of `where`](#braces-around-right-hand-side-of-where)
 - [Whitespace miscellaneous](#whitespace-miscellaneous)

### Toggle formatting

It is possible to toggle formatting around expressions where you want to disable Runic's
formatting. This can be useful in cases where manual formatting increase the readability of
the code. For example, manually aligned array literals may look worse when formatted by
Runic.

The source comments `# runic: off` and `# runic: on` will toggle the formatting off and on,
respectively. The comments must be on their own line, they must be on the same level in the
syntax tree, and they must come in pairs. An exception to the pairing rule is made at top
level where a `# runic: off` comment will disable formatting for the remainder of the file.
This is so that a full file can be excluded from formatting without having to add a
`# runic: on` comment at the end of the file.

> [!NOTE]
> Note that it is enough that a comment contain the substring `# runic: off` or
> `# runic: on` so that they can be combined with other "pragmas" such as e.g.
> [Literate.jl line filters](https://fredrikekre.github.io/Literate.jl/v2/fileformat/#Filtering-lines)
> like `#src`.

> [!NOTE]
> For compatibility with [JuliaFormatter](https://github.com/domluna/JuliaFormatter.jl) the
> comments `#! format: off` and `#! format: on` are also recognized by Runic.

For example, the following code will toggle off the formatting for the array literal `A`:

```julia
function foo()
    a = rand(2)
    # runic: off
    A = [
        -1.00   1.41
         3.14  -4.05
    ]
    # runic: on
    return A * a
end
```

### Line width limit

No. Use your <kbd>Enter</kbd> key or refactor your code.

###  Newlines in blocks

The body of blocklike expressions (e.g. `if`, `for`, `while`, `function`, `struct`, etc.)
always start and end with a newline. Examples:
```diff
-if c x end
+if c
+    x
+end

-function f(x) x^2 end
+function f(x)
+    x^2
+end
```

An exception is made for empty blocks so that e.g.
```julia
struct A end
```
is allowed.

### Indentation

Consistently four spaces for each indentation level.

Standard code blocks (`function`, `for`, `while`, ...) all increase the indentation level by
one until the closing `end`. Examples:
```diff
 function f()
-  for i in 1:2
-    # loop
-  end
-  while rand() < 0.5
-    # loop
-  end
+    for i in 1:2
+        # loop
+    end
+    while rand() < 0.5
+        # loop
+    end
 end
```

Listlike expressions like e.g. tuples, function calls, array literals, etc. also increase
the indentation level by one until the closing token. This only has an effect if the list
span multiple lines. Examples:
```diff
 x = (
-  a, b, c, d,
-  e, f, g, h,
+    a, b, c, d,
+    e, f, g, h,
 )

 foo(
-  a, b, c, d,
-  e, f, g, h,
+    a, b, c, d,
+    e, f, g, h,
 )

 [
-  a, b, c, d,
-  e, f, g, h,
+    a, b, c, d,
+    e, f, g, h,
 ]
```

The examples above both result in "hard" indentation levels. Other expressions that span
multiple lines result in "soft" indentation levels. The difference between the two is that
soft indentation levels don't nest (this is really only applicable to multiline operator
call chains).

```diff
 using Foo:
-  foo, bar
+    foo, bar

 x = a + b +
-  c
+    c

 x = a ? b :
-  c
+    c
```

Without soft indentation levels operators chains can result in ugly (but logically correct)
indentation levels. For example, the following code:
```julia
x = a + b *
        c +
    d
```
would be "correct". Such a chain looks better the way it is currently formatted:
```julia
x = a + b *
    c +
    d
```

### Explicit `return`

Explicit `return` statements are ensured in function and macro definitions by adding
`return` in front of the last expression, with some exceptions listed below.

 - If the last expression is a `for` or `while` loop (which both always evaluate to
   `nothing`) `return` is added *after* the loop.
 - If the last expression is a `if` or `try` block the `return` is only added in case
   there is no `return` inside any of the branches.
 - If the last expression is a `let` or `begin` block the `return` is only added in case
   there is no `return` inside the block.
 - If the last expression is a macro call, the `return` is only added in case there is no
   `return` inside the macro.
 - No `return` is added in short form functions (`f(...) = ...`), short form anonymous
   functions (`(...) -> ...`), and `do`-blocks (`f(...) do ...; ...; end`).
 - If the last expression is a function call, and the function name is (or contains) `throw`
   or `error`, no `return` is added. This is because it is already obvious that these calls
   terminate the function and don't return any value.

Note that adding `return` changes the expression in a way that is visible to macros.
Therefore it is, in general, not valid to add `return` to a function defined inside a macro
since it isn't possible to know what the macro will expand to. For this reason this
formatting rule is disabled for functions defined inside macros with the exception of some
known and safe ones from Base (e.g. `@inline`, `@generated`, ...).

For the same reason mentioned above, if the last expression in a function is a macro call it
isn't valid to step in and add `return` inside. Instead the `return` will be added in front
of the macro call like any other expression (unless there is already a `return` inside of
the macro as described above).

Examples:
```diff
 function f(n)
-    sum(rand(n))
+    return sum(rand(n))
 end

 macro m(args...)
-    :(generate_expr(args...))
+    return :(generate_expr(args...))
 end
```

#### Potential changes
 - If the last expression is a `if` or `try` block it might be better to
   recurse into the branches and add `return` there. Looking at real code, if a
   function ends with an `if` block, it seems about 50/50 whether adding return
   *after* the block or adding return inside the branches is the best choice.
   Quite often `return if` is not the best but at least Runic's current
   formatting will force to think about the return value.
   See issue [#52](https://github.com/fredrikekre/Runic.jl/issues/52).

### Spaces around operators, assignment, etc

Runic formats spaces around infix operators, assignments, comparison chains, and type
comparisons (binary `<:` and `>:`), and some other operator-like things. If the space is
missing it will be inserted, if there are multiple spaces it will be reduced to one.
Examples:
```diff
-1+2*3
-1  +  2  *  3
+1 + 2 * 3
+1 + 2 * 3

-x=1
-x=+1
-x+=1
-x.+=1
+x = 1
+x = +1
+x += 1
+x .+= 1
-1<2>3
-1  <  2  >  3
+1 < 2 > 3
+1 < 2 > 3

-T<:Integer
-T  >:  Integer
+T <: Integer
+T >: Integer

-x->x
-a  ?  b  :  c
+x -> x
+a ? b : c
```

Note that since Runic's rules are applied consistently, no matter the context or surrounding
code, the "spaces around assignment" rule also means that there will be spaces in keyword
arguments in function definitions and calls. Examples:
```diff
-foo(; a=1) = a
-foo(a=1)
+foo(; a = 1) = a
+foo(a = 1)
```

Exceptions to the rule above are `:`, `^`, `::`, and unary `<:` and `>:`. These are
formatted *without* spaces around them. Examples:
```diff
-a : b
+a:b

-a ^ 5
+a^5

-a :: Int
+a::Int

-<: Integer
->:  Integer
+<:Integer
+>:Integer
```

#### Potential changes
 - Perhaps the rule for some of these should be "at least one space" instead. This could
   help with alignment issues. Discussed in issue
   [#12](https://github.com/fredrikekre/Runic.jl/issues/12).

### Spaces around keywords

Consistently use single space around keywords. Examples:
```diff
-struct  Foo
+struct Foo

-mutable  struct  Bar
+mutable struct Bar

-function  foo(x::T)  where  {T}
+function foo(x::T) where {T}
```

### Multiline listlike expressions

Listlike expressions (tuples, function calls/definitions, array literals, etc.) that
*already* span multiple lines are formatted to consistently have a leading and a trailing
newline. Trailing commas are enforced for array/tuple literals (where adding another item is
common) but optional for function/macro calls/definitions.
```diff
-(a,
-    b)
+(
+    a,
+    b,
+)

-foo(a,
-    b)
+foo(
+    a,
+    b
+)

-[1 2
- 3 4]
+[
+    1 2
+    3 4
+]
```

Note that currently there is no line-length limit employed so expressions that only take up
a single line, even if they are long, are not formatted like the above. Thus, only
expressions where the original author have "committed" to mulitples lines are affected by
this rule.

### Spacing in listlike expressions

Listlike expressions (tuples, function calls/definitions, array literals, etc.) use a
consistent rule of no space before `,` and a single space after `,`. Trailing commas are
enforced for array/tuple literals (where adding another item is common) but optional for
function/macro calls/definitions. Leading/trailing spaces are removed. Examples:

```diff
-f(a,b)
-(a,b)
-[a,  b]
+f(a, b)
+(a, b)
+[a, b]


-(a,b,)
+(a, b)
 (
     a,
-    b
+    b,
 )

-( a, b )
+(a, b)
```

#### Potential changes
 - Perhaps the rule for some of these should be "at least one space" instead. This could
   help with alignment issues. Discussed in issue
   [#12](https://github.com/fredrikekre/Runic.jl/issues/12).

### Trailing semicolons

Trailing semicolons are removed in the body of blocklike expressions. Examples
```diff
 function f(x)
-    y = x^2;
-    z = y^2; # z = x^4
-    return z;
+    y = x^2
+    z = y^2  # z = x^4
+    return z
 end
```

Trailing semicolons at top level and module level are kept since they are sometimes used
there for output suppression (e.g. Documenter examples or scripts that are
copy-pasted/included in the REPL).

### Literal floating point numbers

Floating point literals are normalized so that they:
 - always have a decimal point
 - always have a digit before and after the decimal point
 - never have leading zeros in the integral and exponent part
 - never have trailing zeros in the fractional part
 - always use `e` instead of `E` for the exponent

Examples:
```diff
-1.
-.1
+1.0
+0.1

-01.2
-1.0e01
-0.10
+1.2
+1.0e1
+0.1

-1.2E5
+1.2e5
```

#### Potential changes
 - Always add the implicit `+` for the exponent part, i.e. `1.0e+1` instead of `1.0e1`.
   Discussed in issue [#13](https://github.com/fredrikekre/Runic.jl/issues/13).
 - Allow multiple trailing zeros in the fractional part, i.e. don't change `1.00` to `1.0`.
   Such trailing zeros are sometimes used to align numbers in literal array expressions.
   Discussed in issue [#14](https://github.com/fredrikekre/Runic.jl/issues/14).

### Literal hex and oct numbers

Hex literals are padded with zeros to better highlight the resulting type of the literal:
`UInt8` to 2 characters, `UInt16` to 4 characters, `UInt32` to 8 characters etc. Examples:
```diff
-0x1
-0x123
-0x12345
+0x01
+0x0123
+0x00012345
```

### Parentheses around operator calls in colon

Add parentheses around operator calls in colon expressions to better highlight the low
precedence of `:`. Examples:
```diff
-1 + 2:3 * 4
-1 + 2:3
-1:3 * 4
+(1 + 2):(3 * 4)
+(1 + 2):3
+1:(3 * 4)
```

### `in` instead of `∈` and `=`

The keyword `in` is used consistently instead of `∈` and `=` in `for` loops. Examples:
```diff
-for i = 1:2
+for i in 1:2

-for i ∈ 1:2
+for i in 1:2
```

Note that `∈` not replaced when used as an operator outside of loop contexts in
order to be symmetric with `∉` which doesn't have a direct ASCII equivalent.
See [#17](https://github.com/fredrikekre/Runic.jl/issues/17) for more details.

### Braces around right hand side of `where`

Braces are consistently used around the right hand side of `where` expressions. Examples:
```diff
-T where T
-T where T <: S where S <: Any
+T where {T}
+T where {T <: S} where {S <: Any}
```

### Whitespace miscellaneous


#### Trailing spaces

Trailing spaces are removed in code and comments (but not inside of multiline strings where
doing so would change the meaning of the code). Examples:
```diff
-1 + 1 
+1 + 1

-x = 2 # x is two 
+x = 2 # x is two
```

#### Tabs

Tabs are replaced with spaces. Example:
```diff
-function f()
-	return 1
-end
+function f()
+    return 1
+end
```

#### Vertical spacing

Extra vertical spacing is trimmed so that there are at maximum two empty lines
between expressions. Examples:
```diff
-function f()
-     x = 1
-
-
-
-    return x
-end
+function f()
+     x = 1
+
+
+    return x
+end
```

Any newlines at the start of a file are removed and if the file ends with more
than one newline the extra ones are removed.
