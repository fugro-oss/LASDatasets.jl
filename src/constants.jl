# constants for conversion factors from certain units to metres (as they are represented in an OGC WKT)
const UNIT_CONVERSION = Dict{String, Float64}(  "us-in" => 0.0254000508,
                                                "us-ft" => 0.304800609601219,
                                                "us-yd" => 0.9144018288, 
                                                "us-ch" => 20.116840234,
                                                "us-mi" => 1609.3472187,
                                                "in" => 0.0254,
                                                "ft" => 0.3048,
                                                "yd" => 0.9144,
                                                "mi" => 1609.344,
                                                "fath" => 1.8288,
                                                "ch" => 20.1168,
                                                "link" => 0.201168,
                                                "kmi" => 1852,
                                                "km" => 0.001, 
                                                "m" => 1.0, 
                                                "dm" => 10.0,
                                                "cm" => 100.0, 
                                                "mm" => 1000.0)

const LAS_SPEC_USER_ID = "LASF_Spec"
const LAS_PROJ_USER_ID = "LASF_Projection"
const ID_GEOKEYDIRECTORYTAG = UInt16(34735)
const ID_GEODOUBLEPARAMSTAG = UInt16(34736)
const ID_GEOASCIIPARAMSTAG = UInt16(34737)
const ID_OGCWKTTAG = UInt16(2112)
const ID_CLASSLOOKUP = UInt16(0)
const ID_TEXTDESCRIPTION = UInt16(3)
const ID_EXTRABYTES = UInt16(4)
const ID_SUPERSEDED = UInt16(7)
const ID_WAVEFORMPACKETDATA = UInt16(65535)

const DEFAULT_LAS_COLUMNS = (:position, :intensity, :classification, :returnnumber, :numberofreturns, :color, :point_source_id, :gps_time, :overlap)
const ALL_LAS_COLUMNS = nothing

POINT_SCALE = 0.0001
global const _VLR_TYPE_MAP = Dict()

const SUPPORTED_EXTRA_BYTES_TYPES = [UInt8, Int8, UInt16, Int16, UInt32, Int32, UInt64, Int64, Float32, Float64]