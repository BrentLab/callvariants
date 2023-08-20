include { FREEBAYES as FREEBAYES_INDIVIDUAL             } from "../../modules/nf-core/freebayes/main"
include { FREEBAYES_JOINT                               } from "../../modules/local/freebayes_joint/main"
include { TABIX_BGZIPTABIX as TABIX_BGZIPTABIX_RAW      } from '../../modules/nf-core/tabix/bgziptabix/main'
include { TABIX_BGZIPTABIX as TABIX_BGZIPTABIX_FLTR     } from '../../modules/nf-core/tabix/bgziptabix/main'
include { GATK4_MERGEVCFS as GATK4_MERGEVCFS_INDIVIDUAL } from "../../modules/nf-core/gatk4/mergevcfs/main"
include { GATK4_MERGEVCFS as GATK4_MERGEVCFS_JOINT      } from "../../modules/nf-core/gatk4/mergevcfs/main"
include { SNPEFF as SNPEFF_RAW                          } from '../../modules/nf-core/snpeff/snpeff/main'
include { SNPEFF as SNPEFF_FLTR                         } from '../../modules/nf-core/snpeff/snpeff/main'
include { BCFTOOLS_STATS as BCFTOOLS_STATS_RAW          } from "../../modules/nf-core/bcftools/stats/main"
include { BCFTOOLS_STATS as BCFTOOLS_STATS_FLTR         } from "../../modules/nf-core/bcftools/stats/main"
include { VCFTOOLS                                      } from "../../modules/nf-core/vcftools/main"

workflow CALL {
    // note that bam_bai_with_genome_data_interval_split has one entry for
    // each of the intervals generated in PREPARE_GENOME.
    // bam_bai_with_genome_data is one entry per sample

    take:
    bam_bai_with_genome_data_interval_split  //  [meta, bam, bai, path(genome), path(fai), path(bwamem2_index), path(bwa_index), path(genome_dict), path(intervals_bed), path(interval_subset)]
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

    // if call_individual_variants is true, then use freebayes to call
    // variants individually
    if (params.call_individual_variants){

        bam_bai_with_genome_data_interval_split
            .multiMap{ it ->
                bam_bai: [it[0], it[1], it[2], [], [], it[-1]]
                genome: it[3]
                fai: it[4]
                sequence_dict: [it[0].genome_name, it[7]]
            }
            .set{ freebayes_individual_input }

        //
        // Run freebayes on individual by chunk to call SNVs and indels
        //
        FREEBAYES_INDIVIDUAL(
            freebayes_individual_input.bam_bai,
            freebayes_individual_input.genome,
            freebayes_individual_input.fai,
            [],
            [],
            []
        )
        ch_versions = ch_versions.mix(FREEBAYES_INDIVIDUAL.out.versions.first())

        // combine chunks into a single channel
        FREEBAYES_INDIVIDUAL.out.vcf
            .map{ meta, vcf ->
                def new_meta = meta.clone() // Clone if you don't want to modify the original
                new_meta.remove('interval') // Remove the key 'interval'
                [meta.id, new_meta, vcf]
            }
            .groupTuple(by: 0)
            .map{ id, meta_list, vcf_list ->
                def meta = meta_list[0].clone()
                meta.variant_caller = 'freebayes'
                [meta, vcf_list] }
            .set{ ch_individual_collected_freebayes_vcfs }

        // merge
        GATK4_MERGEVCFS_INDIVIDUAL(
            ch_individual_collected_freebayes_vcfs,
            [[],[]]
        )
        ch_versions = ch_versions.mix(GATK4_MERGEVCFS_INDIVIDUAL.out.versions.first())


        // collect the freebayes and tiddit SV into a single channel
        // structure [meta, path(vcf.gz), path(vcf.gz.tbi)]
        ch_individual_gz_tbi = GATK4_MERGEVCFS_INDIVIDUAL.out.vcf
            .join(GATK4_MERGEVCFS_INDIVIDUAL.out.tbi)

        ch_all_vcfs = ch_all_vcfs.mix(ch_individual_gz_tbi)

    }

    if (params.call_joint_variants){
        //
        // Run freebayes on group by chunk to call SNVs and indels
        //

        // this creates sets of group and interval
        // the result looks like this:
        //    [[it:1, interval:CP022321.1_1-2291500],
        //      [/home/oguzkhan/Desktop/tmp_tests/work/30/91fbd5060fdc43473c073502d90cc9/A2-102-5.bam,
        //       /home/oguzkhan/Desktop/tmp_tests/work/f8/2d5be3bce8c535e61369476751473f/A1-35-8.bam],
        //       [/home/oguzkhan/Desktop/tmp_tests/work/7f/66bddfb7a318f614e0f51ef1edc7dc/A2-102-5.bam.bai,
        //       /home/oguzkhan/Desktop/tmp_tests/work/9b/61a17704d886af6dace9cf5e09da9f/A1-35-8.bam.bai],
        //       genome.fa,
        //       genome.fai
        //       /home/oguzkhan/Desktop/tmp_tests/work/b1/d8b3869738ad630a495b8dfa2a7657/CP022321.1_1-2291500.bed]
        // before getting split into different channels by multimap
        // note that only one of the interval beds, genome, fai is necessary -- it will be the
        // same for the set
        bam_bai_with_genome_data_interval_split
            .map{it -> [[id:it[0].group,
                        interval:it[0].interval], it[1], it[2], it[3], it[4], it[7], it[-1]]}
            .groupTuple(by: 0)
            .multiMap{meta, bam_list, bai_list, genome_list, fai_list, sequence_dict_list, interval_list ->
                bam_bai: [meta, bam_list, bai_list, interval_list[0] ]
                genome: genome_list[0]
                fai: fai_list[0]
                sequence_dict: [meta.genome_name, sequence_dict_list[0]]}
            .set{ freebayes_joint_input }

        FREEBAYES_JOINT(
            freebayes_joint_input.bam_bai,
            freebayes_joint_input.genome,
            freebayes_joint_input.fai,
            [],
            [],
            []
        )
        ch_versions   = ch_versions.mix(FREEBAYES_JOINT.out.versions.first())

        // combine chunks into a single channel
        FREEBAYES_JOINT.out.vcf
            .map{ meta, vcf ->
                def new_meta = meta.clone() // Clone if you don't want to modify the original
                new_meta.remove('interval') // Remove the key 'interval'
                [meta.id, new_meta, vcf]
            }
            .groupTuple(by: 0)
            .map{ it, meta_list, vcf_list ->
                def meta = meta_list[0].clone()
                meta.variant_caller = 'freebayes'
                [meta, vcf_list] }
            .set{ ch_joint_collected_freebayes_vcfs }

        // merge
        GATK4_MERGEVCFS_JOINT(
            ch_joint_collected_freebayes_vcfs,
            [[],[]]
        )
        ch_versions = ch_versions.mix(GATK4_MERGEVCFS_JOINT.out.versions.first())

        // structure [meta, path(vcf.gz), path(vcf.gz.tbi)]
        ch_joint_gz_tbi = GATK4_MERGEVCFS_JOINT.out.vcf
            .join(GATK4_MERGEVCFS_JOINT.out.tbi)

        ch_all_vcfs = ch_all_vcfs.mix(ch_joint_gz_tbi)

    }

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
