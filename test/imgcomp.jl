
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

using Plots, Gtk.ShortNames

function makeImageWidget(fn)
  img = @Image(fn)
  vbox = @Box(:v)
  push!(vbox, img)
  show(img)
  vbox
end

"Show a Gtk popup with both images and a confirmation whether we should replace the new image with the old one"
function isTempImageCorrect(tmpfn, reffn)

  # add the images
  imgbox = @Box(:h)
  push!(imgbox, makeImageWidget(tmpfn))
  push!(imgbox, makeImageWidget(reffn))

  # add the buttons
  keepbtn = @Button("KEEP")
  overwritebtn = @Button("OVERWRITE")
  btnbox = @Box(:h)
  push!(btnbox, keepbtn)
  push!(btnbox, overwritebtn)

  # create the window
  box = @Box(:v)
  push!(box, imgbox)
  push!(box, btnbox)
  w = @Window(@Frame(box))
  showall(w)
  w
end


function image_comparison_tests(pkg::Symbol, idx::Int; debug = true, sigma = [0,0], eps = 1e-3)
  
  # first 
  Plots._debugMode.on = debug
  info("Testing plot: $pkg:$idx:$(examples[idx].header)")
  backend(pkg)
  backend()
  map(eval, PlotExamples.examples[idx].exprs)

  # save the png
  tmpfn = tempname() * ".png"
  png(tmpfn)

  # load the saved png
  tmpimg = imread(tmpfn)

  # load the reference image
  reffn = joinpath(Pkg.dir("Plots"), "test", "refimg", pkg, "$idx.png")
  refimg = imread(reffn)

  # run the test
  # NOTE: sigma is a 2-length vector with x/y values for the number of pixels
  #       to blur together when comparing images
  try

    # run the comparison test... a difference will throw an error
    @test_approx_eq_sigma_eps(tmpimg, refimg, sigma, eps)

  catch ex
    if isinteractive()

      # if we're in interactive mode, open a popup and give us a chance to examine the images
      if isTempImageCorrect(tmpfn, reffn)
        return
      end
    end

    # if we rejected the image, or if we're in automated tests, throw the error
    throw(ex)
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
