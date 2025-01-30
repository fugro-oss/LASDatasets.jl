# Header

Each *LAS* file starts with a block of header information that contains metadata for the whole file. *LASDatasets.jl* uses the `LasHeader` struct to wrap around this data and defines a user-friendly interface to modify certain aspects of it.

```@docs; canonical = false
LasHeader
```

You can access information from the header using any of the following functions:

```@docs; canonical = false
las_version
file_source_id
global_encoding
system_id
software_id
creation_day_of_year
creation_year
header_size
point_data_offset
point_record_length
point_format
number_of_points
get_number_of_points_by_return
number_of_vlrs
number_of_evlrs
evlr_start
spatial_info
num_return_channels
is_standard_gps
is_wkt
is_internal_waveform
is_external_waveform
waveform_record_start
```

You can also modify certain fields in the header, but one should note that for some of these fields, such as those impacting the byte layout of the *LAS* file itself, it's better to let the system do it automatically so that your header remains consistent with your dataset.

```@docs; canonical = false
set_las_version!
set_point_format!
set_spatial_info!
set_point_data_offset!
set_point_record_length!
set_point_record_count!
set_num_vlr!
set_num_evlr!
set_gps_week_time_bit!
set_gps_standard_time_bit!
set_waveform_internal_bit!
set_waveform_external_bit!
set_synthetic_return_numbers_bit!
unset_synthetic_return_numbers_bit!
set_wkt_bit!
unset_wkt_bit!
set_number_of_points_by_return!
```