# LAS.jl 

[![CI](https://github.com/fugro-oss/LAS.jl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/fugro-oss/LAS.jl/actions/workflows/ci.yml)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://fugro-oss.github.io/LAS.jl/dev)

A Julia package for reading and writing *LAS* data. *LAS* is a public file format for saving and loading 3D point cloud data, and its source repository can be found [here](https://github.com/ASPRSorg/LAS). This package currently supports *LAS* specifications 1.1-1.4 (see [here](https://www.asprs.org/wp-content/uploads/2019/03/LAS_1_4_r14.pdf) for the 1.4 spec.)

Some key features included in this package are:
* High-level functions for reading and writing *LAS* data in tabular formats using [TypedTables.jl](https://github.com/JuliaData/TypedTables.jl)
* Automatic detection of *LAS* point formats from data
* Reading and writing *Julia*-native structs as *Variable Length Records* (*VLRs*) and *Extended Variable Length Records* (*EVLRs*)
* Easy manipulation of file header properties


## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. Simply run:

```
using Pkg
Pkg.add("git@github.com:fugro-oss/LAS.jl.git")
using LAS
```

And you're ready to go!

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our process for submitting pull requests to us, and please ensure
you follow the [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/fugro-oss/LAS.jl/tags). 

## Authors

* **Ben Curran** - *initial author of repo* - [@BenCurran98](https://github.com/BenCurran98)

See also the list of [contributors](CONTRIBUTORS) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details