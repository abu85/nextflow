// pipeline to index a transcriptome using Salmon
// and perform quantification on RNA-seq reads
params.transcriptome_file = "$projectDir/../../part2/data/ggal/transcriptome.fa"
params.reads = "$projectDir/../../part2/data/samplesheet.csv"
// params.outdir = "results"
process INDEX {
    tag "salmon index"
    container "quay.io/biocontainers/salmon:1.10.1--h7e5ed60_0"
    publishDir 'results', mode: 'copy'
    input:
    path transcriptome

    output:
    path 'salmon_index'

    script:
    """
    salmon index --transcripts $transcriptome --index salmon_index
    """
}

process FASTQC {
    tag "fastqc on ${sample_id}"
    container "quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0"
    publishDir 'results', mode: 'copy'

    input:
    tuple val(sample_id), path(reads_1), path(reads_2)

    output:
    path "fastqc/fastqc_${sample_id}_logs"

    script:
    """
    mkdir -p "fastqc/fastqc_${sample_id}_logs"
    fastqc --outdir "fastqc/fastqc_${sample_id}_logs" --format fastq $reads_1 $reads_2 -t $task.cpus
    """
}

process QUANTIFICATION {
    tag "salmon on ${sample_id}"
    container "quay.io/biocontainers/salmon:1.10.1--h7e5ed60_0"
    publishDir 'results', mode: 'copy'
    
    input:
    path salmon_index
    tuple val(sample_id), path(reads_1), path(reads_2)

    output:
    path "salmon/$sample_id"

    script:
    """
    salmon quant -i $salmon_index -l A \\
        -1 $reads_1 -2 $reads_2 \\
        -p $task.cpus --validateMappings \\
        -o salmon/$sample_id
    """
}

// multiqc process to aggregate QC results
process MULTIQC {
    container "quay.io/biocontainers/multiqc:1.9--py_0"
    publishDir 'results', mode: 'copy'

    input:
    path qc_dirs

    output:
    path "multiqc/multiqc_report.html"
    path "multiqc/multiqc_data"

    script:
    """
    multiqc $qc_dirs -o multiqc/
    """
}

// define the workflow
workflow {
    // call the INDEX process
    INDEX(params.transcriptome_file)

    // read the samplesheet and create a channel
    reads_in = Channel.fromPath(params.reads)
        .splitCsv(header:true)
        .map { row -> [row.sample, file(row.fastq_1), file(row.fastq_2)] }
    // call the FASTQC process for each sample
    FASTQC(reads_in)

    // Define the quantification channel for the index files
    transcriptome_index_in = INDEX.out[0]

    // call the QUANTIFICATION process for each sample
    QUANTIFICATION(transcriptome_index_in, reads_in)

    // call the MULTIQC process with the output of FASTQC
    // Define the multiqc input channel
    multiqc_in = FASTQC.out[0]
        .mix(QUANTIFICATION.out[0])
        .collect()

    // Run the multiqc step with the multiqc_in channel
     MULTIQC(multiqc_in)    
}