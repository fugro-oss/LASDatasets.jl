# LasDatasets.jl

A Julia package for reading and writing *LAS* data. *LAS* is a public file format for saving and loading 3D point cloud data, and its source repository can be found [here](https://github.com/ASPRSorg/LAS). This package currently supports *LAS* specifications 1.1-1.4 (see [here](https://www.asprs.org/wp-content/uploads/2019/03/LAS_1_4_r14.pdf) for the 1.4 spec.)

Some key features included in this package are:
* High-level functions for reading and writing *LAS* data in tabular formats using [TypedTables.jl](https://github.com/JuliaData/TypedTables.jl)
* Automatic detection of *LAS* point formats from data
* Reading and writing *Julia*-native structs as *Variable Length Records* (*VLRs*) and *Extended Variable Length Records* (*EVLRs*)
* Easy manipulation of file header properties