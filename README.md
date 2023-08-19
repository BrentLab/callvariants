## Introduction

**BrentLab/callvariants** is a bioinformatics pipeline for general variant calling.
It runs Freebayes, TIDDIT and CNVpytor for SNP/INDEL and structural variant
calling.

This workflow has been developed with the following specific functionality
in mind:

- Checking the genotype of KN99alpha samples
  - This is performed by providing additional sequences to be appended to the
    genome prior to alignment in a per-smaple basis
- Processing *c. neoformans* samples for bulk segregant analysis
  - The Freebayes step can optionally be used to jointly call variants on
    groups which are identified in the input samplesheet

But there is no reason why it is limited to these applications.

The pipeline, overall, runs the following processes:

1. Prepare the Genome
    - Concatenate additional sequences provided in the input samplesheet,
    if there are any
    - Create indicies
        - [samtools faidx](http://www.htslib.org/doc/samtools-faidx.html)
        - [bwamem2 index](https://github.com/bwa-mem2/bwa-mem2)
        - [bwa index](https://github.com/lh3/bwa) -- this is for TIDDIT
    - Create sequence maps
        - [build](modules/local/build_intervals/main.nf) and
        [create](modules/local/create_intervals_bed/main.nf) intervals.
        Both of these are from [sarek](https://github.com/nf-core/sarek)
        - [GATK CreateSequenceDictionary](https://gatk.broadinstitute.org/hc/en-us/articles/360036712531-CreateSequenceDictionary-Picard-)
1. Read QC
    - [fastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)
1. Align reads
    - [bwamem2](https://github.com/bwa-mem2/bwa-mem2)
    - [picard MarkDuplicates](https://gatk.broadinstitute.org/hc/en-us/articles/360037052812-MarkDuplicates-Picard-)
    - [picard AddOrReplaceReadGroup](https://gatk.broadinstitute.org/hc/en-us/articles/360037226472-AddOrReplaceReadGroups)
    - [samtools](https://samtools.github.io/) index, sort, stats, flatstats, idxstats
1. Call Variants
    - [Freebayes](https://github.com/freebayes/freebayes)
    - [TIDDIT](https://github.com/SciLifeLab/TIDDIT)
    - [CNVpytor](https://github.com/abyzovlab/CNVpytor)
    - [snpEff](https://pcingola.github.io/SnpEff/)
    - [vcftools](https://vcftools.github.io/) for filtering
    - [bcftools](https://samtools.github.io/bcftools/bcftools.html) stats
1. Collect and present QC
    - [MultiQC](http://multiqc.info/)

## [Usage](docs/usage.md)

If you are new to Nextflow and nf-core, please refer to
[this page](https://nf-co.re/docs/usage/installation) on how to set-up
Nextflow. Make sure to
[test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline)
with `-profile test` before running the workflow on actual data.
If you are running this test on WUSTL HTCF or RIS, use one of the built-in
[profiles](docs/usage.md#profile), either `htcf` or `ris`. If you are running
the test on a different host, then you may consider including one of the
dependency manager profiles, eg `singularity` or `docker`.

A test run for `ris`, for example, would look like this:

```bash
nextflow run BrentLab/callvariants -r main -profile ris,test
```
you will need to submit this appropriately, but no other input is necessary
to run the tests -- all input is taken care of by the `test` profile

For detailed instructions on running your own data, please see the
[**usage documentation**](docs/usage.md)

## [Output](docs/output.md)

For a description of the output directory, please see the
[**output documentation**](docs/output.md)

## Credits

BrentLab/callvariants was originally written by Chase Mateusiak. It is based on
the BSA processing steps of Daniel Agustinhno.

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

<!-- TODO after releasing a new version, update the doi url -->
If you use  BrentLab/callvariants for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX)

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
