# Variable Length Records

*Variable Length Records* are useful packets of data that one can include between the header block and start of the point records in a *LAS* file. The *LAS* 1.4 spec also allows for larger data payloads to be stored as *Extended Variable Length Records*, which are stored at the end of the file after the point records. The difference between these is that regular *VLRs* can only have a payload up to 2^16 bytes whereas *EVLRs* can have a payload up to 2^64.

All types of *VLRs* (regular and extended) are wrapped inside a `LasVariableLengthRecord` struct, which holds the data payload as well as the relevant *VLR* IDs and metadata. Each `LasVariableLengthRecord` is parametrised by the type of data in its payload which makes *LAS.jl* able to handle parsing each *VLR* to/from a native *Julia* struct automatically.

```@docs; canonical = false
LasVariableLengthRecord
```

## Coordinate Reference System VLRs

The *LAS* 1.4 spec provides definitions for storing coordinate reference system details as *VLRs*. These are implemented as their own structs so they can be wrapped inside `LasVariableLengthRecord`s. These are split into two flavours: *WKT*, which uses the OpenGIS
coordinate transformation service implementation specification [here](https://www.opengeospatial.org/standards/ct), and *GeoTiff*, which are included for legacy support for specs 1.1-1.3 (and are incompatible with *LAS* point formats 6-10).

### WKT

*LAS.jl* supports the *OGC Coordinate System WKT Record*, which is handled by the struct `OGC_WKT`. Currently we don't support *OGC Math Transform WKT*, however this could be supported in a future release.

```@docs; canonical = false
OGC_WKT
```

One benefit of using the *OGC WKT* is that you can specify what units of measurement are used for your point cloud positions along both the *XY* plane and the *Z* axis. When reading a *LAS* file, the system will detect if an *OGC WKT* is present and will autom

### GeoTiff