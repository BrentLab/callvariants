
include { CNVPYTOR_IMPORTREADDEPTH                } from "../../modules/nf-core/cnvpytor/importreaddepth"
include { CNVPYTOR_HISTOGRAM                      } from "../../modules/nf-core/cnvpytor/histogram"
include { CNVPYTOR_PARTITION                      } from "../../modules/nf-core/cnvpytor/partition"
include { CNVPYTOR_VIEW                           } from "../../modules/nf-core/cnvpytor/view"
include { CNVPYTOR_VIEW as CNVPYTOR_VIEW_TSV_FLTR } from "../../modules/local/cnvpytor/view"

workflow CNVPYTOR_COMPLETE {

    take:
    bam_bai  // channel: [ val(meta), path(bam), path(bai) ]
    cnvpytor_genome_conf
    cnvpytor_genome_gc_ch

    main:

    ch_versions = Channel.empty()

    CNVPYTOR_IMPORTREADDEPTH(
        bam_bai,
        cnvpytor_genome_conf,
        cnvpytor_genome_gc_ch
    )
    ch_versions = ch_versions.mix(CNVPYTOR_IMPORTREADDEPTH.out.versions.first())

    CNVPYTOR_HISTOGRAM(
        CNVPYTOR_IMPORTREADDEPTH.out.pytor
    )
    ch_versions = ch_versions.mix(CNVPYTOR_HISTOGRAM.out.versions.first())

    CNVPYTOR_PARTITION(
        CNVPYTOR_HISTOGRAM.out.pytor
    )
    ch_versions = ch_versions.mix(CNVPYTOR_PARTITION.out.versions.first())

    CNVPYTOR_VIEW(
        CNVPYTOR_PARTITION.out.pytor
    )
    ch_versions = ch_versions.mix(CNVPYTOR_VIEW.out.versions.first())

    CNVPYTOR_VIEW_TSV_FLTR(
        CNVPYTOR_PARTITION.out.pytor
    )
    ch_versions = ch_versions.mix(CNVPYTOR_VIEW_TSV_FLTR.out.versions.first())


    emit:
    versions  = ch_versions       // channel: [ versions.yml ]
}
