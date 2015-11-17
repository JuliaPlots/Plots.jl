
# include this first to help with crashing??
try
  @eval using Gtk
catch err
  warn("Gtk not loaded. err: $err")
end

# don't let pyplot use a gui... it'll crash
# note: Agg will set gui -> :none in PyPlot
ENV["MPLBACKEND"] = "Agg"
try
  @eval import PyPlot
end

include("../docs/example_generation.jl")


using Plots, FactCheck
import Images, ImageMagick

# if !isdefined(ImageMagick, :init_deps)
#   function ImageMagick.init_deps()
#     ccall((:MagickWandGenesis,libwand), Void, ())
#   end
# end

function makeImageWidget(fn)
  img = Gtk.GtkImageLeaf(fn)
  vbox = Gtk.GtkBoxLeaf(:v)
  push!(vbox, Gtk.GtkLabelLeaf(fn))
  push!(vbox, img)
  show(img)
  vbox
end

function replaceReferenceImage(tmpfn, reffn)
  cmd = `cp $tmpfn $reffn`
  run(cmd)
  info("Replaced reference image with: $cmd")
end

"Show a Gtk popup with both images and a confirmation whether we should replace the new image with the old one"
function compareToReferenceImage(tmpfn, reffn)

  # add the images
  imgbox = Gtk.GtkBoxLeaf(:h)
  push!(imgbox, makeImageWidget(tmpfn))
  push!(imgbox, makeImageWidget(reffn))

  win = Gtk.GtkWindowLeaf("Should we make this the new reference image?")
  push!(win, Gtk.GtkFrameLeaf(imgbox))

  showall(win)

  # now ask the question
  if Gtk.ask_dialog("Should we make this the new reference image?", "No", "Yes")
    replaceReferenceImage(tmpfn, reffn)
  end

  destroy(win)
end


# TODO: use julia's Condition type and the wait() and notify() functions to initialize a Window, then wait() on a condition that 
#       is referenced in a button press callback (the button clicked callback will call notify() on that condition)

function image_comparison_tests(pkg::Symbol, idx::Int; debug = false, sigma = [1,1], eps = 1e-2)
  
  # first 
  Plots._debugMode.on = debug
  info("Testing plot: $pkg:$idx:$(PlotExamples.examples[idx].header)")
  backend(pkg)
  backend()

  # ensure consistent results
  srand(1234)

  # run the example
  map(eval, PlotExamples.examples[idx].exprs)

  # save the png
  tmpfn = tempname() * ".png"
  png(tmpfn)

  # load the saved png
  tmpimg = Images.load(tmpfn)

  # reference image location
  refdir = joinpath(Pkg.dir("Plots"), "test", "refimg", string(pkg))
  try
    run(`mkdir -p $refdir`)
  catch err
    display(err)
  end
  reffn = joinpath(refdir, "ref$idx.png")

  try

    # info("Comparing $tmpfn to reference $reffn")
  
    # load the reference image
    refimg = Images.load(reffn)

    # run the comparison test... a difference will throw an error
    # NOTE: sigma is a 2-length vector with x/y values for the number of pixels
    #       to blur together when comparing images
    diffpct = Images.test_approx_eq_sigma_eps(tmpimg, refimg, sigma, eps)

    # we passed!
    info("Reference image $reffn matches.  Difference: $diffpct")
    return true

  catch err
    warn("Image did not match reference image $reffn. err: $err")
    # showerror(Base.STDERR, err)
    
    if isinteractive()

      # if we're in interactive mode, open a popup and give us a chance to examine the images
      warn("Should we make this the new reference image?")
      compareToReferenceImage(tmpfn, reffn)
      # println("exited")
      return
      
    else

      # if we rejected the image, or if we're in automated tests, throw the error
      rethrow(err)
    end

  end
end

function image_comparison_tests(pkg::Symbol; skip = [], debug = false, sigma = [1,1], eps = 1e-2)
  for i in 1:length(PlotExamples.examples)
    i in skip && continue
    @fact image_comparison_tests(pkg, i, debug=debug, sigma=sigma, eps=eps) --> true
  end
end
