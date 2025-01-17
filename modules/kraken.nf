nextflow.enable.dsl=2


process kraken2 {
    tag "${id}"

    publishDir "${params.outdir}/kraken2/" , mode: 'copy'

    input:
    tuple val(id), path(reads)
    path kraken2_db
    
    output:
    tuple val(id), path("${id}.kraken2.report"), emit: report
    tuple val(id), path("${id}.kraken2.mpa"), emit: mpa
    tuple val(id), path("${id}." + params.classified_out.replaceAll("#", "_1")), optional: true
    tuple val(id), path("${id}." + params.classified_out.replaceAll("#", "_2")), optional: true
    tuple val(id), path("${id}." + params.unclassified_out.replaceAll("#", "_1")), optional: true
    tuple val(id), path("${id}." + params.unclassified_out.replaceAll("#", "_2")), optional: true

    script:
    input = params.single_end ? "\"$reads\"" :  "--paired \"${reads[0]}\" \"${reads[1]}\""
    report_zero_counts = params.report_zero_counts ? "--report-zero-counts" : ""
    classified_reads = params.classified_out ? "--classified-out ${id}." + params.classified_out : ""
    unclassified_reads = params.unclassified_out ? "--unclassified-out ${id}." + params.unclassified_out : ""

    """
    kraken2 \
        --db $kraken2_db \
        --threads ${task.cpus} \
        $report_zero_counts \
        $classified_reads \
        $unclassified_reads \
        --report ${id}.kraken2.report \
        $input > /dev/null

    kreport2mpa.py \
        -r ${id}.kraken2.report \
        -o ${id}.kraken2.mpa \
        --display-header
    """
}

process bracken {
    tag "${level}-${id}"

    publishDir "${params.outdir}/bracken/${id}" , mode: 'copy'

    input:
    tuple val(level), val(id), path(kraken2_report)
    path kraken2_db

    output:
    tuple val(level), path("${id}.${level}.bracken"), emit: bracken
    tuple val(level), path("${id}.${level}.bracken.report"), emit: report
    tuple val(level), path("${id}.${level}.bracken.mpa"), emit: mpa
    
    script:
    """
    bracken \
        -d $kraken2_db \
        -r ${params.read_len} \
        -l $level \
        -i $kraken2_report \
        -o ${id}.${level}.bracken \
        -w ${id}.${level}.bracken.report

    kreport2mpa.py \
        -r ${id}.${level}.bracken.report \
        -o ${id}.${level}.bracken.mpa \
        --display-header
    """
}

process combine_kraken2_reports {

    publishDir "${params.outdir}" , mode: 'copy'

    input:
    path(kraken2_reports)

    output:
    path "combined.kraken2.report"
    
    script:
    """
    combine_kreports.py \
        -r ${kraken2_reports} \
        -o combined.kraken2.report
    """
}

process combine_kraken2_mpa {

    publishDir "${params.outdir}" , mode: 'copy'

    input:
    path(kraken2_mpa)

    output:
    path "combined.kraken2.mpa"
    
    script:
    """
    combine_mpa.py \
        -i ${kraken2_mpa} \
        -o combined.kraken2.mpa
    """
}


process combine_bracken {
    tag "${level}"

    publishDir "${params.outdir}/combined_bracken" , mode: 'copy'

    input:
    tuple val(level), path(bracken)

    output:
    path "combined.${level}.bracken"
    
    script:
    """
    python /usr/local/bracken/analysis_scripts/combine_bracken_outputs.py \
        --files $bracken \
        --output combined.${level}.bracken
    """
}

process combine_bracken_reports {
    tag "${level}"

    publishDir "${params.outdir}/combined_bracken_report" , mode: 'copy'

    input:
    tuple val(level), path(bracken_reports)

    output:
    path "combined.${level}.bracken.report"
    
    script:
    """
    combine_kreports.py \
        -r ${bracken_reports} \
        -o combined.${level}.bracken.report
    """
}

process combine_bracken_mpa {
    tag "${level}"

    publishDir "${params.outdir}/combined_bracken_mpa" , mode: 'copy'

    input:
    tuple val(level), path(bracken_mpa)

    output:
    path "combined.${level}.bracken.mpa"
    
    script:
    """
    combine_mpa.py \
        -i ${bracken_mpa} \
        -o combined.${level}.bracken.mpa
    """
}
