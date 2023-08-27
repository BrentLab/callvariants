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

## The Output Directory

This will be named according to what you set in the submission command:

```bash
--outdir <results_dir_name>
```

The following subdirectories will exist, depending on the settings of `debug`,
`save_intermediates` and `save_reference`, which control what is saved in
the `<OUTDIR>`. Note that all input and intermediate files are stored in the
`work` directory, so until you delete `work` (which you should when the
pipeline successfully completes), you can find *all* of the files produced
by the pipeline there. In general, `debug` and `save_intermediates` are set
to `false`. `save_reference` is set to true by default in the `genotype_check`
profile since it is more likely that additional fasta will be provided in the
samplesheet when using the pipeline for this purpose.

**Note**: in general, setting `save_reference` is useful if you want to use the
concatenated fasta (the result of appending the sample's `additional_fasta` to
the main genome fasta) to view samples in the IGV. It is not recommended that
you keep unnecessary copies of the genome long-term, however, so you should
plan to delete these genomes when finished with them. They can always be
easily recreated.

### alignment

In the main directory, the final `<sample>_markdups_tagged.bam` and
`<sample>_markdups_tagged.bam.bai` alignment files will be stored at the
top level. These have been run through picard mark duplicates, and they have
had the sample name and some other information added as with picard
add or replace read tags.

If `params.save_intermediates` is set, then the `bwamem2` and `bwa` indicies
will be saved as subdirectories of `alignment`.

in the `picard` subdirectory, the duplicated marked intermediate `bam` will be
saved *only* went the `debug` parameter is `true`. However, the mark duplicates
report will always be saved here as
`<sample>_markdups.Markduplicates.metrics.txt`.

Finally, the `samtools` subdirectory will always store the `<sample>_sorted_markdups_tagged.flagstat`,
`<sample>_sorted_markdups_tagged.idxstats`, and
`<sample>_sorted_markdups_tagged.stats` samtools QC files.

### fastqc

The `fastqc` subdirectory stores the output of fastQC

### multiqc

The `multiqc` subdirectory stores the result of running multiQC on the
output of the pipeline. MultiQC collects and organizes the output of an
enormous number of bioinformatics package. Of particular interest to most
users will be the `multiqc_report.html`, which presents the result of this
collection of the output of the pipeline processes into a nicely presented,
feature rich html report that may be viewed in a browser. There is more
in the multiqc subdirectory, though -- and you can
learn about it from the [multiqc docs](https://multiqc.info/)

### pipeline_info

This subdirectory stores information about the pipeline and is created by
the workflow. There will be the following files:

- `execution_report_<timestamp>.html` gives you detailed information about the
resource requests, usage, and more about each process run by the pipeline

- `execution_timeline_<timestamp>.html` gives you a graph which shows how much
time, and with how much parallelism, each process in the pipeline executed

- `execution_trace_<timestamp>.html` is a detailed view, from the host machine,
of each process. This is similar to the output you would get from looking
at the execution log from your executor (slurm, LSF, ...)

- `pipeline_dag_<timestamp>.html` this is a neat visualization of the directed
acyclic graph which is a representation of how each process in the pipeline
is related to other process through the data channels. This is likely only
useful to a developer who wants to do a deep dive into how process
relationships could be improved

- `software_versions.yml` this is a list of softwares and version info for each
software used in the pipeline. For citations, please see the
[CITATIONS](../CITATIONS.md)

### reference

This will only exist when `save_reference` is set to true. In that case,
at the top level the genomes used for alignment and their `.fai` files will
exist. Genomes created by appending the `additional_fasta` from the samplesheet
to the main genome will be named according to their `<genome_name>_concat`
where `genome_name` is from the samplesheet. If `debug` is set to true, then
the various programs which create sequence dictionaries from the genomes for
the purpose of processing `freebayes` in chunks in parallel will also be
saved. Note that the chunks are created according to some internal settings,
and very short contigs from the genome fasta may be appended to previous
chunks. This may not be reflected in the chunk filename, so if you suspect
an issue in the interval files, make sure you actually look at them rather than
only relying on the filename.

### variants

This is where the variant calling output is saved. There will be three
subdirectories, `cnvpytor`, `raw` and `filtered`.

#### cnvpytor

You are encouraged to go to the
[CNVpytor documentation](https://github.com/abyzovlab/CNVpytor)
to learn more.

Specifically, you can use the `.pytor` files in the cnvpytor output directory
and follow along with their jupyter notebook to do things like visualize the
depth information. [See here](https://github.com/abyzovlab/CNVpytor/blob/master/examples/PythonLibraryGuide.ipynb).
If you discover that there are no calls in a given binwidth, you can try
reducing the bin width, though it gets buggy below 1000. It may be useful to
use the tiddit coverage output. See the [tiddit](#raw) output in the
`variants/raw` output directory for a less fancy, more manual sound approach to
exploring CNV. Though not statistically sound, it may still be enlightening.

This will store the output of the cnvpytor variant calling process. If
`save_intermediates` is set to true, then some of the intermediate steps'
pytor files will be saved in corresponding subdirectories, eg `histogram` and
`import_read_depth`. However, you will almost certainly only be interested in
the files at the top level of this directory, which will be:

- `<sample>_filtered_<bin_width>_depthfiltered.tsv`: this has had any cnvpytor
filters applied, *and* has been filtered according to a normalized depth. In
the `kn99_haploid` profile, there is no additional filter, so the `_filter` and
`_raw` are identical. **However**, the `_depthfiltered` file is filtered for
only those records with normalized depth > 1.7x
- `<sample>_filtered_<bin_width>.tsv`: this tsv file has been filtered
according to the cnvpytor filter settings, but has *not* been filtered by
normalized depth
- `<sample>.pytor`: this is the object which is produced and used by CNVPytor
- `<sample>_raw_<bin_width>.tsv`: this is a completely unfiltered set of
CNVPytor results in `tsv` format.


#### filtered

At the top level, there wil be `<sample or group>_<freebayes/tiddit>_filtered.vcf.gz`
and `<sample or group>_<freebayes/tiddit>_filtered.vcf.gz.tbi` files.
These are snpeff annotated and filtered by vcftools. There will be
subdirectories `bcftools_stats` which stores the results of running
[bcftools stats](https://samtools.github.io/bcftools/bcftools.html) on the vcfs.
The `snpeff` subdirectory will have `vcf` files if `debug` is set to true. It
will always have the `.txt` and `.html` snpEff reports

#### raw

At the top level of this directory, there will be
`<sample or group>_<freebayes/tiddit>.vcf.gz` and the corresponding
`<.vcf.gz.tbi>` index file. Like the `filtered` results, there will be
a `snpeff` subdirectory that will have `vcf` files only if `debug` is `true`.
It will always have the `.txt` and `.html` snpeff reports. There will be
a `bcftools_stats` subdirectory that will store the `.bcftools_stats.txt` QC
reports on the raw files. Then, optionally and mostly by setting `debug`,
there may be the subdirectories `freebayes` and `gatk4`. Note that in the
`freebayes` subdirectory, the results of calling the variants on *chunks* will
be stored. These are then collected by gatk4, and it is those collected files
that are presented in the the top level.

**IMPORTANT**: in the subdirectory `tiddit`, if `save_intermediates` is true,
there will be `vcf` files. But, more importantly, there will *always* be a file
called `<sample or group>_tiddit.ploidies.tab` which has the TIDDIT estimation
of the ploidy of the sample over each contig in the genome file. There is not
good documentation on how this is calculated. Additionally, in the `tiddit`
subdirectory, there is a bed file with coverage across some bin width. By
default, the binwidth is 500. In the kn99_haploid profile, it is set to 10000.
This can be used to more manually examine read depth and possible CNV events.
Since CNVpytor is somewhat challenging to use and not terribly clear in what
it is doing, the tiddit `.bed` coverage file can be used as a quick sanity
check. Here is an example of parsing the bed file, using R:

```R
library(tidyverse)

cov_df = read_tsv("/path/to/results/raw/tiddit/<sample>_tiddit.bed")

filtered_cov_df = cov_df %>%
    group_by(`#chromosome`) %>%
    mutate(mean_coverage = mean(coverage)) %>%
    ungroup() %>%
    mutate(normalized_coverage = coverage / mean_coverage) %>%
    select(-mean_coverage) %>%
    filter(normalized_coverage > 1.7 | normalized_coverage < .1)

view(filtered_cov_df)
```
