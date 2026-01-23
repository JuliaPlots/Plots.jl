@testset "HDF5_Plots" begin
    fname = tempname() * ".hdf5"
    hdf5()

    x = 1:10
    pl = plot(x, x .^ 2)  # create some plot
    Plots.hdf5plot_write(pl, fname)

    # read back file
    gr()  # choose some fast backend likely to work in test environment
    pread = Plots.hdf5plot_read(fname)

    # make sure data made it through
    @test pl.subplots[1].series_list[1][:x] == pread.subplots[1].series_list[1][:x]
    @test pl.subplots[1].series_list[1][:y] == pread.subplots[1].series_list[1][:y]

    ex = pl.subplots[1][:xaxis][:extrema]
    @test (ex.emin, ex.emax) == (1, 10)

    ex = pl.subplots[1][:yaxis][:extrema]
    @test (ex.emin, ex.emax) == (1, 100)

    # display(pread)  # don't display. Regression env might not support
end
