/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap; fromSamplesheet } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowCallvariants.initialise(params, log)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { PREPARE_GENOME } from "${projectDir}/subworkflows/local/prepare_genome"
include { ALIGN          } from "${projectDir}/subworkflows/local/align"
include { CALL_SV        } from "${projectDir}/subworkflows/local/call_sv"
include { CALL_SNV       } from "${projectDir}/subworkflows/local/call_snv"

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                      } from '../modules/nf-core/fastqc/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SET PARAM FILE CHANNELS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

fasta = params.fasta     ?
        Channel.fromPath(params.fasta, checkIfExists: true).collect()     :
        Channel.empty()

cnvpytor_genome_conf_ch = params.cnvpytor_conf_file ?
                          Channel.fromPath(params.cnvpytor_conf_file, checkIfExists: true).collect():
                          Channel.empty()

cnvpytor_genome_gc_ch = params.cnvpytor_gc_file ?
                          Channel.fromPath(params.cnvpytor_gc_file, checkIfExists: true).collect():
                          Channel.empty()

ch_snpeff_db = params.snpeff_db ?
            Channel.fromPath(params.snpeff_db, checkIfExists: true).collect():
            Channel.empty()

ch_snpeff_config = params.snpeff_db_config ?
            Channel.fromPath(params.snpeff_db_config, checkIfExists: true).collect():
            Channel.empty()

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow CALLVARIANTS {

    // store software versions from all processes
    ch_versions = Channel.empty()
    // store reports that will be consumed by multiQC
    ch_reports = Channel.empty()

    annotate_variants_input = Channel.empty()

    ch_region_bed_mask = params.region_bed_mask ?
                         Channel.fromPath(params.region_bed_mask).collect() :
                         Channel.empty()

    ch_main_fasta = params.fasta ?
                    Channel.fromPath(params.fasta, checkIfExists: true).collect() :
                    Channel.empty()

    //
    // use nf-validation plugin to parse samplesheet
    //
    ch_input = Channel.fromSamplesheet("input")
        .multiMap{ sample, group, genome_name, fastq_1, fastq_2, additional_fasta ->
            def single_end = fastq_2.size() == 0
            def reads = single_end ? [fastq_1] : [fastq_1, fastq_2]
            reads: [["id": sample,
                     "group": group,
                     "genome_name": genome_name,
                     "single_end": single_end], reads]
            genome: [["genome_name": genome_name], additional_fasta]
        }

    // check that for any given genome_name there is only one additional_fasta
    ch_additional_fasta = ch_input.genome.unique()

    ch_additional_fasta
        .map { it[0].genome_name }
        .collect()
        .subscribe { genome_names ->
            def genome_name_counts = genome_names.groupBy { it }.collectEntries { k, v -> [k, v.size()] }
            def duplicates = genome_name_counts.findAll { k, v -> v > 1 }

            if (duplicates) {
                error "Found duplicate genome names: ${duplicates.keySet().join(', ')}"
            }
        }

    //
    // SUBWORKFLOW: Prepare the genome indicies, etc
    //
    PREPARE_GENOME (
        ch_main_fasta,
        ch_additional_fasta
    )
    ch_versions = ch_versions.mix(PREPARE_GENOME.out.versions)

    //
    // MODULE: Run FastQC
    //
    FASTQC (
        ch_input.reads
    )
    ch_reports  = ch_reports.mix(FASTQC.out.zip.collect{meta, logs -> logs})
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    ch_input.reads
        .map { meta, reads -> [meta.genome_name, meta, reads] }
        .combine(PREPARE_GENOME.out.genome_data, by:0)
        .map{ it -> it[1..-1] } // remove genome_name from tuple
        .set { ch_reads_with_genome_data }

    //
    // SUBWORKFLOW: Align the reads with bwamem2
    //
    ALIGN (
        ch_reads_with_genome_data
    )
    ch_reports  = ch_reports.mix(ALIGN.out.reports)
    ch_versions = ch_versions.mix(ALIGN.out.versions)

    ALIGN.out.bam_bai
        .map{ meta, bam, bai -> [meta.genome_name, meta, bam, bai] }
        .combine(PREPARE_GENOME.out.genome_data, by:0)
        .tap { ch_bam_bai_with_genome_data_raw }
        .combine(PREPARE_GENOME.out.intervals, by:0)
        // result is [genome_name, meta, bam, bai, path(genome), path(fai), path(bwamem2_index), path(bwa_index), path(genome_dict), path(intervals_bed), [interval: interval_name], interval_bed]
        .map{ it -> [it[1] + it[10], *(it[2..9]), it[11]] }
        .set { ch_bam_bai_with_genome_data_interval_split }

    ch_bam_bai_with_genome_data_raw
        .map{ it -> [it[1], *(it[2..-1])] }
        .set { ch_bam_bai_with_genome_data }

    //
    // SUBWORKFLOW: Call variants using CNVpytor, TIDDIT and Freebayes
    //
    CALL_SV (
        ch_bam_bai_with_genome_data,
        ch_region_bed_mask,
        cnvpytor_genome_conf_ch,
        cnvpytor_genome_gc_ch,
        ch_snpeff_config,
        ch_snpeff_db
    )
    ch_reports = ch_reports.mix(CALL_SV.out.reports)
    ch_versions = ch_versions.mix(CALL_SV.out.versions)

    //
    // SUBWORKFLOW: Call small nucleotide variants
    //
    CALL_SNV (
        ch_bam_bai_with_genome_data_interval_split,
        ch_region_bed_mask,
        cnvpytor_genome_conf_ch,
        cnvpytor_genome_gc_ch,
        ch_snpeff_config,
        ch_snpeff_db
    )
    ch_reports = ch_reports.mix(CALL_SNV.out.reports)
    ch_versions = ch_versions.mix(CALL_SNV.out.versions)

    //
    // MODULE: MultiQC
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    workflow_summary    = WorkflowCallvariants.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowCallvariants.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description, params)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files =  Channel.empty().mix(ch_reports.collect().ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
