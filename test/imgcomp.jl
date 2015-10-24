
# macro test_approx_eq_sigma_eps(A, B, sigma, eps)

include("../docs/example_generation.jl")


# # make and display one plot
# function test_examples(pkg::Symbol, idx::Int; debug = true)
#   Plots._debugMode.on = debug
#   println("Testing plot: $pkg:$idx:$(examples[idx].header)")
#   backend(pkg)
#   backend()
#   map(eval, examples[idx].exprs)
#   plt = current()
#   gui(plt)
#   plt
# end

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
  @eval import Gtk

  # add the images
  imgbox = Gtk.GtkBoxLeaf(:h)
  push!(imgbox, makeImageWidget(tmpfn))
  push!(imgbox, makeImageWidget(reffn))

  # add the buttons
  doNothingButton = Gtk.GtkButtonLeaf("Skip")
  replaceReferenceButton = Gtk.GtkButtonLeaf("Replace reference image")
  btnbox = Gtk.GtkButtonBoxLeaf(:h)
  push!(btnbox, doNothingButton)
  push!(btnbox, replaceReferenceButton)

  # create the window
  box = Gtk.GtkBoxLeaf(:v)
  push!(box, imgbox)
  push!(box, btnbox)
  win = Gtk.GtkWindowLeaf("Should we make this the new reference image?")
  push!(win, Gtk.GtkFrameLeaf(box))

  # we'll wait on this condition
  c = Condition()
  Gtk.on_signal_destroy((x...) -> notify(c), win)

  Gtk.signal_connect(replaceReferenceButton, "clicked") do widget
    replaceReferenceImage(tmpfn, reffn)
    notify(c)
  end

  Gtk.signal_connect(doNothingButton, "clicked") do widget
    notify(c)
  end

  # wait until a button is clicked, then close the window
  Gtk.showall(win)
  wait(c)
  Gtk.destroy(win)
end


# TODO: use julia's Condition type and the wait() and notify() functions to initialize a Window, then wait() on a condition that 
#       is referenced in a button press callback (the button clicked callback will call notify() on that condition)

function image_comparison_tests(pkg::Symbol, idx::Int; debug = false, sigma = [1,1], eps = 1e-3)
  
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
  refdir = joinpath(Pkg.dir("Plots"), "test", "refimg", "v$(VERSION.major).$(VERSION.minor)", string(pkg))
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
    Images.test_approx_eq_sigma_eps(tmpimg, refimg, sigma, eps)

    # we passed!
    info("Reference image $reffn matches")
    return true

  catch ex
    warn("Image did not match reference image $reffn. err: $ex")
    if isinteractive()

      # if we're in interactive mode, open a popup and give us a chance to examine the images
      warn("Should we make this the new reference image?")
      compareToReferenceImage(tmpfn, reffn)
      return
      
    else

      # if we rejected the image, or if we're in automated tests, throw the error
      rethrow(ex)
    end

  end
end

function image_comparison_tests(pkg::Symbol; skip = [], debug = false, sigma = [1,1], eps = 1e-3)
  for i in 1:length(PlotExamples.examples)
    i in skip && continue
    @fact image_comparison_tests(pkg, i, debug=debug, sigma=sigma, eps=eps) --> true
  end
end
