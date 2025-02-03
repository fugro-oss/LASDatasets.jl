@testset "LAS Dataset" begin
    num_points = 100
    pc = Table(
        position = rand(SVector{3, Float64}, num_points),
        classification = rand(UInt8, num_points),
        gps_time = rand(num_points)
    )
    header = LasHeader(;
        data_format_id = 0x00,
        data_record_length = UInt16(LASDatasets.byte_size(LasPoint0)),
        record_count = UInt64(num_points),
        point_return_count = (UInt64(num_points), zeros(UInt64, 14)...)
    )

    # should error if our point format in the point cloud is incompatible with the one in the header
    @test_throws AssertionError LASDataset(header, pc, LasVariableLengthRecord[], LasVariableLengthRecord[], UInt8[])
    set_point_format!(header, 1)
    set_point_record_length!(header, LASDatasets.byte_size(LasPoint1))

    # number of points needs to match
    set_point_record_count!(header, num_points + 1)
    @test_throws AssertionError LASDataset(header, pc, LasVariableLengthRecord[], LasVariableLengthRecord[], UInt8[])
    set_point_record_count!(header, num_points)

    # same for number of VLRs/EVLRs
    set_num_vlr!(header, 1)
    @test_throws AssertionError LASDataset(header, pc, LasVariableLengthRecord[], LasVariableLengthRecord[], UInt8[])
    set_num_vlr!(header, 0)
    set_num_evlr!(header, 1)
    @test_throws AssertionError LASDataset(header, pc, LasVariableLengthRecord[], LasVariableLengthRecord[], UInt8[])
    set_num_evlr!(header, 0)

    las = LASDataset(header, pc, LasVariableLengthRecord[], LasVariableLengthRecord[], UInt8[])
    this_pc = get_pointcloud(las)
    @test length(this_pc) == num_points
    # check we add an ID column to the pointcloud
    @test :id ∈ columnnames(this_pc)
    @test all(map(col -> col ∈ columnnames(this_pc), columnnames(pc)))

    # make sure the header matches
    this_header = get_header(las)
    @test this_header == header

    # check equality if we create two of the same dataset
    other_las = LASDataset(deepcopy(header), deepcopy(pc), LasVariableLengthRecord[], LasVariableLengthRecord[], UInt8[])
    @test other_las == las

    # test constructor with pc Only
    h = LasHeader(; las_version = v"1.1", data_format_id = UInt8(1), data_record_length = UInt16(28))
    LASDatasets.make_consistent_header!(h, pc, LasVariableLengthRecord[], LasVariableLengthRecord[], UInt8[])
    las = LASDataset(h, pc, LasVariableLengthRecord[], LasVariableLengthRecord[], UInt8[])
    @test las == LASDataset(deepcopy(pc))
    
    # now try incorporating some user fields
    spicy_pc = Table(pc, thing = rand(num_points), other_thing = rand(Int16, num_points))
    las = LASDataset(header, spicy_pc, LasVariableLengthRecord[], LasVariableLengthRecord[], UInt8[])
    # make sure our record length reflects the user fields
    this_header = get_header(las)
    @test point_record_length(this_header) == LASDatasets.byte_size(LasPoint1) + 10
    # our user fields should be populated in the dataset
    @test sort(collect(columnnames(las.pointcloud))) == [:classification, :gps_time, :id, :other_thing, :position, :thing]
    this_pc = get_pointcloud(las)
    @test this_pc.thing == spicy_pc.thing
    @test this_pc.other_thing == spicy_pc.other_thing
    # we should have documented our columns as extra bytes VLRs now
    vlrs = get_vlrs(las)
    @test length(vlrs) == 1
    vlr_data = get_data.(vlrs)
    @test  vlr_data[1] isa ExtraBytesCollection
    extra_bytes = LASDatasets.get_extra_bytes(vlr_data[1])
    @test (LASDatasets.name(extra_bytes[1]) == "thing") && (LASDatasets.data_type(extra_bytes[1]) == Float64)
    @test (LASDatasets.name(extra_bytes[2]) == "other_thing") && (LASDatasets.data_type(extra_bytes[2]) == Int16)
    # and our header should be updated appropriately
    @test number_of_vlrs(header) == 1
    @test point_data_offset(header) == header_size(header) + sum(sizeof.(vlrs))
    # now add another user field directly to the dataset
    new_thing = rand(Float32, num_points)
    add_column!(las, :new_thing, new_thing)
    vlrs = get_vlrs(las)
    @test length(vlrs) == 1
    new_extra_bytes = LASDatasets.get_extra_bytes(get_data(vlrs[1]))[3]
    @test (LASDatasets.name(new_extra_bytes) == "new_thing") && (LASDatasets.data_type(new_extra_bytes) == Float32)
    # we shouldn't be able to add columns of different length to the LAS data
    @test_throws AssertionError add_column!(las, :bad, rand(10))
    # now if we replace the values of one of the user fields with a different type, it should work
    new_thing = rand(UInt8, num_points)
    add_column!(las, :thing, new_thing)
    vlrs = get_vlrs(las)
    @test length(vlrs) == 1
    new_extra_bytes = LASDatasets.get_extra_bytes(get_data(vlrs[1]))[3]
    @test (LASDatasets.name(new_extra_bytes) == "thing") && (LASDatasets.data_type(new_extra_bytes) == UInt8)

    # merge some data into our dataset
    new_classifications = rand(5:8, num_points)
    merge_column!(las, :classification, new_classifications)
    @test get_pointcloud(las).classification == new_classifications

    # now check we can modify VLRs correctly
    desc = LasVariableLengthRecord(
        LASDatasets.LAS_SPEC_USER_ID, 
        LASDatasets.ID_TEXTDESCRIPTION, 
        "Text Area Description", 
        TextAreaDescription("This is a LAS dataset captured from somewhere idk")
    )
    add_vlr!(las, desc)
    vlrs = get_vlrs(las)
    @test length(vlrs) == 2
    @test vlrs[2] == desc
    # make sure we've updated the header correctly
    header = get_header(las)
    @test number_of_vlrs(header) == 2
    @test point_data_offset(header) == header_size(header) + sum(sizeof.(vlrs))
    # now let's replace this description for another one
    new_desc = LasVariableLengthRecord(
        LASDatasets.LAS_SPEC_USER_ID, 
        LASDatasets.ID_TEXTDESCRIPTION, 
        "Text Area Description", 
        TextAreaDescription("This is the new dataset description")
    )
    # mark the old one as superseded
    set_superseded!(las, desc)
    # and add the new one
    add_vlr!(las, new_desc)
    
    vlrs = get_vlrs(las)
    @test length(vlrs) == 3
    @test vlrs[3] == new_desc
    superseded_desc = vlrs[2]
    @test get_user_id(superseded_desc) == get_user_id(desc)
    @test get_record_id(superseded_desc) == LASDatasets.ID_SUPERSEDED
    @test get_description(superseded_desc) == get_description(desc)
    @test get_data(superseded_desc) == get_data(desc)
    @test is_extended(superseded_desc) == is_extended(desc)
    # we can also remove the old one entirely
    remove_vlr!(las, superseded_desc)
    vlrs = get_vlrs(las)
    @test length(vlrs) == 2
    @test vlrs[2] == new_desc
    @test number_of_vlrs(get_header(las)) == 2

    # this stuff should also work for EVLRs
    struct Comment
        str::String
    end
    Base.:(==)(c1::Comment, c2::Comment) = (c1.str == c2.str)
    @register_vlr_type Comment "Comment" 100
    long_comment = LasVariableLengthRecord("Comment", 100, "This is a long comment", Comment(String(rand(UInt8, 2^8))), true)
    add_vlr!(las, long_comment)
    header = get_header(las)
    # vlrs should stay the same
    @test length(get_vlrs(las)) == 2
    @test number_of_vlrs(header) == 2
    # should have updated the EVLRs
    evlrs = get_evlrs(las)
    @test length(evlrs) == 1
    @test number_of_evlrs(header) == 1
    @test evlrs[1] == long_comment
    # make sure the offset makes sense
    @test evlr_start(header) == point_data_offset(header) + (number_of_points(header) * point_record_length(header))
    # we can add a new comment on top of this one
    new_commment = LasVariableLengthRecord("Comment", 100, "This is a new comment", Comment(String(rand(UInt8, 2^8))), true)
    add_vlr!(las, new_commment)
    @test number_of_evlrs(get_header(las)) == 2
    @test length(get_evlrs(las)) == 2
    # and mark the original one as superseded
    set_superseded!(las, long_comment)
    evlrs = get_evlrs(las)
    @test length(evlrs) == 2
    superseded_comment = evlrs[1]
    @test get_user_id(superseded_comment) == get_user_id(long_comment)
    @test get_record_id(superseded_comment) == LASDatasets.ID_SUPERSEDED
    @test get_description(superseded_comment) == get_description(long_comment)
    @test get_data(superseded_comment) == get_data(long_comment)
    @test is_extended(superseded_comment) == is_extended(long_comment)
    # if we add a regular VLR, we should update the offset to the first EVLR correctly
    short_comment = LasVariableLengthRecord("Comment", 100, "This is a long comment", Comment(String(rand(UInt8, 10))))
    add_vlr!(las, short_comment)
    @test evlr_start(header) == point_data_offset(header) + (number_of_points(header) * point_record_length(header))
    # and similarly if we add column data it should update properly
    add_column!(las, :another_column, rand(UInt8, num_points))
    @test evlr_start(header) == point_data_offset(header) + (number_of_points(header) * point_record_length(header))
    # and finally we can remove it
    remove_vlr!(las, superseded_comment)
    @test number_of_evlrs(get_header(las)) == 1
    @test get_evlrs(las) == [new_commment]

    # test modifying point formats and versions
    las = LASDataset(pc)
    # if we add a LAS column that isn't covered by the current format, the point format (and possibly LAS version) should be updated in the header
    add_column!(las, :overlap, falses(length(pc)))
    @test point_format(get_header(las)) == LasPoint6
    @test las_version(get_header(las)) == v"1.4"
    # we should be able to add new points in too
    new_points = Table(
        id = (length(pc) + 1):(length(pc) + 10),
        position = rand(SVector{3, Float64}, 10),
        classification = rand(UInt8, 10),
        gps_time = rand(10),
        overlap = falses(10)
    )
    add_points!(las, new_points)
    pointcloud = get_pointcloud(las)
    # check the point contents to make sure our new points are there
    @test length(pointcloud) == 110
    # equality checks are annoying when the column order gets switched internally, so check each column individually
    for col ∈ columnnames(new_points)
        @test getproperty(pointcloud, col)[101:end] == getproperty(new_points, col)
    end
    orig_pc = deepcopy(pointcloud)
    # also make sure our header information is correctly set
    @test number_of_points(las) == 110
    @test spatial_info(las) == LASDatasets.get_spatial_info(pointcloud)

    # we can also delete these points if we want
    remove_points!(las, 101:110)
    @test number_of_points(las) == 100
    pc = get_pointcloud(las)
    for col ∈ columnnames(pc)
        @test getproperty(pc, col) == getproperty(orig_pc, col)[1:100]
    end
    
end