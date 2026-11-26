@testset "Spatial Info" begin
    io = IOBuffer()

    # check equalities and I/O
    x = AxisInfo(1.0, 2.0, 3.0)
    @test x == AxisInfo(1.0f0, 2.0f0, 3.0f0)
    write(io, x)
    seek(io, 0)
    out = read(io, AxisInfo{Float64})
    @test out == x

    @test_throws AssertionError Range(0, 1)
    r = Range(1.0, 0.0)
    @test r.min ∈ r
    @test r.max ∈ r
    @test 0.5 ∈ r
    @test -0.5 ∉ r
    seek(io, 0)
    write(io, r)
    seek(io, 0)
    out = read(io, Range{Float64})
    @test out == r

    # points arranged in a 1m cube
    ps = [
        SVector{3, Float64}(0.0, 0.0, 0.0),
        SVector{3, Float64}(1.0, 0.0, 0.0),
        SVector{3, Float64}(1.0, 1.0, 0.0),
        SVector{3, Float64}(0.0, 1.0, 0.0),
        SVector{3, Float64}(0.0, 0.0, 1.0),
        SVector{3, Float64}(1.0, 0.0, 1.0),
        SVector{3, Float64}(1.0, 1.0, 1.0),
        SVector{3, Float64}(0.0, 1.0, 1.0)
    ]

    xyz = LASDatasets.get_spatial_info(ps)

    # all our points should be contained in the bounding box
    for p ∈ ps
        @test p.x ∈ xyz.range.x
        @test p.y ∈ xyz.range.y
        @test p.z ∈ xyz.range.z
    end

    seek(io, 0)
    write(io, xyz)
    seek(io, 0)
    out = read(io, SpatialInfo)
    @test out == xyz

    # bounds within half a scale step of zero shouldn't be mistaken for overflow
    @test LASDatasets.determine_offset(-249.99998612145566, 1.3878544336876075e-5, 0.001) == 0.0
    @test LASDatasets.determine_offset(-1.0e-5, 250.0, 0.001) == 0.0
    near_zero = [SVector{3, Float64}(-250.0, 0.0, 0.0), SVector{3, Float64}(1.0e-5, 1.0, 1.0)]
    @test LASDatasets.get_spatial_info(near_zero) isa SpatialInfo

    # genuine overflows should still be caught
    @test_throws ErrorException LASDatasets.determine_offset(0.0, 1.0e7, 0.001)
    @test_throws ErrorException LASDatasets.determine_offset(-1.0e7, 0.0, 0.001)
end