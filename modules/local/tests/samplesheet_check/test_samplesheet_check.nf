#!/usr/bin/env nextflow

// usage:
// nextflow run \
// ~/code/mblab_call_variants/modules/local/tests/samplesheet_check/test_samplesheet_check.nf \
// -c ~/code/mblab_call_variants/modules/local/tests/samplesheet_check/test.conf \
// --samplesheet_path \
// ~/code/mblab_call_variants/assets/bsa_samplesheet.csv \
// --outdir results


nextflow.enable.dsl = 2

include { validateParameters; paramsHelp; paramsSummaryLog; paramsSummaryMap; fromSamplesheet } from 'plugin/nf-validation'

// Validate input parameters
validateParameters()


workflow test_parse_samplesheet {

    // use nf-validation plugin to parse samplesheet
    Channel.fromSamplesheet("input")
        .map{meta,group,fastq_1,fastq_2,fasta ->
                [meta,group,[fastq_1,fastq_2],fasta]}
        .set{ ch_input }

    ch_input.view()

}

workflow{
    test_parse_samplesheet ()
}
