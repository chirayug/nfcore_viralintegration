process INSERTION_SITE_CANDIDATES {
    tag "$meta.id"

    // TODO Use python 3.6.9 and pigz in their own container
    if (params.enable_conda) {
        exit 1, "Conda environments cannot be used when using the PolyA-stripper script. Please use docker or singularity containers."
    }
    container "trinityctat/ctat_vif"

    input:
    tuple val(meta), path(bam), path(bai), path(chimeric_junction)
    path ref_genome_fasta
    path viral_fasta

    output:
    path "*.full.tsv"                    , emit: full
    path "*.full.abridged.tsv"           , optional: true, emit: full_abridged
    path "*.genome_chimeric_evidence.bam", emit: genome_chimeric_evidence_reads_bam
    path "*.genome_chimeric_evidence.bai", emit: genome_chimeric_evidence_reads_bai
    path "human_virus_chimJ.tsv"         , emit: human_virus_chimJ
    path "versions.yml"                  , emit: versions

    script: // This script is bundled with the pipeline, in nf-core/viralintegration/bin/
    // TODO Move to modules.config?
    def prefix = task.ext.prefix ?: "${meta.id}.vif.init"
    def remove_duplicates = '--remove_duplicates'
    // TODO remove duplicates option
    """
    pre_filter_non_human_virus_chimeric_alignments.py  \\
        --chimJ ${chimeric_junction} \\
        --viral_db_fasta ${viral_fasta} \\
        --output human_virus_chimJ.tsv

    chimJ_to_virus_insertion_candidate_sites.py \\
        --chimJ human_virus_chimJ.tsv \\
        --viral_db_fasta ${viral_fasta} \\
        --max_multi_read_alignments ${params.max_hits} \\
        --output_prefix ${prefix}.tmp \\
        ${remove_duplicates}

    # extract the chimeric read alignments:
    extract_prelim_chimeric_genome_read_alignments.py \\
        --star_bam ${bam} \\
        --vif_full_tsv ${prefix}.tmp.full.tsv \\
        --output_bam ${prefix}.genome_chimeric_evidence.bam

    # add evidence read stats
    incorporate_read_alignment_stats.py \\
        --supp_reads_bam ${prefix}.genome_chimeric_evidence.bam \\
        --vif_full_tsv ${prefix}.tmp.full.tsv \\
        --output ${prefix}.full.w_read_stats.tsv

    # add seq entropy around breakpoints
    incorporate_breakpoint_entropy_n_splice_info.py \\
        --vif_tsv  ${prefix}.full.w_read_stats.tsv \\
        --ref_genome_fasta ${ref_genome_fasta} \\
        --viral_genome_fasta ${viral_fasta} \\
        --output ${prefix}.full.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
