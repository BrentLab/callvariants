## Introduction

**BrentLab/callvariants** is a bioinformatics pipeline for general variant calling.
It runs Freebayes, TIDDIT and CNVpytor for SNP/INDEL and structural variant
calling.

This has been developed with specific functionality in mind. These are:

1. Checking the genotype of KN99alpha samples
    - This is performed by providing additional sequences to be appended to the
    genome prior to alignment in a per-smaple basis
2. Processing *c. neoformans* samples for bulk segregant analysis
    - The Freebayes step can optionally be used to jointly call variants on
    groups which are identified in the input samplesheet

The pipeline, overall, runs the following processes:

1. Prepare the Genome
    1. Concatenate additional sequences provided in the input samplesheet,
    if there are any
    1. Create indicies
        1. [samtools faidx](http://www.htslib.org/doc/samtools-faidx.html)
        1. [bwamem2 index](https://github.com/bwa-mem2/bwa-mem2)
        1. [bwa index](https://github.com/lh3/bwa) -- this is for TIDDIT
    1. Create sequence maps
        1. [build](modules/local/build_intervals/main.nf) and
        [create](modules/local/create_intervals_bed/main.nf) intervals.
        Both of these are from [sarek](https://github.com/nf-core/sarek)
        1. [GATK CreateSequenceDictionary](https://gatk.broadinstitute.org/hc/en-us/articles/360036712531-CreateSequenceDictionary-Picard-)
    1. Read QC ([fastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
    1. Align reads
        1. [bwamem2](https://github.com/bwa-mem2/bwa-mem2)
        1. [picard MarkDuplicates](https://gatk.broadinstitute.org/hc/en-us/articles/360037052812-MarkDuplicates-Picard-)
        1. [picard AddOrReplaceReadGroup](https://gatk.broadinstitute.org/hc/en-us/articles/360037226472-AddOrReplaceReadGroups)
        1. [samtools](https://samtools.github.io/) index, sort, stats, flatstats, idxstats
    1. Call Variants
        1. [Freebayes](https://github.com/freebayes/freebayes)
        1. [TIDDIT](https://github.com/SciLifeLab/TIDDIT)
        1. [CNVpytor](https://github.com/abyzovlab/CNVpytor)
        1. [snpEff](https://pcingola.github.io/SnpEff/)
        1. [vcftools](https://vcftools.github.io/) for filtering
        1. [bcftools](https://samtools.github.io/bcftools/bcftools.html) stats
1. Present QC for raw reads ([`MultiQC`](http://multiqc.info/))

## Usage

> **Note**
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how
> to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline)
> with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,group,genome_name,fastq_1,fastq_2,additional_fasta
A1-35-8,1,add_seq1,/path/to/A1-35-8_R1.fastq.gz,/path/to/A1-35-8_R2.fastq.gz,/path/to/additional_sequence1.fa
A1-102-8,1,add_seq1,/path/to/A1-102-8_R1.fastq.gz,,/path/to/additional_sequence1.fa
A1-17-8,1,main,/path/to/A1-17-8_R1.fastq.gz,/path/to/A1-17-8_R2.fastq.gz,
```

Each row represents a library. Libraries can be single-end (for example, row 2)
or paired-end (row 1 and 3). Each library must be assigned a group -- here,
simply denoted `1`, but this could be anything (no spaces). Next, we need to
specify a genome_name. I suggest using `main` for libraries which do not have
any additional fasta files (row 3 is an example of this).

Now, you can run the pipeline using a command similar to the following

```bash
nextflow run BrentLab/callvariants \
   -r main \
   -profile <htcf,ris,kn99_haploid,genotype_check,bsa> \
   -c /path/to/local.config \
   --input samplesheet.csv \
   --fasta /path/to/genome.fa \
   --outdir <OUTDIR>
```

The pipeline will be automatically pulled from github by using
`BrentLab/callvariants`. You need to include the `-r main` flag in order to
tell nextflow that it should use the main branch (this will be the most
current). You may wish to use a specific version, eg `-r 1.0.0` for
consistency over batches, however.

The `-profile` flag can be used to select a pre-configured set of parameters.
Mulitple profiles can be selected, for example
`-profile ris,genotype_check,kn99_haploid`.

The `-c /path/to/local.config` flag is the path to a local configuration file.
This may be necessary to further configure your environment on your specific
machine. It is also possible that this is not necessary and may be omitted.

The `--input`, `--fasta` and `--outdir` are required arguments to the workflow.
You can use `nextflow run BrentLab/callvariants -r main --help` for more
information on the input parameters, or you can
[read about the input parameters here](docs/params.md)

> **Warning:**
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those
> provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;
> see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

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
