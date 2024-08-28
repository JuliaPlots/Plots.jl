```@setup contributing
using Plots; gr()
Plots.reset_defaults()
```

This is a guide to contributing to Plots and the surrounding ecosystem. Plots is a complex and far-reaching suite of software components, and as such will be most effective when the community contributes their own expertise, knowledge, perspective, and effort. The document is roughly broken up into the following categories, and after reading this introduction you should feel comfortable skipping to the section(s) that interest you the most:

- [The JuliaPlots Organization](#The-JuliaPlots-Organization): Packages and dependencies
- [Choosing a Project](#Choosing-a-Project): Fix bugs, add features, create recipes
- [Key Design Principles](#Key-Design-Principles): Design goals and considerations
- [Code Organization](#Code-Organization): Where to look when implementing new features
- [Git-fu (or... the mechanics of contributing)](#Git-fu-(or...-the-mechanics-of-contributing)): Git (how to commit/push), Github (how to submit a PR), Testing (VisualRegressionTests, Travis)

When in doubt, use this handy dandy logic designed by a [legendary open source guru](https://github.com/tbreloff)...

![](https://cloud.githubusercontent.com/assets/933338/23193321/4cd1d578-f876-11e6-92dc-222b52598054.png)

---

## The JuliaPlots Organization

[JuliaPlots](https://github.com/JuliaPlots) is the home for all things Plots. It was founded by [Tom Breloff](https://www.breloff.com), and extended through many contributions from [members](https://github.com/orgs/JuliaPlots/people) and others.  The first step in contributing will be to understand which package(s) are appropriate destinations for your code.


### Plots

This is the core package for:

- Definitions of `plot`/`plot!`
- The [core processing pipeline](@ref pipeline)
- Base [recipes](@ref recipes) for `path`, `scatter`, `bar`, and many others
- Generic [output](@ref output) methods
- Generic [layout](@ref layouts) methods
- Generic [animation](@ref animations) methods
- Generic types: Plot, Subplot, Axis, Series, ...
- Conveniences: `getindex`/`setindex`, `push!`/`append!`, `unzip`, `cycle`, ...

This package depends on RecipesBase, PlotUtils, and PlotThemes.  When contributing new functionality/features, you should make best efforts to find a more appropriate home (StatsPlots, PlotUtils, etc) than contributing to core Plots. In general, the push has been to reduce the size and scope of Plots, when possible, and move features to other packages.

### Backends

Backend code (such as code linking Plots with GR) lives in the `Plots/src/backends` directory. As such, backend code should be contributed to core Plots. GR and Plotly are the only backends installed by default. All other backend code is loaded conditionally using [Requires.jl](https://github.com/JuliaPackaging/Requires.jl) in `Plots/src/init.jl`.

### PlotDocs

PlotDocs is the home of this documentation. The documentation is built using [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl).

### RecipesBase

Seldom updated, but essential. This is the package that you would depend on to create third-party recipes. It contains the bare minimum to define new recipes.

### PlotUtils

Components that could be used for other (non-Plots) packages. Anything that is sufficiently generic and useful could be contributed here.

- Color (conversions, construction, conveniences)
- Color gradients/maps
- Tick computation

### PlotThemes

Visual themes (i.e. attribute defaults) such as "dark", "orange", etc.

### StatsPlots

An extension of Plots: Statistical plotting and tabular data.  Complex histograms and densities, correlation plots, and support for DataFrames.  Anything related to stats or special handling for table-like data should live here.

### GraphRecipes

An extension of StatsPlots: Graphs, maps, and more.

---

## Choosing a Project

For people new to Plots, the first step should be to read (and reread) the documentation.  Code up some examples, play with the attributes, and try out multiple backends. It's really hard to contribute to a project that you don't know how to use.

### Beginner Project Ideas

- **Create a new recipe**: Preferably something you care about.  Maybe you want custom overlays of heatmaps and scatters?  Maybe you have an input format that isn't currently supported?  Make a recipe for it so you can just `plot(thing)`.
- **Fix bugs**: There are many "bugs" which are specific to one backend, or incorrectly implement features that are infrequently used.  Some ideas can be found in the [issues marked easy](https://github.com/JuliaPlots/Plots.jl/issues?q=is%3Aissue+is%3Aopen+label%3A%22easy+-+up+for+grabs%22).
- **Add recipes to external packages**: By depending on RecipesBase, a package can define a recipe for their custom types.  Submit a PR to a package you care about that adds a recipe for that package.  For example, see [this PR to add OHLC plots for TimeSeries.jl](https://github.com/JuliaStats/TimeSeries.jl/pull/303).

### Intermediate Project Ideas

- **Improve your favorite backend**: There are many missing features and other improvements that can be made to individual backends.  Most issues specific to a backend have a [special tag](https://github.com/JuliaPlots/Plots.jl/issues?q=is%3Aissue+is%3Aopen+label%3APlotly).
- **Help with documentation**: This could come in the form of improved descriptions, additional examples, or full tutorials.  Please contribute improvements to [PlotDocs](https://github.com/JuliaPlots/PlotDocs.jl).
- **Expand StatsPlots functionality**:  qqplot, DataStreams, or anything else you can think of.

### Advanced Project Ideas

- **ColorBar redesign**: Colorbars [need serious love](https://github.com/JuliaPlots/Plots.jl/issues?utf8=%E2%9C%93&q=is%3Aissue%20is%3Aopen%20colorbar)... this would likely require a new Colorbar type that links with the appropriate Series object(s) and is independent during subplot layout.  We want to allow many series (possibly from multiple subplots) to use the same clims and to share a colorbar, or have multiple colorbars that can be flexibly positioned.
- **PlotSpec redesign**: This [long standing redesign proposal](https://github.com/JuliaPlots/Plots.jl/issues/390) could allow generic serialization/deserialization of Plot data and attributes, as well as some improvements/optimizations when mutating plots.  For example, we could lazily compute attribute values, and intelligently flag them as "dirty" when they change, allowing backends to skip much of the wasted processing and unnecessary rebuilding that currently occurs.
- **Improve graph recipes**: Lots to do here: clean up visuals, improve edge drawing, implement [layout algorithms](https://github.com/JuliaGraphs/NetworkLayout.jl), and much more.

---

## Key Design Principles

Flexible and generic... these are the core principles underlying Plots development, and also tend to cause confusion when users laser-focus on their specific use case.

I (Tom) have painstakingly designed the core logic to support nearly any use case that exists or may exist.  I don't pretend to know how you want to use Plots, or what type of data you might pass in, or what sort of recipe you may want to apply.  As such, I try to avoid unnecessary restriction of types, or forced conversions, or many other pitfalls of limited visualization frameworks.  The result is a highly modular framework which is limited by your imagination.

When contributing new features to Plots (or the surrounding ecosystem), you should strive for this mentality as well.  New features should be left as generic as possible, while avoiding obvious feature clash.

As an example, you may want a new recipe that shows a histogram when passed Float64 numbers, but shows counts of every unique value for strings.  So you make a recipe that works perfectly for your purpose:

```@example contributing
using Plots, StatsBase
gr(size = (300, 300), leg = false)

@userplot MyCount
@recipe function f(mc::MyCount)
    # get the array from the args field
    arr = mc.args[1]

    T = typeof(arr)
    if T.parameters[1] == Float64
        seriestype := :histogram
        arr
    else
        seriestype := :bar
        cm = countmap(arr)
        x = sort!(collect(keys(cm)))
        y = [cm[xi] for xi ∈ x]
        x, y
    end
end
```

The recipe defined above is a "user recipe", which builds a histogram for arrays of Float64, and otherwise shows a "countmap" of sorted unique values and their observed counts.  You only care about Float64 and String, and so you're results are fine:

```@example contributing
mycount(rand(500))
```

```@example contributing
mycount(rand(["A","B","C"],100))
```

But you didn't consider the person that, in the future, might want to pass integers to this recipe:

```@example contributing
mycount(rand(1:500, 500))
```

This user expected integers to be treated as numbers and output a histogram, but instead they were treated like strings.  A simple solution would have been to replace `if T.parameters[1] == Float64` with `if T.parameters[1] <: Number`.  However, should we even depend on `T` having it's first parameter be the element type? (No)  So even better would be `if eltype(arr) <: Number`, which now allows any container with any numeric type to trigger the "histogram" logic.

This simple example outlines a common theme when developing Plots (or really any other Julia package).  Try to create the most generic implementation you can think of while maintaining correctness.  You don't know what crazy types someone else will use to try to access your functionality.

---

## Code Organization

Generally speaking, similar functionality is kept within the same file.  Within the `src` directory, much of the files should be self explanatory (for example, you'll find animation methods/macros in the `animation.jl` file), but some could use a summary of contents:

- `Plots.jl`: imports, exports, shorthands, and initialization
- `args.jl`: defaults, aliases, and attribute processing
- `components.jl`: shapes, fonts, and other assorted goodies
- `pipeline.jl`: code which builds the plots and subplots through recursive application of recipes
- `recipes.jl`: primarily core series recipes
- `series.jl`: core input data handling and processing
- `utils.jl`: lots of functionality that didn't have a home... `getindex`/`setindex!` for `Plot`/`Subplot`/`Axis`/`Series`, `push!`/`append!` for adding data to a series, `cycle`/`unzip` and similar utility functions, `Segments`/`SegmentsIterator`, etc.

These files should probably be reorganized, but until then...

### Creating new backends

Model new backends on `Plots/src/backends/template.jl`. Implement the callbacks that are appropriate, especially `_display` and `_show` for GUI and image output respectively.

### Style/Design Guidelines

- Make every effort to minimize external dependencies and exports.  Requiring new dependencies is the most likely way to make your PR "unmergeable".
- Be careful adding method signatures on existing methods with Base types (Array, etc) as you may override key functionality.  This is especially true with recipes.  Consider wrapping inputs in a new type (like in "user recipes").
- Terse code is ok, as is verbose code.  What's important is understanding and context.  Will someone reading your code know what you mean?  If not, consider writing comments to describe your reason for the design, or describe the hack you just implemented in clear prose.  Sometimes [it's ok that your comments are longer than your code](https://github.com/JuliaPlots/Plots.jl/blob/master/src/pipeline.jl#L62-L67).
- Pick your project for yourself, but write code for others.  It should be generic and useful beyond your needs, and you should **never break functionality** because you can't figure out how to implement something well.  Spend more time on it... there's always a better way.

---

## Git-fu (or... the mechanics of contributing)

Many people have trouble with Git.  More have trouble with Github.  I think much of the confusion happens when you run commands without understanding what they do.  We're all guilty of it, but recovering usually means "starting over".  In this section, I'll try to keep a simple, practical approach to making PRs.  It's worked well for me, though YMMV.

### Guidelines

Here are some guidelines for the development workflow (Note: Even if you've made 20 PRs to Plots in the past, please read this as it may be different than past guidelines):

- **Commit to a branch that belongs to you.**  Typically that means you should give your branches names that are unique to you, and that might include information on the feature you're developing.  For example, I might choose to `git checkout -b tb-fonts` when starting work on fonts.
- **Open a PR against master.**  `master` is the "bleeding edge".  (Note: I used to recommend PRing to `dev`)
- **Only merge others changes when absolutely necessary.** You should prefer to use `git rebase origin/master` instead of `git merge origin/master`.  A rebase replays your recent commits on top of the most recent `master`, avoiding complicated and messy merge commits and generally avoiding confusion.  If you follow the first rule, then you likely won't get yourself in trouble.  Rebase horror stories generally result when many people are working on the same branch.  I find [this resource](https://git-scm.com/book/en/v2/Git-Branching-Rebasing) is great for understanding the important parts of `git rebase`.

---

### Development Workflow

My suggestions for a smooth development workflow:

#### Fork the repo

Navigate to the repo site (https://github.com/JuliaPlots/Plots.jl) and click the "Fork" button.  You might get a choice of which account or organization to place the fork.  I'll assume going forward that you forked to Github username `user123`.

#### Set up the git remote

Navigate to the local repo.  Note: I'm assuming that you do development in your Julia directory, and using Mac/Linux.  Adjust as needed.

```
cd ~/.julia/v0.5/Plots
git remote add forked git@github.com:user123/Plots.jl.git
```

After running these commands, `git remote -v` should show two remotes: `origin` (the main repo) and `forked` (your fork).  A remote is simply a reference/pointer to the github site hosting the repo, and a fork is simply any other git repo with a special link to the originating repo.

#### Create a new branch

If you're just starting work on a new feature:

```
git fetch origin
git checkout master
git merge --ff-only origin/master
git checkout -b user123-myfeature
git push -u forked user123-myfeature
```

The first three lines are meant to ensure you start from the main repo's master branch.  The `--ff-only` flag ensures you will only "fast forward" to newer commits, and avoids creating a new merge commit when you didn't mean to.  The `git checkout` line both creates a new branch (the `-b`) pointing to the current commit and makes that branch current.  The `git push` line adds this branch to your Github fork, and sets up the local branch to "track" (`-u`) the remote branch for subsequent `git push` and `git pull` calls.

#### or... Reuse an old branch

If you have an ongoing development branch (say, `user123-dev`) which you'd prefer to use (and which has previously been merged into master!) then you can get that up to date with:

```
git fetch origin
git checkout user123-dev
git merge --ff-only origin/master
git push forked user123-dev
```

We update our local copy of origin, checkout the dev branch, then attempt to "fast-forward" to the current master.  If successful, we push the branch back to our forked repo.

#### Write code, and format

Power up your favorite editor (maybe [Juno](https://junolab.org/)?) and make some code changes to the repo.

Format your changes (code style consistency) using:
```bash
$ julia -e 'using JuliaFormatter; format(["src", "test"])'
```

#### Commit

After applying changes, you'll want to "commit" or save a snapshot of all the changes you made.  After committing, you can "push" those changes to your forked repo on Github:

```
git add src/my_new_file.jl
git commit -am "my commit message"
git push forked user123-dev
```

The first line is optional, and is used when adding new files to the repo.  The `-a` means "commit all my changes", and the `-m` lets you write a note about the commit (you should always do this, and hopefully make it descriptive).

#### Submit a PR

You're almost there!  Browse to your fork (https://github.com/user123/Plots.jl).  Most likely there will be a section just above the code that asks if you'd like to create a PR from the `user123-dev` branch.  If not, you can click the "New pull request" button.

Make sure the "base" branch is JuliaPlots `master` and the "compare" branch is `user123-dev`.  Add an informative title and description, and link to relevant issues or discussions, then click "Create pull request".  You may get some questions about it, and possibly suggestions of how to fix it to be "merge-ready".  Then hopefully it gets merged... thanks for the contribution!!

#### Cleanup

After all of this, you will likely want to go back to using `master` (or possibly using a tagged release, once your feature is tagged).  To clean up:

```
git fetch origin
git checkout master
git merge --ff-only origin/master
git branch -d user123-dev
```

This catches your local master branch up to the remote master branch, then deletes the dev branch.  If you want to return to tagged releases, run `Pkg.free("Plots")` from the Julia REPL.

---

### Tags

New tags should represent "stable releases"... those that you are happy to distribute to end-users.  Effort should be made to ensure tests pass before creating a new tag, and ideally new tests would be added which test your new functionality.  This is, of course, a much trickier problem for visualization libraries as compared to other software.  See the [testing section](#testing) below.

Only JuliaPlots members may create a new tag.  To create a new tag, we'll create a new release on Github and use [attobot](https://github.com/attobot/attobot) to generate the PR to METADATA.  Create a new release at https://github.com/JuliaPlots/Plots.jl/releases/new (of course replacing the repo name with the package you're tagging).

The version number (vMAJOR.MINOR.PATCH) should be incremented using [semver](https://semver.org/), which generally means that breaking changes should increment the major number, backwards compatible changes should increment the minor number, and bug fixes should increment the patch number.  For "v0.x.y" versions, this requirement is relaxed.  The minor version can be incremented for breaking changes.

---

### Testing

#### VisualRegressionTests

Testing in Plots is done with the help of [VisualRegressionTests](https://github.com/JuliaPlots/VisualRegressionTests.jl).  Reference images are stored in [PlotReferenceImages](https://github.com/JuliaPlots/PlotReferenceImages.jl). Sometimes the reference images need to be updated (if features change, or if the underlying backend changes).  VisualRegressionTests makes it somewhat painless to update the reference images:

From the Julia REPL, run `Pkg.test(name="Plots")`.  This will try to plot the tests, and then compare the results to the stored reference images.  If the test output is sufficiently different than the reference output (using Tim Holy's excellent algorithm for the comparison), then a GTK window will pop up with a side-by-side comparison.  You can choose to replace the reference image, or not, depending on whether a real error was discovered.

After the reference images have been updated, navigate to PlotReferenceImages and push the changes to Github:

```
cd ~/.julia/v0.5/PlotReferenceImages
git add Plots/*
git commit -am "a useful message"
git push
```

If there are mis-matches due to bugs, **don't update the reference image**.

#### CI

On a `git push` the tests will be run automatically as part of our continuous integration setup.
This runs the same tests as above, downloading and comparing to the reference images, though with a larger tolerance for differences.
When these error, it may be due to timeouts, stale reference images, or a host of other reasons.
Check the logs to determine the reason.
If the tests are broken because of a new commit, consider rolling back.
