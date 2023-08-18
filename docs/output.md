# BrentLab/callvariants: Output

## Introduction

This document describes the output of the pipeline.

The pipeline will produce two output directories: `work` and the directory
which is named by the `outdir` parameter (for example, `results`). When the
pipeline has successfully completed, you should delete `work`.

First, the parameters `debug`, `save_intermediates` and `save_reference`
each affect what is output.

- `save_reference` should be used when you are passing additional sequences
via the samplesheet, and you wish to save the concatenated genome (the main
genome fasta + the additional sequences). This would be useful, for instance,
when you wish to use those additional sequences in the IGV.

- `save_intermediates` is similar to a `verbose` setting -- this will output
more of the intermediate files, such as uncompressed vcf files, which are
produced as the pipeline runs

- `debug` should be used in addition to `save_intermediates` when debugging
the pipeline. Even with `save_intermediates`, there are some steps which are
not output to the `outdir` directory. Setting `debug` will ensure that all
steps are actually output. This is likely only useful in debugging.

The files which are hidden by one of the parameters above are noted below.

## The output directory structure

