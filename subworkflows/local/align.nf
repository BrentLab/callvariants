//
// Align reads to a reference genome
//

include { BWAMEM2_MEM                   } from "../../modules/nf-core/bwamem2/mem/main"
include { PICARD_MARKDUPLICATES        } from "../../modules/nf-core/picard/markduplicates/main"
include { PICARD_ADDORREPLACEREADGROUPS } from "../../modules/nf-core/picard/addorreplacereadgroups/main"
include { BAM_SORT_STATS_SAMTOOLS } from '../nf-core/bam_sort_stats_samtools/main'

workflow ALIGN {
    take:
    reads_with_genome_data //  [meta, reads, path(genome), path(fai), path(bwamem2_index), path(bwa_index), path(genome_dict), path(intervals_bed)]

    main:

    ch_versions    = Channel.empty()
    ch_reports     = Channel.empty()

    BWAMEM2_MEM (
        reads_with_genome_data.map{ it -> [it[0], it[1]]},
        reads_with_genome_data.map{ it -> [it[0], it[4]]},
        true
    )
    ch_versions = ch_versions.mix(BWAMEM2_MEM.out.versions.first())

    PICARD_MARKDUPLICATES(
        BWAMEM2_MEM.out.bam,
        reads_with_genome_data.map{ it -> [it[0], it[2]]},
        [[],[]]
    )
    ch_versions = ch_versions.mix(PICARD_MARKDUPLICATES.out.versions.first())

    PICARD_ADDORREPLACEREADGROUPS(
        PICARD_MARKDUPLICATES.out.bam,
    )
    ch_versions = ch_versions.mix(PICARD_ADDORREPLACEREADGROUPS.out.versions.first())

    BAM_SORT_STATS_SAMTOOLS(
        PICARD_ADDORREPLACEREADGROUPS.out.bam,
        reads_with_genome_data.map{ it -> [it[0], it[2]]}
    )

    BAM_SORT_STATS_SAMTOOLS.out.bam
        .join(BAM_SORT_STATS_SAMTOOLS.out.bai)
        .set { ch_bam_bai }

    // Gather QC reports
    ch_reports  = ch_reports.mix(PICARD_MARKDUPLICATES.out.metrics.collect{it[1]}.ifEmpty([]))
    ch_reports  = ch_reports.mix(BAM_SORT_STATS_SAMTOOLS.out.stats.collect{it[1]}.ifEmpty([]))
    ch_reports  = ch_reports.mix(BAM_SORT_STATS_SAMTOOLS.out.flagstat.collect{it[1]}.ifEmpty([]))
    ch_reports  = ch_reports.mix(BAM_SORT_STATS_SAMTOOLS.out.idxstats.collect{it[1]}.ifEmpty([]))
    // Gather used softwares versions
    ch_versions = ch_versions.mix(BAM_SORT_STATS_SAMTOOLS.out.versions)

    emit:
    // channel: [ val(meta), [ bam ], [ bai ] ]
    bam_bai   = ch_bam_bai   // bam and bai files
    reports   = ch_reports   // qc reports
    versions  = ch_versions  // channel: [ versions.yml ]
}
