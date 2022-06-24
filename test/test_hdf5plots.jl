using HDF5

@testset "HDF5_Plots" begin
    fname = "tmpplotsave.hdf5"
    hdf5()

    x = 1:10
    psrc = plot(x, x .* x) #Create some plot
    Plots.hdf5plot_write(psrc, fname)

    # read back file
    gr() # choose some fast backend likely to work in test environment.
    pread = Plots.hdf5plot_read(fname)

    # make sure data made it through
    @test psrc.subplots[1].series_list[1][:x] == pread.subplots[1].series_list[1][:x]
    @test psrc.subplots[1].series_list[1][:y] == pread.subplots[1].series_list[1][:y]

    # display(pread)  # don't display. Regression env might not support
end
