

//
// index the genome in various ways for various tools
//

include { CONCATFASTA                    } from "../../modules/local/concatFasta/main"
include { SAMTOOLS_FAIDX                 } from "../..//modules/nf-core/samtools/faidx/main"
include { BUILD_INTERVALS                } from "../../modules/local/build_intervals/main"
include { CREATE_INTERVALS_BED           } from "../../modules/local/create_intervals_bed/main"
include { GATK4_CREATESEQUENCEDICTIONARY } from "../..//modules/nf-core/gatk4/createsequencedictionary/main"
include { BWAMEM2_INDEX                  } from "../..//modules/nf-core/bwamem2/index/main"
include { BWA_INDEX                      } from "../..//modules/nf-core/bwa/index/main"

workflow PREPARE_GENOME {
    take:
    genome_fasta     // path(fasta)
    additional_fasta // [meta, path(additional fasta)]

    main:

    ch_versions      = Channel.empty()
    ch_reports       = Channel.empty()
    ch_aln_fasta     = Channel.empty()
    ch_main_fasta    = Channel.empty()

    //
    // concat additional fasta sequences onto the genome_fasta
    // this is only executed with additional_fasta has a fasta file
    //
    CONCATFASTA ( genome_fasta, additional_fasta )
    ch_versions = ch_versions.mix(CONCATFASTA.out.versions)

    // This (should -- keep an eye on this) create a channel where the
    // entries in the additional_fasta channel which do not have an additional
    // fasta are assigned the genome_fasta, and the rest are the result of
    // the CONCATFASTA process, eg
    // [[genome_name:main], /home/oguzkhan/ref/KN99/current_htcf_genome/KN99_genome_fungidb.fasta]
    // [[genome_name:NAT], /home/oguzkhan/Desktop/tmp_tests/work/b8/c25775fcad8a52bd7d816e52e1943e/concat.fasta]
    // [[genome_name:G418], /home/oguzkhan/Desktop/tmp_tests/work/b1/798e1f88bb3f582cca185c405990f0/concat.fasta]
    additional_fasta
        .filter { it[1].size() == 0 }
        .map { meta, _ -> meta }
        .combine(genome_fasta)
        .concat(CONCATFASTA.out.fasta)
        .set{ ch_fasta_with_meta }

    //
    // index genome with samtools faidx if not input
    //
    if(params.fasta_fai){
        exit "NOT IMPLEMENTED ERROR: using a provided fai is not yet "+
             "implemented. resubmit without fasta_fai"
        ch_fai = Channel.fromPath(params.fasta_fai)
            .collect()
    } else{
        // SAMTOOLS FAIDX now has a second argument
        SAMTOOLS_FAIDX ( ch_fasta_with_meta, [[], []] )
        ch_versions = ch_versions.mix(SAMTOOLS_FAIDX.out.versions.first())
    }

    //
    // Build intervals for parallel processing variant calling
    //
    // BUILD_INTERVALS creates a bed file from the fai
    BUILD_INTERVALS(
        SAMTOOLS_FAIDX.out.fai
    )
    ch_versions = ch_versions.mix(BUILD_INTERVALS.out.versions)

    // CREATE_INTERVALS_BED splits the bed file by line
    CREATE_INTERVALS_BED(
        BUILD_INTERVALS.out.bed
    )
    ch_versions = ch_versions.mix(CREATE_INTERVALS_BED.out.versions)

    // transpose the channel so that we get
    // [[meta, bed_chunk1], [meta, bed_chunk2], ...]
    CREATE_INTERVALS_BED.out.bed
        .transpose()
        .map{ meta, bed_chunk ->
            [meta.genome_name, [interval: bed_chunk.getBaseName()], bed_chunk]}
        .set{ ch_intervals }

    //
    // index the genome with bwamem2 index if not passed
    //
    if(params.bwamem2_index){
        exit "NOT IMPLEMENTED ERROR: using a provided bwamem2 index is not yet " +
             "implemented. resubmit without bwamem2_index"
        ch_bwamem2_index = Channel.fromPath(params.bwamem2_index).collect()
    } else {
        BWAMEM2_INDEX ( ch_fasta_with_meta )
        ch_versions = ch_versions.mix(BWAMEM2_INDEX.out.versions)
    }

    //
    // index genome with bwa index (index for bwa aln) for TIDIT SV
    //
    BWA_INDEX( ch_fasta_with_meta )
    ch_versions = ch_versions.mix(BWA_INDEX.out.versions)

    GATK4_CREATESEQUENCEDICTIONARY( ch_fasta_with_meta )
    ch_versions   = ch_versions.mix(GATK4_CREATESEQUENCEDICTIONARY.out.versions)

    ch_fasta_with_meta
        .join(SAMTOOLS_FAIDX.out.fai)
        .join(BWAMEM2_INDEX.out.index)
        .join(BWA_INDEX.out.index)
        .join(GATK4_CREATESEQUENCEDICTIONARY.out.dict)
        .join(BUILD_INTERVALS.out.bed)
        .map{ meta, fasta, fai, bwamem2_index, bwa_index, genome_dict, intervals_bed ->
            [meta.genome_name, fasta, fai, bwamem2_index, bwa_index, genome_dict, intervals_bed]}
        .set{ ch_genome_data }



    emit:
    genome_data     = ch_genome_data // [genome_name, path(genome), path(fai), path(bwamem2_index), path(bwa_index), path(genome_dict), path(intervals_bed)]
    intervals       = ch_intervals   // [[genome_name, [interval: chunk1], chunk1.bed], [genome_name, [interval: chunk2], chunk2.bed], ... ]
    versions        = ch_versions    // channel: [ versions.yml ]
}
