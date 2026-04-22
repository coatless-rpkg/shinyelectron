# Append app-specific package installs to the Dockerfile

Bakes the dependencies into the image at build time so container launch
doesn't have to compile/install packages on the user's machine.

## Usage

``` r
bake_dockerfile_dependencies(output_dir, dockerfile_dest)
```
