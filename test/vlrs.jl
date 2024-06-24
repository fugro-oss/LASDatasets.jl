@testset "VLRs" begin
    @testset "GeoTIFF" begin
        # make sure we can read GeoTIFF coordinate info VLRs correctly (values based on lasinfo)
        srs_vlrs = load_vlrs((joinpath(@__DIR__(), "test_files/srs.las")))
        @test all(LasDatasets.is_srs.(srs_vlrs))
        @test srs_vlrs[1].reserved == 43707
        @test get_record_id(srs_vlrs[1]) == LasDatasets.ID_GEOKEYDIRECTORYTAG
        @test get_user_id(srs_vlrs[1]) == LasDatasets.LAS_PROJ_USER_ID
        
        @test get_description(srs_vlrs[1]) == ""
        geokey_dir = get_data(srs_vlrs[1])
        @test geokey_dir.key_directory_version == 1
        @test geokey_dir.key_revision == 1
        @test geokey_dir.minor_revision == 0
        @test length(geokey_dir.keys) == 8
        # only the first 4 keys have any values populated
        @test geokey_dir.keys[1].keyid == 1024
        @test geokey_dir.keys[1].tiff_tag_location == 0
        @test geokey_dir.keys[1].count == 1
        @test geokey_dir.keys[1].value_offset == 1
        @test geokey_dir.keys[2].keyid == 1025
        @test geokey_dir.keys[2].tiff_tag_location == 0
        @test geokey_dir.keys[2].count == 1
        @test geokey_dir.keys[2].value_offset == 1
        @test geokey_dir.keys[3].keyid == 3072
        @test geokey_dir.keys[3].tiff_tag_location == 0
        @test geokey_dir.keys[3].count == 1
        @test geokey_dir.keys[3].value_offset == 32617
        @test geokey_dir.keys[4].keyid == 3076
        @test geokey_dir.keys[4].tiff_tag_location == 0
        @test geokey_dir.keys[4].count == 1
        @test geokey_dir.keys[4].value_offset == 9001

        @test srs_vlrs[2].reserved == 43707
        @test get_record_id(srs_vlrs[2]) == LasDatasets.ID_GEODOUBLEPARAMSTAG
        @test get_user_id(srs_vlrs[2]) == LasDatasets.LAS_PROJ_USER_ID
        @test get_description(srs_vlrs[2]) == ""
        @test get_data(srs_vlrs[2]) == GeoDoubleParamsTag([0.0, 0.0, 0.0, 0.0, 0.0])

        @test srs_vlrs[3].reserved == 43707
        @test get_record_id(srs_vlrs[3]) == LasDatasets.ID_GEOASCIIPARAMSTAG
        @test get_user_id(srs_vlrs[3]) == LasDatasets.LAS_PROJ_USER_ID
        @test get_description(srs_vlrs[3]) == ""
        geo_ascii = get_data(srs_vlrs[3])
        @test isempty(geo_ascii.ascii_params)
        @test geo_ascii.nb == 256

        # now, make sure we can save them and read them again
        io = IOBuffer()
        for vlr ∈ srs_vlrs
            write(io, vlr)
        end
        seek(io, 0)
        new_vlrs = map(_ -> read(io, LasVariableLengthRecord), 1:3)
        @test (length(new_vlrs) == length(srs_vlrs)) && all(new_vlrs .== srs_vlrs) 
    end

    @testset "GeoWKT" begin
        wkt = OGC_WKT("COMPD_CS[\"NAD83 / Maryland + NAVD88 height - Geoid12B (metre)\",PROJCS[\"NAD83 / Maryland\",GEOGCS[\"NAD83\",DATUM[\"North_American_Datum_1983\",SPHEROID[\"GRS 1980\",6378137,298.257222101,AUTHORITY[\"EPSG\",\"7019\"]],TOWGS84[0,0,0,0,0,0,0],AUTHORITY[\"EPSG\",\"6269\"]],PRIMEM[\"Greenwich\",0,AUTHORITY[\"EPSG\",\"8901\"]],UNIT[\"degree\",0.0174532925199433,AUTHORITY[\"EPSG\",\"9122\"]],AUTHORITY[\"EPSG\",\"4269\"]],PROJECTION[\"Lambert_Conformal_Conic_2SP\"],PARAMETER[\"standard_parallel_1\",39.45],PARAMETER[\"standard_parallel_2\",38.3],PARAMETER[\"latitude_of_origin\",37.66666666666666],PARAMETER[\"central_meridian\",-77],PARAMETER[\"false_easting\",400000],PARAMETER[\"false_northing\",0],UNIT[\"metre\",1,AUTHORITY[\"EPSG\",\"9001\"]],AXIS[\"X\",EAST],AXIS[\"Y\",NORTH],AUTHORITY[\"EPSG\",\"26985\"]],VERT_CS[\"NAVD88 height - Geoid12B (metre)\",VERT_DATUM[\"North American Vertical Datum 1988\",2005,AUTHORITY[\"EPSG\",\"5103\"]],HEIGHT_MODEL[\"US Geoid Model 2012B\"],UNIT[\"metre\",1,AUTHORITY[\"EPSG\",\"9001\"]],AUTHORITY[\"EPSG\",\"5703\"]]]\0")
        @test get_horizontal_unit(wkt) == "m"
        @test get_vertical_unit(wkt) == "m"
        @test LasDatasets.conversion_from_vlrs(wkt) == SVector{3, Float64}(1.0, 1.0, 1.0)
        wkt = OGC_WKT("COMPD_CS[\"NAD83(2011) / Texas Central (ftUS) + NAVD88 height - Geoid18 height (metre)\",PROJCS[\"NAD83(2011) / Texas Central (ftUS)\",GEOGCS[\"NAD83(2011)\",DATUM[\"NAD83_National_Spatial_Reference_System_2011\",SPHEROID[\"GRS 1980\",6378137,298.257222101,AUTHORITY[\"EPSG\",\"7019\"]],AUTHORITY[\"EPSG\",\"1116\"]],PRIMEM[\"Greenwich\",0,AUTHORITY[\"EPSG\",\"8901\"]],UNIT[\"degree\",0.0174532925199433,AUTHORITY[\"EPSG\",\"9122\"]],AUTHORITY[\"EPSG\",\"6318\"]],PROJECTION[\"Lambert_Conformal_Conic_2SP\"],PARAMETER[\"standard_parallel_1\",31.88333333333333],PARAMETER[\"standard_parallel_2\",30.11666666666667],PARAMETER[\"latitude_of_origin\",29.66666666666667],PARAMETER[\"central_meridian\",-100.3333333333333],PARAMETER[\"false_easting\",2296583.333],PARAMETER[\"false_northing\",9842500.000000002],UNIT[\"US survey foot\",0.3048006096012192,AUTHORITY[\"EPSG\",\"9003\"]],AXIS[\"X\",EAST],AXIS[\"Y\",NORTH],AUTHORITY[\"EPSG\",\"6578\"]],VERT_CS[\"\"NAVD88 height - Geoid18 (metre)\",VERT_DATUM[\"North American Vertical Datum 1988\",2005,AUTHORITY[EPSG,\"5103\"]],UNIT[\"metre\",1.0,AUTHORITY[\"EPSG\",\"9001\"]],AXIS[\"Gravity-related height\",UP],AUTHORITY[\"EPSG\",\"5703\"]]]")
        @test ismissing(get_horizontal_unit(wkt))
        @test ismissing(get_vertical_unit(wkt))
        @test all(ismissing.(LasDatasets.conversion_from_vlrs(wkt)))
        wkt = OGC_WKT("COMPD_CS[\"NAD83(2011) / Texas Central (ftUS) + NAVD88 height - Geoid18 height (metre)\",PROJCS[\"NAD83(2011) / Texas Central (ftUS)\",GEOGCS[\"NAD83(2011)\",DATUM[\"NAD83_National_Spatial_Reference_System_2011\",SPHEROID[\"GRS 1980\",6378137,298.257222101,AUTHORITY[\"EPSG\",\"7019\"]],AUTHORITY[\"EPSG\",\"1116\"]],PRIMEM[\"Greenwich\",0,AUTHORITY[\"EPSG\",\"8901\"]],UNIT[\"degree\",0.0174532925199433,AUTHORITY[\"EPSG\",\"9122\"]],AUTHORITY[\"EPSG\",\"6318\"]],PROJECTION[\"Lambert_Conformal_Conic_2SP\"],PARAMETER[\"standard_parallel_1\",31.88333333333333],PARAMETER[\"standard_parallel_2\",30.11666666666667],PARAMETER[\"latitude_of_origin\",29.66666666666667],PARAMETER[\"central_meridian\",-100.3333333333333],PARAMETER[\"false_easting\",2296583.333],PARAMETER[\"false_northing\",9842500.000000002],UNIT[\"US survey foot\",0.3048006096012192,AUTHORITY[\"EPSG\",\"9003\"]],AXIS[\"X\",EAST],AXIS[\"Y\",NORTH],AUTHORITY[\"EPSG\",\"6578\"]],VERT_CS[\"NAVD88 height - Geoid18 (metre)\",VERT_DATUM[\"North American Vertical Datum 1988\",2005,AUTHORITY[EPSG,\"5103\"]],UNIT[\"metre\",1.0,AUTHORITY[\"EPSG\",\"9001\"]],AXIS[\"Gravity-related height\",UP],AUTHORITY[\"EPSG\",\"5703\"]]]")
        @test get_horizontal_unit(wkt) == "us-ft"
        @test get_vertical_unit(wkt) == "m"
        @test LasDatasets.conversion_from_vlrs(wkt) == SVector{3, Float64}(0.304800609601219, 0.304800609601219, 1.0)
        wkt = OGC_WKT("COMPD_CS[\"NAD_1983_HARN_StatePlane_Florida_North_FIPS_0903_Feet / NAVD88 - Geoid12B (Feet)\",PROJCS[\"NAD_1983_HARN_StatePlane_Florida_North_FIPS_0903_Feet\",GEOGCS[\"GCS_North_American_1983_HARN\",DATUM[\"D_North_American_1983_HARN\",SPHEROID[\"GRS_1980\",6378137,298.257222101004]],PRIMEM[\"Greenwich\",0],UNIT[\"Degree\",0.0174532925199433]], PROJECTION[\"Lambert_Conformal_Conic\"],PARAMETER[\"False_Easting\",1968500],PARAMETER[\"False_Northing\",0],PARAMETER[\"Central_Meridian\",-84.5],PARAMETER[\"Standard_Parallel_1\",29.5833333333333],PARAMETER[\"Standard_Parallel_2\",30.75],PARAMETER[\"Latitude_Of_Origin\",29],UNIT[\"Foot_US\",0.304800609601219]],VERT_CS[\"NAVD88 - Geoid12B (Feet)\",VERT_DATUM[\"North American Vertical Datum 1988\",2005,AUTHORITY[\"EPSG\",\"5103\"]],HEIGHT_MODEL[\"US Geoid Model 2012B\"],UNIT[\"Foot_US\",0.304800609601219],AUTHORITY[\"EPSG\",\"6360\"]]]")
        @test get_horizontal_unit(wkt) == "us-ft"
        @test get_vertical_unit(wkt) == "us-ft"
        @test LasDatasets.conversion_from_vlrs(wkt) == SVector{3, Float64}(0.304800609601219, 0.304800609601219, 0.304800609601219)

        @test ismissing(LasDatasets.units_to_conversion(missing))
        @test ismissing(LasDatasets.units_to_conversion("weird-unknown-unit"))
        @test SVector{3}(1.0, 1.0, 1.0) == LasDatasets.units_to_conversion("m")
        @test SVector{3}(0.3048, 0.3048, 0.3048) == LasDatasets.units_to_conversion("ft")
        @test SVector{3}(0.3048, 0.3048, 1.0) == LasDatasets.units_to_conversion("ft", "m")

        # make sure we can save and load correctly
        ogc_wkt_vlr = LasVariableLengthRecord(LasDatasets.LAS_PROJ_USER_ID, 2112, "OGC WKT Info", wkt)
        @test LasDatasets.is_ogc_wkt_record(ogc_wkt_vlr)
        io = IOBuffer()
        write(io, ogc_wkt_vlr)
        seek(io, 0)
        @test read(io, LasVariableLengthRecord) == ogc_wkt_vlr
    end

    @testset "Classification Lookup" begin
        @test_throws AssertionError ClassificationLookup(Dict(1000 => "Too big"))
        @test_throws AssertionError ClassificationLookup(Dict(1 => "This description is way too long"))

        lookup = ClassificationLookup(1 => "Class 1", 200 => "Big Class!")
        @test length(lookup) == 2
        @test get_classes(lookup) == [1, 200]
        @test get_description(lookup, 1) == "Class 1"
        @test get_description(lookup, 200) == "Big Class!"

        set_description!(lookup, 1, "Small class")
        @test get_description(lookup, 1) == "Small class"

        @test_throws AssertionError set_description!(lookup, 200, "Big description for a big class")

        vlr = LasVariableLengthRecord(LasDatasets.LAS_SPEC_USER_ID, LasDatasets.ID_CLASSLOOKUP, "Classification Lookup", lookup)
        
        # make sure we can save and load
        io = IOBuffer()
        write(io, vlr)
        seek(io, 0)
        @test read(io, LasVariableLengthRecord) == vlr
    end

    @testset "Custom VLRs" begin
        # make sure the register macro works as expected
        @test_throws AssertionError @register_vlr_type Vector{Int} 100 [1, 2]
        @test_throws AssertionError @register_vlr_type Vector{Int} "User ID" [1.0, 2.0]
        @test_throws AssertionError @register_vlr_type Vector{Int} "User ID" "Record ID"
        @test_throws AssertionError @register_vlr_type [1, 2, 3] "User ID" [1, 2]

        @register_vlr_type Vector{Int} "User ID" [1, 2]
        @test ("User ID", [1, 2]) ∈ keys(LasDatasets._VLR_TYPE_MAP) && (LasDatasets._VLR_TYPE_MAP["User ID", [1, 2]] == Vector{Int})
        
        @register_vlr_type String "Custom" collect(10:15)
        LasDatasets.read_vlr_data(io::IO, ::Type{String}, nb::Integer) = LasDatasets.readstring(io, nb)
        
        # create a custom VLR
        vlr = LasVariableLengthRecord("Custom", 10, "A string", "This is a string")
        
        # make sure we can save and load
        io = IOBuffer()
        write(io, vlr)
        seek(io, 0)
        @test read(io, LasVariableLengthRecord) == vlr
    end
end