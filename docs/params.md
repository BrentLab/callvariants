

# BrentLab/callvariants pipeline parameters

a variant caller intended for both genotype checks and BSA data processing for the Brent and Doering labs

## Variant calling



| Parameter | Description | Type | Default | Required | Hidden |
|-----------|-----------|-----------|-----------|-----------|-----------|
| `cnvpytor_conf_file` | Path to the cnvpytor configuration file. This is not necessary for the cnvpytor default configured organisms. For KN99, one is available in assets/genome_files. This is set
| `cnvpytor_gc_file` | Path to the cnvpytor GC file. This is not necessary for the organisms configured by default in cnvpytor. One for KN99 is available in assets/genome_files and is set automatica
| `snpeff_db_config` | snpEff config file. This is not necessary for the organisms configured by default in snpeff. A config file suitable for KN99 is provided in assets/genome_files. This is set in
| `snpeff_config_key` | The organism key in the snpEff config. This is set in the kn99_haploid profile for KN99 | `string` |  |  | True |
| `snpeff_db` | Path to the snpEff database. This is not necessary for organisms configured by default in snpEff. A database for KN99 exists in assets/genome_files and is set automatically in the KN
| `region_bed_mask` | Path to a bed file of regions to filter (remove) from the filtered variant calls. A file made by daniel, probably with NCBI dustmask, is in assets/genome files. This is set in
| `call_individual_variants` | By defualt, true. Set this to false to avoid calling variants on individual samples. For instance, for BSA, you may not care to call variants on the individual samles
| `call_joint_variants` | By default, true, Set to false to avoid calling variants jointly, within samplesheet group | `boolean` | True |  | True |

## Input/output options

Define where the pipeline should find input data and save output data.

| Parameter | Description | Type | Default | Required | Hidden |
|-----------|-----------|-----------|-----------|-----------|-----------|
| `input` | Path to comma-separated file containing information about the samples in the experiment. <details><summary>Help</summary><small>You will need to create a design file with information abo
| `outdir` | The output directory where the results will be saved. You have to use absolute paths to storage on Cloud infrastructure. | `string` |  | True |  |
| `email` | Email address for completion summary. <details><summary>Help</summary><small>Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when th
| `multiqc_title` | MultiQC report title. Printed as page header, used for filename if not otherwise specified. | `string` |  |  | True |
| `save_intermediates` | Set this flag to save intermediate outputs, eg un-zipped and indexed vcf files from TIDDIT. | `boolean` |  |  | True |
| `debug` | When save_intermediates is set to true, some steps still will not output. Set debug, inaddition to save_intermediates, to save absolutely all of the output | `boolean` |  |  | True |
| `save_reference` | Set this to true to save the reference genome in the pipeline `outdir`. This is useful when you include additional fasta files | `boolean` |  |  |  |
| `platform` | Name of the sequencing machine used to produce the raw data | `string` | platform_not_set |  | True |

## Reference genome options

Reference genome related files and options required for the workflow.

| Parameter | Description | Type | Default | Required | Hidden |
|-----------|-----------|-----------|-----------|-----------|-----------|
| `fasta` | Path to FASTA genome file. <details><summary>Help</summary><small>This parameter is *mandatory* if `--genome` is not specified. If you don't have a BWA index available this will be gener
| `fasta_fai` | Path to the fasta fai index file. Note that this is not currently used since in the case of samples with additional fasta files the indicies need to be re-made. | `string` |  |  | Tr

## Institutional config options

Parameters used to describe centralised config profiles. These should not be edited.

| Parameter | Description | Type | Default | Required | Hidden |
|-----------|-----------|-----------|-----------|-----------|-----------|
| `config_profile_name` | Institutional config name. | `string` |  |  | True |
| `config_profile_description` | Institutional config description. | `string` |  |  | True |
| `config_profile_contact` | Instutional configuration profile contact | `string` |  |  |  |
| `config_profile_url` | Institutional proflie documentation url | `string` |  |  |  |

## Max job request options

Set the top limit for requested resources for any single job.

| Parameter | Description | Type | Default | Required | Hidden |
|-----------|-----------|-----------|-----------|-----------|-----------|
| `max_cpus` | Maximum number of CPUs that can be requested for any single job. <details><summary>Help</summary><small>Use to set an upper-limit for the CPU requirement for each process. Should be a
| `max_memory` | Maximum amount of memory that can be requested for any single job. <details><summary>Help</summary><small>Use to set an upper-limit for the memory requirement for each process. Shou
| `max_time` | Maximum amount of time that can be requested for any single job. <details><summary>Help</summary><small>Use to set an upper-limit for the time requirement for each process. Should be
| `nucleotides_per_second` |  | `integer` | 1000 |  |  |

## Generic options

Less common options for the pipeline, typically set in a config file.

| Parameter | Description | Type | Default | Required | Hidden |
|-----------|-----------|-----------|-----------|-----------|-----------|
| `help` | Display help text. | `boolean` |  |  | True |
| `version` | Display version and exit. | `boolean` |  |  | True |
| `publish_dir_mode` | Method used to save pipeline results to output directory. <details><summary>Help</summary><small>The Nextflow `publishDir` option specifies which intermediate files should be
| `email_on_fail` | Email address for completion summary, only when pipeline fails. <details><summary>Help</summary><small>An email address to send a summary email to when the pipeline is completed
| `plaintext_email` | Send plain-text email instead of HTML. | `boolean` |  |  | True |
| `max_multiqc_email_size` | File size limit when attaching MultiQC reports to summary emails. | `string` | 25.MB |  | True |
| `monochrome_logs` | Do not use coloured log outputs. | `boolean` |  |  | True |
| `hook_url` | Incoming hook URL for messaging service <details><summary>Help</summary><small>Incoming hook URL for messaging service. Currently, MS Teams and Slack are supported.</small></details>|
| `multiqc_config` | Custom config file to supply to MultiQC. | `string` |  |  | True |
| `multiqc_logo` | Custom logo file to supply to MultiQC. File name must also be set in the MultiQC config file | `string` |  |  | True |
| `multiqc_methods_description` | Custom MultiQC yaml file containing HTML including a methods description. | `string` |  |  |  |
| `validate_params` | Boolean whether to validate parameters against the schema at runtime | `boolean` | True |  | True |
| `validationShowHiddenParams` | Show all params when using `--help` <details><summary>Help</summary><small>By default, parameters set as _hidden_ in the schema are not shown on the command line whe
| `validationFailUnrecognisedParams` | Validation of parameters fails when an unrecognised parameter is found. <details><summary>Help</summary><small>By default, when an unrecognised parameter is fo
| `validationLenientMode` | Validation of parameters in lenient more. <details><summary>Help</summary><small>Allows string values that are parseable as numbers or booleans. For further information s



