process CNVPYTOR_VIEW {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::cnvpytor=1.2.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/cnvpytor:1.2.1--pyhdfd78af_0':
        'biocontainers/cnvpytor:1.2.1--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(pytor_files)

    output:
    tuple val(meta), path("*.tsv"), emit: tsv      , optional: true
    tuple val(meta), path("*.xls"), emit: xls      , optional: true
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def output_suffix = 'tsv'
    def bins   = task.ext.args?.bins ?: '1000'
    def filter = task.ext.args?.filter ?: ''
    def min_cnv_depth = task.ext.args?.min_cnv_depth ?: '0'
    def input  = pytor_files.join(" ")
    def prefix = task.ext.prefix ?: "${meta.id}"
    """

    cnvpytor_view_tsv_with_fltr.py \\
        --input "${pytor_files}" \\
        --bins "${bins}" \\
        --prefix "${prefix}" \\
        --output-suffix "${output_suffix}" \\
        --min-cnv-depth ${min_cnv_depth} \\
        --filter "${filter}"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cnvpytor: \$(echo \$(cnvpytor --version 2>&1) | sed 's/CNVpytor //' )
    END_VERSIONS
    """

    stub:
    def output_suffix = output_format ?: 'vcf'
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.${output_suffix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cnvpytor: \$(echo \$(cnvpytor --version 2>&1) | sed 's/CNVpytor //' )
    END_VERSIONS
    """
}
