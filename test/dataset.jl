@testset "LAS Content" begin
    num_points = 100
    pc = Table(
        position = rand(SVector{3, Float64}, num_points),
        classification = rand(UInt8, num_points),
        gps_time = rand(num_points)
    )
    header = LasHeader(;
        data_format_id = 0x00,
        data_record_length = UInt16(LAS.byte_size(LasPoint0)),
        record_count = UInt64(num_points),
        point_return_count = (UInt64(num_points), zeros(UInt64, 14)...)
    )

    # should error if our point format in the point cloud is incompatible with the one in the header
    @test_throws AssertionError LasDataset(header, pc, LasVariableLengthRecord[], LasVariableLengthRecord[], UInt8[])
    set_point_format!(header, 1)
    set_point_record_length!(header, LAS.byte_size(LasPoint1))

    # number of points needs to match
    set_point_record_count!(header, num_points + 1)
    @test_throws AssertionError LasDataset(header, pc, LasVariableLengthRecord[], LasVariableLengthRecord[], UInt8[])
    set_point_record_count!(header, num_points)

    # same for number of VLRs/EVLRs
    set_num_vlr!(header, 1)
    @test_throws AssertionError LasDataset(header, pc, LasVariableLengthRecord[], LasVariableLengthRecord[], UInt8[])
    set_num_vlr!(header, 0)
    set_num_evlr!(header, 1)
    @test_throws AssertionError LasDataset(header, pc, LasVariableLengthRecord[], LasVariableLengthRecord[], UInt8[])
    set_num_evlr!(header, 0)

    las = LasDataset(header, pc, LasVariableLengthRecord[], LasVariableLengthRecord[], UInt8[])
    this_pc = get_pointcloud(las)
    @test length(this_pc) == num_points
    # check we add an ID column to the pointcloud
    @test :id ∈ columnnames(this_pc)
    @test all(map(col -> col ∈ columnnames(this_pc), columnnames(pc)))

    # make sure the header matches
    this_header = get_header(las)
    @test this_header == header

    # check equality if we create two of the same dataset
    other_las = LasDataset(deepcopy(header), deepcopy(pc), LasVariableLengthRecord[], LasVariableLengthRecord[], UInt8[])
    @test other_las == las
    
    # now try incorporating some user fields
    spicy_pc = Table(pc, thing = rand(num_points), other_thing = rand(Int16, num_points))
    las = LasDataset(header, spicy_pc, LasVariableLengthRecord[], LasVariableLengthRecord[], UInt8[])
    # make sure our record length reflects the user fields
    this_header = get_header(las)
    @test point_record_length(this_header) == LAS.byte_size(LasPoint1) + 10
    # our user fields should be populated in the dataset
    @test las._user_data isa FlexTable
    @test length(las._user_data) == num_points
    @test sort(collect(columnnames(las._user_data))) == [:other_thing, :thing]
    this_pc = get_pointcloud(las)
    @test this_pc.thing == spicy_pc.thing
    @test this_pc.other_thing == spicy_pc.other_thing
    # we should have documented our columns as extra bytes VLRs now
    vlrs = get_vlrs(las)
    @test length(vlrs) == 2
    vlr_data = get_data.(vlrs)
    @test all(isa.(vlr_data, ExtraBytes))
    @test (LAS.name(vlr_data[1]) == "thing") && (LAS.data_type(vlr_data[1]) == Float64)
    @test (LAS.name(vlr_data[2]) == "other_thing") && (LAS.data_type(vlr_data[2]) == Int16)
    # and our header should be updated appropriately
    @test number_of_vlrs(header) == 2
    # now add another user field directly to the dataset
    new_thing = rand(Float32, num_points)
    add_column!(las, :new_thing, new_thing)
    vlrs = get_vlrs(las)
    @test length(vlrs) == 3
    new_extra_bytes = get_data(vlrs[3])
    @test (LAS.name(new_extra_bytes) == "new_thing") && (LAS.data_type(new_extra_bytes) == Float32)
    # we shouldn't be able to add columns of different length to the LAS data
    @test_throws AssertionError add_column!(las, :bad, rand(10))
    # now if we replace the values of one of the user fields with a different type, it should work
    new_thing = rand(UInt8, num_points)
    add_column!(las, :thing, new_thing)
    vlrs = get_vlrs(las)
    @test length(vlrs) == 3
    new_extra_bytes = get_data(vlrs[3])
    @test (LAS.name(new_extra_bytes) == "thing") && (LAS.data_type(new_extra_bytes) == UInt8)

    # now check we can modify VLRs correctly
    desc = LasVariableLengthRecord(
        LAS.LAS_SPEC_USER_ID, 
        LAS.ID_TEXTDESCRIPTION, 
        "Text Area Description", 
        TextAreaDescription("This is a LAS dataset captured from somewhere idk")
    )
    add_vlr!(las, desc)
    vlrs = get_vlrs(las)
    @test length(vlrs) == 4
    @test vlrs[4] == desc
    # make sure we've updated the header correctly
    header = get_header(las)
    @test number_of_vlrs(header) == 4
    @test point_data_offset(header) == header_size(header) + sum(sizeof.(vlrs))
    # now let's replace this description for another one
    new_desc = LasVariableLengthRecord(
        LAS.LAS_SPEC_USER_ID, 
        LAS.ID_TEXTDESCRIPTION, 
        "Text Area Description", 
        TextAreaDescription("This is the new dataset description")
    )
    add_vlr!(las, new_desc)
    # mark the old one as superseded
    set_superseded!(las, desc)
    vlrs = get_vlrs(las)
    @test length(vlrs) == 5
    @test vlrs[5] == new_desc
    superseded_desc = vlrs[4]
    @test get_user_id(superseded_desc) == get_user_id(desc)
    @test get_record_id(superseded_desc) == LAS.ID_SUPERSEDED
    @test get_description(superseded_desc) == get_description(desc)
    @test get_data(superseded_desc) == get_data(desc)
    @test is_extended(superseded_desc) == is_extended(desc)
    # we can also remove the old one entirely
    remove_vlr!(las, superseded_desc)
    vlrs = get_vlrs(las)
    @test length(vlrs) == 4
    @test vlrs[4] == new_desc
    @test number_of_vlrs(get_header(las)) == 4

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
    @test length(get_vlrs(las)) == 4
    @test number_of_vlrs(header) == 4
    # should have updated the EVLRs
    evlrs = get_evlrs(las)
    @test length(evlrs) == 1
    @test number_of_evlrs(header) == 1
    @test evlrs[1] == long_comment
    @test evlr_start(header) > 0
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
    @test get_record_id(superseded_comment) == LAS.ID_SUPERSEDED
    @test get_description(superseded_comment) == get_description(long_comment)
    @test get_data(superseded_comment) == get_data(long_comment)
    @test is_extended(superseded_comment) == is_extended(long_comment)
    # and finally we can remove it
    remove_vlr!(las, superseded_comment)
    @test number_of_evlrs(get_header(las)) == 1
    @test get_evlrs(las) == [new_commment]
end