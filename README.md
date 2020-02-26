# Tenacious Image-File Foreshortener (TI-FF)
This is a Z shell script for replacing all TIFF files in a directory with compressed PNG files that have nearly the same information.

## purpose
This utility is intended for use with 

## usage
usage: `ti-ff [ -h | --help | -? ] [<directory>]`

This script finds all TIFF files in the current directory (or the provided directory) and converts them all to PNGs using [LibTIFF](http://LibTIFF.org)’s `tiff2png` command. The resulting PNGs are then compressed with [OptiPNG](http://OptiPNG.SourceForge.net). The TIFFs for which this process is successful are **deleted**.
Please note that, by design, this script strips all TIFF and PNG metadata from the output files; however, file access and modification times are copied from the deleted TIFFs to the output PNGs.

### dependencies
This script runs only in [Z shell](http://zsh.SourceForge.net) (Zsh) and directly relies on the following utilities:

* [LibTIFF](http://LibTIFF.org)’s `tiff2png`
* [OptiPNG](http://OptiPNG.SourceForge.net)
* [file](https://DarwinSys.com/file) (with the `--mime-type` option)
* `touch` (with the `-r` option)
* `printf`
* `wc`

Starting with an argument of `-h`, `--help`, or `-?` causes this message to be printed to stdout with no further actions.

### status codes

0. success
1. optional directory argument not found
2. process interrupted by SIGINT or SIGTERM
3. failure in at least one file
