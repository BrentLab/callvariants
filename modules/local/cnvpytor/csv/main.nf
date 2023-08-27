process CNVPYTOR_CSV {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::cnvpytor=1.3.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/cnvpytor%3A1.3.1--pyhdfd78af_1':
        'biocontainers/cnvpytor:1.3.1--pyhdfd78af_1' }"

    input:
    tuple val(meta), path(bams), path(bais)
    path(cnvpytor_conf)
    path(cnvpytor_genome_gc_ch)

    output:
    tuple val(meta), path("*.pytor"), emit: pytor
    tuple val(meta), path("*.csv")  , emit: csv
    path "versions.yml"             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def bins   = task.ext.args?.bins ?: '1000'
    def filter = task.ext.args?.filter ?: ''
    def min_cnv_depth_dup = task.ext.args?.min_cnv_depth_dup ?: '0.0'
    def min_cnv_depth_del = task.ext.args?.min_cnv_depth_del ?: '100.0'
    def input  = bams.join(" ")
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    cnvpytor_csv.py \\
        --bams ${input} \\
        --bins ${bins} \\
        --prefix ${prefix} \\
        --min_cnv_depth_dup ${min_cnv_depth_dup} \\
        --max_cnv_depth_del ${min_cnv_depth_del} \\
        --max_cores ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cnvpytor: \$(echo \$(cnvpytor --version 2>&1) | sed 's/CNVpytor //' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.pytor
    touch ${prefix}.csv
    touch versions.yml
    """
}
