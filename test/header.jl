@testset "LAS Header" begin

    header = LasHeader(;
        las_version = v"1.4",
        creation_dayofyear = UInt16(100),
        creation_year = UInt16(2024),
        data_format_id = 0x01,
        data_record_length = UInt16(28),
        record_count = UInt64(100)
    )

    # make sure we can get and set properties ok
    @test las_version(header) == v"1.4"
    @test system_id(header) == "OTHER"
    @test software_id(header) == LAS.software_version()
    @test creation_day_of_year(header) == UInt16(100)
    @test creation_year(header) == UInt16(2024)
    
    @test point_data_offset(header) == UInt32(375)
    set_point_data_offset!(header, 376)
    @test point_data_offset(header) == UInt32(376)
    @test point_record_length(header) == UInt16(28)
    set_point_record_length!(header, 30)
    @test point_record_length(header) == UInt16(30)
    @test record_format(header) == LasRecord{LasPoint1, 2}
    @test point_format(header) == LasPoint1
    @test number_of_points(header) == 100
    set_point_record_count!(header, 150)
    @test number_of_points(header) == 150
    
    @test number_of_vlrs(header) == 0
    set_num_vlr!(header, 2)
    @test number_of_vlrs(header) == 2
    @test number_of_evlrs(header) == 0
    set_num_evlr!(header, 1)
    @test number_of_evlrs(header) == 1

    @test num_return_channels(header) == 15
    @test get_number_of_points_by_return(header) == Tuple(zeros(Int, 15))
    points_per_return = ntuple(i -> 10, 15)
    set_number_of_points_by_return!(header, points_per_return)
    @test get_number_of_points_by_return(header) == points_per_return

    xyz = SpatialInfo(AxisInfo(0.01, 0.01, 0.01), AxisInfo(0.0, 0.0, 0.0), AxisInfo(Range(1.0, 0.0), Range(5.0, -5.0), Range(10.0, 0.0)))
    set_spatial_info!(header, xyz)
    @test spatial_info(header) == xyz

    # setting and unsetting global encoding flags
    @test !is_standard_gps(header)
    set_gps_standard_time_bit!(header)
    @test is_standard_gps(header)
    set_gps_week_time_bit!(header)
    @test !is_standard_gps(header)
    @test !is_wkt(header)
    set_wkt_bit!(header)
    @test is_wkt(header)
    unset_wkt_bit!(header)
    @test !is_wkt(header)

    @test !is_internal_waveform(header)
    @test is_external_waveform(header)
    set_waveform_internal_bit!(header)
    @test is_internal_waveform(header)
    @test !is_external_waveform(header)
    set_waveform_external_bit!(header)
    @test !is_internal_waveform(header)
    @test is_external_waveform(header)

    # test I/O
    header = open(joinpath(@__DIR__, "test_files/libLAS_1.2.las")) do io
        read(io, LasHeader)
    end

    @test system_id(header) == "MODIFICATION"
    @test software_id(header) == "TerraScan"
    @test header_size(header) == 227
    @test point_data_offset(header) == 227
    @test point_record_length(header) == 20
    @test point_format(header) == LasPoint0
    @test record_format(header) == LasRecord{LasPoint0, 0}
    @test number_of_points(header) == 497536
    @test number_of_vlrs(header) == 0
    @test number_of_evlrs(header) == 0

    xyz = spatial_info(header)
    @test xyz.offset == AxisInfo(0.0, 0.0, 0.0)
    @test xyz.scale == AxisInfo(0.01, 0.01, 0.01)
    @test xyz.range.x ≈ Range(1444999.96, 1440000.00)
    @test xyz.range.y ≈ Range(379999.99, 375000.03)
    @test xyz.range.z ≈ Range(972.67, 832.18)

    points_per_return = get_number_of_points_by_return(header)
    @test points_per_return[1] == 497536
    @test all(points_per_return[2:end] .== 0)
    

    # # make sure if we write it we get the same thing back
    io = IOBuffer()
    write(io, header)
    seek(io, 0)
    loaded_header = read(io, LasHeader)
    @test loaded_header == header
end