process CONCATFASTA {

    conda "bioconda::coreutils=8.25"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://depot.galaxyproject.org/singularity/coreutils:8.25--1' :
    'biocontainers/coreutils:8.25--1' }"

    input:
        path(main_fasta)
        tuple val(meta), path(additional_fasta)

    output:
        tuple val(meta), path("*concat.fasta") , emit: fasta
        path "versions.yml"                    , emit: versions

    when:
    (task.ext.when == null && additional_fasta.size() > 0) || (task.ext.when && additional_fasta.size() > 0)

    script:

    def args        = task.ext.args     ?: ''
    def prefix      = task.ext.prefix   ?: "${meta.id}"
    def suffix      = task.ext.suffix   ?: ""
    def filename    = prefix + suffix + "_concat.fasta"
    def VERSION     = "8.25"    // WARN: Version information not provided by
                                // tool on CLI. Please update this string
                                // when bumping container versions.

    """
    cat ${main_fasta} ${additional_fasta} > ${filename}

    cat <<-END_VERSIONS > versions.yml
        "${task.process}":
        coreutils: $VERSION
    END_VERSIONS
    """
}


// process CONCATFASTA {

//     conda "bioconda::coreutils=8.25"
//     container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
//     'https://depot.galaxyproject.org/singularity/coreutils:8.25--1' :
//     'biocontainers/coreutils:8.25--1' }"

//     input:
//         path(main_fasta)
//         tuple val(meta), path(additional_fasta)

//     output:
//         tuple val(meta), path "*concat.fasta", emit: fasta
//         path "versions.yml"                  , emit: versions

//     when:
//     task.ext.when == null || task.ext.when // && additional_fasta.size() > 0

//     script:

//     def args        = task.ext.args     ?: ''
//     def prefix      = task.ext.prefix   ?: ""
//     def suffix      = task.ext.suffix   ?: ""
//     def filename    = prefix + suffix + "concat.fasta"
//     def VERSION     = "8.25"    // WARN: Version information not provided by
//                                 // tool on CLI. Please update this string
//                                 // when bumping container versions.

//     """
//     cat ${main_fasta} ${additional_fasta} > ${filename}

//     cat <<-END_VERSIONS > versions.yml
//         "${task.process}":
//         coreutils: $VERSION
//     END_VERSIONS
//     """

//     stub:
//     // Stub script block - this will be executed in stub-run mode

//     """
//     touch concat.fasta
//     echo '"${task.process}": coreutils: 8.25' > versions.yml
//     """
// }
