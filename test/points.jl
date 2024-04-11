@testset "Points" begin
    # check our versions are correct
    @test LAS.lasversion_for_point(LasPoint0) == v"1.1"
    @test LAS.lasversion_for_point(LasPoint1) == v"1.1"
    @test LAS.lasversion_for_point(LasPoint2) == v"1.2"
    @test LAS.lasversion_for_point(LasPoint3) == v"1.2"
    @test LAS.lasversion_for_point(LasPoint4) == v"1.3"
    @test LAS.lasversion_for_point(LasPoint5) == v"1.3"
    @test LAS.lasversion_for_point(LasPoint6) == v"1.4"
    @test LAS.lasversion_for_point(LasPoint7) == v"1.4"
    @test LAS.lasversion_for_point(LasPoint8) == v"1.4"
    @test LAS.lasversion_for_point(LasPoint9) == v"1.4"
    @test LAS.lasversion_for_point(LasPoint10) == v"1.4"

    # make sure we have the right number of bytes
    @test LAS.byte_size(LasPoint0) == 20
    @test LAS.byte_size(LasPoint1) == 28
    @test LAS.byte_size(LasPoint2) == 26
    @test LAS.byte_size(LasPoint3) == 34
    @test LAS.byte_size(LasPoint4) == 57
    @test LAS.byte_size(LasPoint5) == 63
    @test LAS.byte_size(LasPoint6) == 30
    @test LAS.byte_size(LasPoint7) == 36
    @test LAS.byte_size(LasPoint8) == 38
    @test LAS.byte_size(LasPoint9) == 59
    @test LAS.byte_size(LasPoint10) == 67

    xyz = LAS.get_spatial_info([SVector{3, Float64}(0, 0, 0), SVector{3, Float64}(1, 1, 1)])

    p0_nt = (;
        position = SVector{3, Float64}(1.0, 2.0, 3.0), 
        intensity = N0f8(0.5), 
        returnnumber = 0x01, 
        numberofreturns = 0x02, 
        scan_direction = false, 
        edge_of_flight_line = false,
        classification = 1,
        synthetic = false,
        key_point = true,
        withheld = false,
        scan_angle = 1,
        user_data = 1,
        point_source_id = 1
    )
    p = LAS.laspoint(LasPoint0, p0_nt, xyz)
    @test p.x == 1.0/LAS.POINT_SCALE
    @test p.y == 2.0/LAS.POINT_SCALE
    @test p.z == 3.0/LAS.POINT_SCALE
    @test p.intensity == 0x8080
    @test p.flag_byte == 0x11
    @test p.raw_classification == 0x41
    @test p.scan_angle == 1
    @test p.user_data == 1
    @test p.pt_src_id == 1

    p1_nt = (;
        position = SVector{3, Float64}(1.0, 2.0, 3.0), 
        intensity = N0f8(0.5), 
        returnnumber = 0x05, 
        numberofreturns = 0x05, 
        scan_direction = true, 
        edge_of_flight_line = false,
        classification = 3,
        synthetic = true,
        key_point = false,
        withheld = true,
        scan_angle = 1,
        user_data = 1,
        point_source_id = 1,
        gps_time = 2.5
    )
    p = LAS.laspoint(LasPoint1, p1_nt, xyz)
    @test p.x == 1.0/LAS.POINT_SCALE
    @test p.y == 2.0/LAS.POINT_SCALE
    @test p.z == 3.0/LAS.POINT_SCALE
    @test p.intensity == 0x8080
    @test p.flag_byte == 0x6d
    @test p.raw_classification == 0xa3
    @test p.scan_angle == 1
    @test p.user_data == 1
    @test p.pt_src_id == 1
    @test p.gps_time == 2.5

    p2_nt = (;
        position = SVector{3, Float64}(1.0, 2.0, 3.0), 
        intensity = N0f8(0.5), 
        returnnumber = 0x05, 
        numberofreturns = 0x05, 
        scan_direction = true, 
        edge_of_flight_line = false,
        classification = 3,
        synthetic = true,
        key_point = false,
        withheld = true,
        scan_angle = 1,
        user_data = 1,
        point_source_id = 1,
        color = RGB(1, 0, 0.5)
    )
    p = LAS.laspoint(LasPoint2, p2_nt, xyz)
    @test p.x == 1.0/LAS.POINT_SCALE
    @test p.y == 2.0/LAS.POINT_SCALE
    @test p.z == 3.0/LAS.POINT_SCALE
    @test p.intensity == 0x8080
    @test p.flag_byte == 0x6d
    @test p.raw_classification == 0xa3
    @test p.scan_angle == 1
    @test p.user_data == 1
    @test p.pt_src_id == 1
    @test p.red == 0xffff
    @test p.green == 0x0000
    @test p.blue == 0x7fff

    p3_nt = (;
        position = SVector{3, Float64}(1.0, 2.0, 3.0), 
        intensity = N0f8(0.5), 
        returnnumber = 0x05, 
        numberofreturns = 0x05, 
        scan_direction = true, 
        edge_of_flight_line = false,
        classification = 3,
        synthetic = true,
        key_point = false,
        withheld = true,
        scan_angle = 1,
        user_data = 1,
        point_source_id = 1,
        gps_time = 2.5,
        color = RGB(1, 0, 0.5)
    )
    p = LAS.laspoint(LasPoint3, p3_nt, xyz)
    @test p.x == 1.0/LAS.POINT_SCALE
    @test p.y == 2.0/LAS.POINT_SCALE
    @test p.z == 3.0/LAS.POINT_SCALE
    @test p.intensity == 0x8080
    @test p.flag_byte == 0x6d
    @test p.raw_classification == 0xa3
    @test p.scan_angle == 1
    @test p.user_data == 1
    @test p.pt_src_id == 1
    @test p.red == 0xffff
    @test p.green == 0x0000
    @test p.blue == 0x7fff
    @test p.gps_time == 2.5
    
    # TODO: Add wavepacket info
    p4_nt = (;
        position = SVector{3, Float64}(1.0, 2.0, 3.0), 
        intensity = N0f8(0.5), 
        returnnumber = 0x05, 
        numberofreturns = 0x05, 
        scan_direction = true, 
        edge_of_flight_line = false,
        classification = 3,
        synthetic = true,
        key_point = false,
        withheld = true,
        scan_angle = 1,
        user_data = 1,
        point_source_id = 1,
        gps_time = 2.5
    )
    p = LAS.laspoint(LasPoint4, p4_nt, xyz)
    @test p.x == 1.0/LAS.POINT_SCALE
    @test p.y == 2.0/LAS.POINT_SCALE
    @test p.z == 3.0/LAS.POINT_SCALE
    @test p.intensity == 0x8080
    @test p.flag_byte == 0x6d
    @test p.raw_classification == 0xa3
    @test p.scan_angle == 1
    @test p.user_data == 1
    @test p.pt_src_id == 1
    @test p.gps_time == 2.5
    @test p.wave_packet_descriptor_index == 0
    @test p.wave_packet_byte_offset == 0
    @test p.wave_packet_size_in_bytes == 0
    @test p.wave_return_location == 0
    @test p.wave_x_t == 0
    @test p.wave_y_t == 0
    @test p.wave_z_t == 0

    p5_nt = (;
        position = SVector{3, Float64}(1.0, 2.0, 3.0), 
        intensity = N0f8(0.5), 
        returnnumber = 0x05, 
        numberofreturns = 0x05, 
        scan_direction = true, 
        edge_of_flight_line = false,
        classification = 3,
        synthetic = true,
        key_point = false,
        withheld = true,
        scan_angle = 1,
        user_data = 1,
        point_source_id = 1,
        gps_time = 2.5,
        color = RGB(1, 0, 0.5)
    )
    p = LAS.laspoint(LasPoint5, p5_nt, xyz)
    @test p.x == 1.0/LAS.POINT_SCALE
    @test p.y == 2.0/LAS.POINT_SCALE
    @test p.z == 3.0/LAS.POINT_SCALE
    @test p.intensity == 0x8080
    @test p.flag_byte == 0x6d
    @test p.raw_classification == 0xa3
    @test p.scan_angle == 1
    @test p.user_data == 1
    @test p.pt_src_id == 1
    @test p.red == 0xffff
    @test p.green == 0x0000
    @test p.blue == 0x7fff
    @test p.gps_time == 2.5
    @test p.wave_packet_descriptor_index == 0
    @test p.wave_packet_byte_offset == 0
    @test p.wave_packet_size_in_bytes == 0
    @test p.wave_return_location == 0
    @test p.wave_x_t == 0
    @test p.wave_y_t == 0
    @test p.wave_z_t == 0

    p6_nt = (;
        position = SVector{3, Float64}(1.0, 2.0, 3.0), 
        intensity = N0f8(0.5), 
        returnnumber = 0x0a, 
        numberofreturns = 0x0f, 
        scan_direction = true, 
        edge_of_flight_line = false,
        classification = 3,
        synthetic = false,
        key_point = true,
        withheld = false,
        overlap = true,
        scanner_channel = 0x01,
        scan_angle = 35,
        user_data = 0,
        point_source_id = 4,
        gps_time = 2.5
    )
    p = LAS.laspoint(LasPoint6, p6_nt, xyz)
    @test p.x == 1.0/LAS.POINT_SCALE
    @test p.y == 2.0/LAS.POINT_SCALE
    @test p.z == 3.0/LAS.POINT_SCALE
    @test p.intensity == 0x8080
    @test p.flag_byte_1 == 0xfa
    @test p.flag_byte_2 == 0x5a
    @test p.classification == 3
    @test p.user_data == 0
    @test p.scan_angle == 5833
    @test p.pt_src_id == 4
    @test p.gps_time == 2.5

    p7_nt = (;
        position = SVector{3, Float64}(1.0, 2.0, 3.0), 
        intensity = N0f8(0.5), 
        returnnumber = 0x0a, 
        numberofreturns = 0x0f, 
        scan_direction = true, 
        edge_of_flight_line = false,
        classification = 3,
        synthetic = false,
        key_point = true,
        withheld = false,
        overlap = true,
        scanner_channel = 0x01,
        scan_angle = 35,
        user_data = 0,
        point_source_id = 4,
        gps_time = 2.5,
        color = RGB(0.1, 0.2, 0.6)
    )
    p = LAS.laspoint(LasPoint7, p7_nt, xyz)
    @test p.x == 1.0/LAS.POINT_SCALE
    @test p.y == 2.0/LAS.POINT_SCALE
    @test p.z == 3.0/LAS.POINT_SCALE
    @test p.intensity == 0x8080
    @test p.flag_byte_1 == 0xfa
    @test p.flag_byte_2 == 0x5a
    @test p.classification == 3
    @test p.user_data == 0
    @test p.scan_angle == 5833
    @test p.pt_src_id == 4
    @test p.gps_time == 2.5
    @test p.red == 0x1999
    @test p.green == 0x3333
    @test p.blue == 0x9999

    p8_nt = (;
        position = SVector{3, Float64}(1.0, 2.0, 3.0), 
        intensity = N0f8(0.5), 
        returnnumber = 0x0a, 
        numberofreturns = 0x0f, 
        scan_direction = true, 
        edge_of_flight_line = false,
        classification = 3,
        synthetic = false,
        key_point = true,
        withheld = false,
        overlap = true,
        scanner_channel = 0x01,
        scan_angle = 35,
        user_data = 0,
        point_source_id = 4,
        gps_time = 2.5,
        color = RGB(0.1, 0.2, 0.6),
        nir = N0f8(0.8)
    )
    p = LAS.laspoint(LasPoint8, p8_nt, xyz)
    @test p.x == 1.0/LAS.POINT_SCALE
    @test p.y == 2.0/LAS.POINT_SCALE
    @test p.z == 3.0/LAS.POINT_SCALE
    @test p.intensity == 0x8080
    @test p.flag_byte_1 == 0xfa
    @test p.flag_byte_2 == 0x5a
    @test p.classification == 3
    @test p.user_data == 0
    @test p.scan_angle == 5833
    @test p.pt_src_id == 4
    @test p.gps_time == 2.5
    @test p.red == 0x1999
    @test p.green == 0x3333
    @test p.blue == 0x9999
    @test p.nir == 0xcccc

    p9_nt = (;
        position = SVector{3, Float64}(1.0, 2.0, 3.0), 
        intensity = N0f8(0.5), 
        returnnumber = 0x0a, 
        numberofreturns = 0x0f, 
        scan_direction = true, 
        edge_of_flight_line = false,
        classification = 3,
        synthetic = false,
        key_point = true,
        withheld = false,
        overlap = true,
        scanner_channel = 0x01,
        scan_angle = 35,
        user_data = 0,
        point_source_id = 4,
        gps_time = 2.5
    )
    p = LAS.laspoint(LasPoint9, p9_nt, xyz)
    @test p.x == 1.0/LAS.POINT_SCALE
    @test p.y == 2.0/LAS.POINT_SCALE
    @test p.z == 3.0/LAS.POINT_SCALE
    @test p.intensity == 0x8080
    @test p.flag_byte_1 == 0xfa
    @test p.flag_byte_2 == 0x5a
    @test p.classification == 3
    @test p.user_data == 0
    @test p.scan_angle == 5833
    @test p.pt_src_id == 4
    @test p.gps_time == 2.5
    @test p.wave_packet_descriptor_index == 0
    @test p.wave_packet_byte_offset == 0
    @test p.wave_packet_size_in_bytes == 0
    @test p.wave_return_location == 0
    @test p.wave_x_t == 0
    @test p.wave_y_t == 0
    @test p.wave_z_t == 0

    p10_nt = (;
        position = SVector{3, Float64}(1.0, 2.0, 3.0), 
        intensity = N0f8(0.5), 
        returnnumber = 0x0a, 
        numberofreturns = 0x0f, 
        scan_direction = true, 
        edge_of_flight_line = false,
        classification = 3,
        synthetic = false,
        key_point = true,
        withheld = false,
        overlap = true,
        scanner_channel = 0x01,
        scan_angle = 35,
        user_data = 0,
        point_source_id = 4,
        gps_time = 2.5,
        color = RGB(0.1, 0.2, 0.6),
        nir = N0f8(0.8)
    )
    p = LAS.laspoint(LasPoint10, p10_nt, xyz)
    @test p.x == 1.0/LAS.POINT_SCALE
    @test p.y == 2.0/LAS.POINT_SCALE
    @test p.z == 3.0/LAS.POINT_SCALE
    @test p.intensity == 0x8080
    @test p.flag_byte_1 == 0xfa
    @test p.flag_byte_2 == 0x5a
    @test p.classification == 3
    @test p.user_data == 0
    @test p.scan_angle == 5833
    @test p.pt_src_id == 4
    @test p.gps_time == 2.5
    @test p.wave_packet_descriptor_index == 0
    @test p.wave_packet_byte_offset == 0
    @test p.wave_packet_size_in_bytes == 0
    @test p.wave_return_location == 0
    @test p.wave_x_t == 0
    @test p.wave_y_t == 0
    @test p.wave_z_t == 0
    @test p.red == 0x1999
    @test p.green == 0x3333
    @test p.blue == 0x9999
    @test p.nir == 0xcccc
end

"Find the centroid of all points in a LAS file"
function centroid(io, header)
    x_sum = 0.0
    y_sum = 0.0
    z_sum = 0.0
    n = number_of_points(header)

    for _ = 1:n
        p = read(io, LasPoint0)
        x = xcoord(p, header)
        y = ycoord(p, header)
        z = zcoord(p, header)

        x_sum += x
        y_sum += y
        z_sum += z
    end

    x_avg = x_sum / n
    y_avg = y_sum / n
    z_avg = z_sum / n

    x_avg, y_avg, z_avg
end

@testset "Points From File" begin
    # reading point by point
    open(joinpath(@__DIR__, "test_files/libLAS_1.2.las")) do io
        header = read(io, LasHeader)

        seek(io, header.data_offset)
        x_avg, y_avg, z_avg = centroid(io, header)

        @test x_avg ≈ 1442694.2739025319
        @test y_avg ≈ 377449.24373880465
        @test z_avg ≈ 861.60254888088491

        seek(io, header.data_offset)
        p = read(io, LasPoint0)

        @test xcoord(p, header) ≈ 1.44013394e6
        @test xcoord(1.44013394e6, header) ≈ p.x
        @test ycoord(p, header) ≈ 375000.23
        @test ycoord(375000.23, header) ≈ p.y
        @test zcoord(p, header) ≈ 846.66
        @test zcoord(846.66, header) ≈ p.z
        @test get_integer_intensity(p) === 0x00fa
        @test scan_angle(p) === 0.0
        @test user_data(p) === 0x00
        @test point_source_id(p) === 0x001d
        @test return_number(p) === 0x00
        @test number_of_returns(p) === 0x00
        @test scan_direction(p) === false
        @test edge_of_flight_line(p) === false
        @test classification(p) === 0x02
        @test synthetic(p) === false
        @test key_point(p) === false
        @test withheld(p) === false

        # raw bytes composed of bit fields
        @test flag_byte(p) === 0x00
        @test p.raw_classification === 0x02

        # recompose bytes with bit fields
        @test flag_byte(return_number(p),number_of_returns(p),scan_direction(p),edge_of_flight_line(p)) === p.flag_byte
        @test raw_classification(classification(p),synthetic(p),key_point(p),withheld(p)) === p.raw_classification

        # TODO GPS time, colors (not in this test file, is point data format 0)
    end
end
