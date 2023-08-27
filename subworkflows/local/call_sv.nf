include { TIDDIT_SV                                     } from "../../modules/nf-core/tiddit/sv/main"
include { TIDDIT_COV                                    } from '../../modules/nf-core/tiddit/cov/main'
include { TABIX_BGZIPTABIX as TABIX_BGZIPTABIX_TIDDIT   } from '../../modules/nf-core/tabix/bgziptabix/main'
include { TABIX_BGZIPTABIX as TABIX_BGZIPTABIX_RAW      } from '../../modules/nf-core/tabix/bgziptabix/main'
include { TABIX_BGZIPTABIX as TABIX_BGZIPTABIX_FLTR     } from '../../modules/nf-core/tabix/bgziptabix/main'
include { CNVPYTOR_CSV as CNVPYTOR_CSV_RAW              } from "../../modules/local/cnvpytor/csv/main"
include { CNVPYTOR_CSV as CNVPYTOR_CSV_FLTR             } from "../../modules/local/cnvpytor/csv/main"
include { SNPEFF as SNPEFF_RAW                          } from '../../modules/nf-core/snpeff/snpeff/main'
include { SNPEFF as SNPEFF_FLTR                         } from '../../modules/nf-core/snpeff/snpeff/main'
include { BCFTOOLS_STATS as BCFTOOLS_STATS_RAW          } from "../../modules/nf-core/bcftools/stats/main"
include { BCFTOOLS_STATS as BCFTOOLS_STATS_FLTR         } from "../../modules/nf-core/bcftools/stats/main"
include { VCFTOOLS                                      } from "../../modules/nf-core/vcftools/main"

workflow CALL_SV {
    // note that bam_bai_with_genome_data_interval_split has one entry for
    // each of the intervals generated in PREPARE_GENOME.
    // bam_bai_with_genome_data is one entry per sample

    take:
    bam_bai_with_genome_data  //  [meta, bam, bai, path(genome), path(fai), path(bwamem2_index), path(bwa_index), path(genome_dict), path(intervals_bed)]
    region_bed_mask
    cnvpytor_genome_conf
    cnvpytor_genome_gc_ch
    snpeff_config
    snpeff_db

    main:

    ch_versions                            = Channel.empty()
    ch_reports                             = Channel.empty()
    ch_individual_collected_freebayes_vcfs = Channel.empty()
    ch_all_vcfs                            = Channel.empty()

    // Setup input for cnpytor and TIDDIT
    bam_bai_with_genome_data
        .multiMap{ it ->
            bam_bai: [it[0], it[1], it[2]]
            genome: [it[0], it[3]]
            bwa_index: [it[0], it[6]]
        }
        .set{ cnvpytor_tiddit_input }

    //
    // TIDDIT coverage mode
    //
    TIDDIT_COV(
        cnvpytor_tiddit_input.bam_bai.map{ meta, bam, bai -> [meta, bam]},
        cnvpytor_tiddit_input.genome
    )
    ch_versions = ch_versions.mix(TIDDIT_COV.out.versions.first())
    ch_reports = ch_reports.mix(TIDDIT_COV.out.cov.map{ it -> it[1]})

    //
    // TIDDIT discordant pair and other SV mode
    //
    TIDDIT_SV(
        cnvpytor_tiddit_input.bam_bai,
        cnvpytor_tiddit_input.genome,
        cnvpytor_tiddit_input.bwa_index
    )
    ch_versions = ch_versions.mix(TIDDIT_SV.out.versions.first())
    ch_reports = ch_reports.mix(TIDDIT_SV.out.ploidy.map{ it -> it[1]})

    // zip, index and add the key 'variant_caller' to the meta
    TABIX_BGZIPTABIX_TIDDIT(
        TIDDIT_SV.out.vcf
            .map{ meta, vcf ->
                def new_meta = meta.clone()
                new_meta.variant_caller = 'tiddit'
                [new_meta, vcf] } )
    ch_versions = ch_versions.mix(TABIX_BGZIPTABIX_TIDDIT.out.versions.first())

    ch_all_vcfs = ch_all_vcfs.mix(TABIX_BGZIPTABIX_TIDDIT.out.gz_tbi)

    //
    // call CNVs unfiltered
    //
    CNVPYTOR_CSV_RAW(
        cnvpytor_tiddit_input.bam_bai,
        cnvpytor_genome_conf,
        cnvpytor_genome_gc_ch
    )
    ch_versions = ch_versions.mix(CNVPYTOR_CSV_RAW.out.versions)

    //
    // call CNVs filtered
    // TODO in future, just parse the raw csv outputs
    CNVPYTOR_CSV_FLTR(
        cnvpytor_tiddit_input.bam_bai,
        cnvpytor_genome_conf,
        cnvpytor_genome_gc_ch
    )

    //
    // Annotate the variants with snpEff
    //
    SNPEFF_RAW(
        ch_all_vcfs.map{meta, vcf_gz, vcf_gz_tbi -> [meta, vcf_gz]},
        snpeff_config,
        snpeff_db
    )
    ch_versions = ch_versions.mix(SNPEFF_RAW.out.versions.first())
    ch_reports = ch_reports.mix(SNPEFF_RAW.out.report)

    TABIX_BGZIPTABIX_RAW(SNPEFF_RAW.out.vcf)

    BCFTOOLS_STATS_RAW(
        TABIX_BGZIPTABIX_RAW.out.gz_tbi,
        [[],[]],
        [[],[]],
        [[],[]],
        [[],[]],
        [[],[]]
    )
    ch_versions = ch_versions.mix(BCFTOOLS_STATS_RAW.out.versions.first())
    ch_reports = ch_reports.mix(BCFTOOLS_STATS_RAW.out.stats.map{it -> it[1]})

    // filter the VCFs
    // TODO: SPLIT THIS INTO A INDIVIDUAL AND JOINT TO PROVIDE
    // MORE FINE TUNED FILTERING
    VCFTOOLS(
        ch_all_vcfs.map{ meta, vcf_gz, vcf_tbi -> [meta, vcf_gz]},
        region_bed_mask,
        []
    )
    ch_versions   = ch_versions.mix(VCFTOOLS.out.versions.first())

    TABIX_BGZIPTABIX_FLTR( VCFTOOLS.out.vcf )

    SNPEFF_FLTR(
        TABIX_BGZIPTABIX_FLTR.out.gz_tbi.map{meta, vcf_gz, vcf_gz_tbi -> [meta, vcf_gz]},
        snpeff_config,
        snpeff_db
    )
    ch_reports = ch_reports.mix(SNPEFF_FLTR.out.report)

    BCFTOOLS_STATS_FLTR(
        TABIX_BGZIPTABIX_FLTR.out.gz_tbi,
        [[],[]],
        [[],[]],
        [[],[]],
        [[],[]],
        [[],[]]
    )
    ch_reports = ch_reports.mix(BCFTOOLS_STATS_FLTR.out.stats.map{ it -> it[1]})

    emit:
    vcf = VCFTOOLS.out.vcf   // channel: [val(meta), path(vcf) ]
    reports = ch_reports    // channel: [ reports.yml ]
    versions  = ch_versions  // channel: [ versions.yml ]
}
