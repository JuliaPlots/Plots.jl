
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

using Plots
import Images, Gtk, ImageMagick

function makeImageWidget(fn)
  img = Gtk.GtkImageLeaf(fn)
  vbox = Gtk.GtkBoxLeaf(:v)
  push!(vbox, Gtk.GtkLabelLeaf(fn))
  push!(vbox, img)
  show(img)
  vbox
end

function replaceReferenceImage(tmpfn, reffn)
  println("cp $tmpfn $reffn")
end

"Show a Gtk popup with both images and a confirmation whether we should replace the new image with the old one"
function compareToReferenceImage(tmpfn, reffn)

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
  win = Gtk.GtkWindowLeaf(Gtk.GtkFrameLeaf(box))

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

function image_comparison_tests(pkg::Symbol, idx::Int; debug = true, sigma = [0,0], eps = 1e-3)
  
  # first 
  Plots._debugMode.on = debug
  info("Testing plot: $pkg:$idx:$(PlotExamples.examples[idx].header)")
  backend(pkg)
  backend()

  info("here: ", PlotExamples.examples[idx].exprs)
  map(eval, PlotExamples.examples[idx].exprs)

  # save the png
  tmpfn = tempname() * ".png"
  png(tmpfn)

  # load the saved png
  tmpimg = Images.load(tmpfn)

  # reference image location
  refdir = joinpath(Pkg.dir("Plots"), "test", "refimg", "v$(VERSION.major).$(VERSION.minor)", string(pkg))
  try
    mkdir(refdir)
  catch err
    display(err)
  end
  reffn = joinpath(refdir, "ref$idx.png")

  try

    info("Comparing $tmpfn to reference $reffn")
  
    # load the reference image
    refimg = Images.load(reffn)

    # run the comparison test... a difference will throw an error
    # NOTE: sigma is a 2-length vector with x/y values for the number of pixels
    #       to blur together when comparing images
    Images.@test_approx_eq_sigma_eps(tmpimg, refimg, sigma, eps)

  catch ex
    if isinteractive()

      # if we're in interactive mode, open a popup and give us a chance to examine the images
      compareToReferenceImage(tmpfn, reffn)
      return
      
    else

      # if we rejected the image, or if we're in automated tests, throw the error
      rethrow(ex)
    end

  end
end

function image_comparison_tests(pkg::Symbol; debug = false)
  for i in 1:length(PlotExamples.examples)
    # try
    image_comparison_tests(pkgname, i, debug=debug)
    # catch ex
    #   # TODO: put error info into markdown?
    #   warn("Example $pkgname:$i:$(examples[i].header) failed with: $ex")
    # end
  end
end
