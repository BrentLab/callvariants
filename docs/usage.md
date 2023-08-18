# BrentLab/callvariants: Usage


## Introduction

For most users, a combination of the pre-configured profiles, the input
samplesheet, and an output directory name are the only required parameters.

## Samplesheet input

You will need to create a samplesheet with information about the samples you
would like to analyse before running the pipeline. Use this parameter to
specify its location. It has to be a comma-separated file with 3 columns,
and a header row as shown in the examples below.

```bash
--input '[path to samplesheet file]'
```

### Full samplesheet

The samplesheet must be a csv file. Each row in the samplesheet represents a
library. An example is shown below.

```csv
sample,group,genome_name,fastq_1,fastq_2,additional_fasta
A1-35-8,1,add_seq1,/path/to/A1-35-8_R1.fastq.gz,/path/to/A1-35-8_R2.fastq.gz,/path/to/additional_sequence1.fa
A1-102-8,1,add_seq1,/path/to/A1-102-8_R1.fastq.gz,,/path/to/additional_sequence1.fa
A1-17-8,1,main,/path/to/A1-17-8_R1.fastq.gz,/path/to/A1-17-8_R2.fastq.gz,
```

Libraries can be single-end (for example, row 2) or paired-end
(row 1 and 3). Each library must be assigned a group -- here, simply
denoted `1`, but this could be anything (no spaces). Next, we need to specify
a genome_name. I suggest using `main` for libraries which do not have any
additional fasta files (row 3 is an example of this).

The columns in the samplesheet are defined as follows:

| Column    | Description                                                                                                                                                                            |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sample`  | Custom sample name. This entry will be identical for multiple sequencing libraries/runs from the same sample. Spaces in sample names are automatically converted to underscores (`_`). |
| `group`  | A group name. If you set the parameter `call_joint_variants`, then rows with the same group will have the variants joinly called on all samples simultaneously. If `call_joint_variants` is false, this step is not performed and I suggest entering the same value in `group`, for instance, `1` would work. Group names can be alphabetic or numeric and contain special characters. They may not have spaces. |
| `genome_name`  | When `additional_fasta` is present, this is used to name the genome. For the unique set of `additional_fasta` which are provided in a single samplesheet, there may only be a single `genome_name`. For example, if you have 10 samples, where 5 of them use the genome which is passed by the `fasta` parameter, adn 5 genomes which use the additional sequence `marker1.fa`, then the five samples which use the unadulterated genome could have the `genome_name` `main` while the 5 which use the additional_sequence might be called `main_with_marker1`. Names can be alphabetic or numeric. There can be no spaces, and one name cannot apply to multiple different additional_fasta files. |
| `fastq_1` | Full path to FastQ file for Illumina short reads 1. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz". |
| `fastq_2` | Full path to FastQ file for Illumina short reads 2. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz". Providing a file is optional, and when it is not provided, the pipeline assumes that sample to be single-end |
| `additional_fasta` | Full path to a fasta format file which contains additional sequences to be appended to the genome fasta provided by the `fasta` parameter. This is optional -- if it is not passed, then the main fasta is used directly. If an additional fasta is passed, then it must have extension ".fasta" or ".fa"|

An [example samplesheet](../assets/test_multi_sample.csv) has been provided with the pipeline.

## Running the pipeline

Most commonly, this pipeline will be run with a combination of profiles.
More information on the available profiles are [here](#profile)

The typical command for running the pipeline to check genotypes of a set
of KN99 libraries on the WUSTL RIS compute cluster is as follows:

```bash
nextflow run BrentLab/callvariants -r main -profile ris,kn99_haploid,genotype_check --input ./samplesheet.csv --outdir ./results
```

Similarly, for processing data for bulk segregate analysis, you would do the
following:

```bash
nextflow run BrentLab/callvariants -r main -profile ris,kn99_haploid,bsa --input ./samplesheet.csv --outdir ./results
```

This will launch the pipeline with the `ris`, `kn99_haploid` and either the
`genotype_check` or `bsa` configuration profiles. See below for more
information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

More information on the contents of the `<OUTDIR>` may be found [here](./output.md)

## Using a params file

If you wish to repeatedly use the same parameters for multiple runs,
rather than specifying each flag in the command, you can specify these in a
params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

This can be created interactively using the [nf-core](https://github.com/nf-core/tools) tools (a python package).
If you install this, then you can use the following command:

```bash
nf-core launch Brentlab/callvariants -r main
```
to launch an interactive webpage that will help you create a params file.

> ⚠️ Do not use `-c <file>` to specify parameters as this will result in errors.
Custom config files specified with `-c` must only be used for
[tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources),
other infrastructural tweaks (such as output directories),
or module arguments (args).

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run BrentLab/callvariants -profile docker -params-file params.yaml
```

with `params.yaml` containing:

```yaml
input: './samplesheet.csv'
outdir: './results/'
genome: 'GRCh37'
<...>
```

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline
code from GitHub and stores it as a cached version. When running the pipeline
after this, it will always use the cached version if available - even if
the pipeline has been updated since. To make sure that you're running the
latest version of the pipeline, make sure that you regularly update the cached
version of the pipeline:

```bash
nextflow pull -r main BrentLab/callvariants
```

### Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on
your data. This ensures that a specific version of the pipeline code and
software are used when you run your pipeline. If you keep using the same tag,
you'll be running the same version of the pipeline, even if there have been
changes to the code since.

First, go to the [BrentLab/callvariants releases page](https://github.com/BrentLab/callvariants/releases)
and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify
this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`.
Of course, you can switch to another version by changing the number after
the `-r` flag.

This version number will be logged in reports when you run the pipeline, so
that you'll know what you used when you look back in the future. For example,
at the bottom of the MultiQC reports.

To further assist in reproducbility, you can use share and re-use
[parameter files](#running-the-pipeline) to repeat pipeline runs with the same
settings without having to write out a command with every single parameter.

> 💡 If you wish to share such profile (such as upload as supplementary
material for academic publications), make sure to NOT include cluster
specific paths to files, nor institutional specific profiles.

## Core Nextflow arguments

> **NB:** These options are part of Nextflow and use a _single_ hyphen
(pipeline parameters use a double-hyphen).

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give
configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the
pipeline to use software packaged using different methods (Docker, Singularity,
Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

> We highly recommend the use of Docker or Singularity containers for full
pipeline reproducibility, however when this is not possible, Conda is also
supported.

Note that multiple profiles can be loaded, for example:
`-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all
software to be installed and available on the `PATH`. This is _not_
recommended, since it can lead to different results on different machines
dependent on the computer enviroment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters. Output will
  be deposited in the directory `results`. This will
  run a single file with `debug`, `save_intermediates` and `save_reference` set to false
- `test_full`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters. In this case, all output is deposited to `results`, and all steps of the pipeline are executed and all outputs (including intermediates and debug)  are saved.
- `ris`
  - This profile configures the pipeline to run on the Washington University RIS compute cluster. Please see the instructions on running
  the pipeline on RIS for further configuration instructions.
- `htcf`
  - This profile configures the pipeline to run on the Washington University HTCF cluster. No additional configuration is necessary in the pipeline.
- `kn99_haploid`
  - This sets all paths (fasta, cnvpytor and snpeff files, etc) necessary
  to processing haploid KN99 samples. The fasta file is the most recent, as of 2023, KN99alpha genome from fungiDB. Additionally, this profile
  further configures the variant calling steps (freebayes, tiddit,
   cnvpytor, vcftools). However, these should be viewed as a starting point -- you as the scientist need to evaluate whether these settings
   are appropriate for your data. Information on adjusting these parameters are [here](#custom-configuration)
- `genotype_check`
  - This profile turns off joint variant calling
- `bsa`
  - This profile turns off individual variant calling
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://hpc.github.io/charliecloud/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter, Charliecloud, or Apptainer.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

There are two likely scenarios in which you will use a custom configuration
for this pipeline:

1. You are running the pipeline on RIS

1. You wish to adjust the variant calling settings.
    - In this case, you should copy the
    [kn99_haploid.conf](../conf/kn99_haploid.config) to a new file with a name
    that describes its purpose. The extension doesn't matter, but using `.conf`
    makes sense. In that new file, you can adjust the settings as you see
    fit. It would be a good idea to reference the
    [freebayes](https://github.com/freebayes/freebayes),
    [TIDDIT](https://github.com/SciLifeLab/TIDDIT) and
    [vcftools (this produces the filtered results)](https://vcftools.github.io/man_latest.html)
    documentation. The CNVpytor modules are quite complicated, and will almost
    certainly require a computationally experienced user. These modules have
    been modified for this pipeline. In order to adjust settings other than the
    bin size(s) and the depth for the filtered results, you will need to look
    at the [subworkflow code](../subworkflows/local/cnvpytor_complete.nf),
    the underlying [modules](../modules/nf-core/cnvpytor), the current
    kn99_haploid.conf file and the [CNVPytor](https://github.com/abyzovlab/CNVpytor)
    docs.

    Once you have created your new configuration file, you can provide it
    on the command line like so: `-c path/to/<name>.conf`

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher requests (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/usage/configuration#max-resources) and [tuning workflow resources](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources) section of the nf-core website.

### Custom Containers

In some cases you may wish to change which container or conda environment a step of the pipeline uses for a particular tool. By default nf-core pipelines use containers and software from the [biocontainers](https://biocontainers.pro/) or [bioconda](https://bioconda.github.io/) projects. However in some cases the pipeline specified version maybe out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/usage/configuration#updating-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
