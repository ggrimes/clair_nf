nextflow.enable.dsl=2


process clair_calls {
  tag "{$bam.simpleName}_chr${ctg}"
  label 'high_memory'
  conda '/exports/igmm/eddie/tomlinson-CRC-promethion/analysis/clair/clair-env'
  cpus 8 

  input:
    tuple val(sampleID), file(bam) 
    val reference 
    path clair
    each ctg
    val model
    val threshold

  output:
    tuple val("${sampleID}"),file('*.vcf')
  
  script:
  """
  python clair.py \
  callVarBam \
  --chkpnt_fn $model \
  --ref_fn ${reference} \
  --bam_fn ${sampleID}.bam \
  --threshold ${threshold} \
  --minCoverage "4" \
  --pypy "pypy3" \
  --samtools "samtools" \
  --delay "10" \
  --threads ${task.cpus} \
  --sampleName ${sampleID} \
  --ctgName chr${ctg}\
  --call_fn  ${sampleID}_chr${ctg}.vcf 
  """
}

// concatenate vcf files and sort the variants called
process concat_vcf {
tag "${sampleID}"
label 'mid_memory'
publishDir "myresults/"
conda '/exports/igmm/eddie/tomlinson-CRC-promethion/analysis/clair/clair-env'
echo true //process directive echo to console

input:
  tuple val(sampleID),  file(vcf) 

output:
  file "${sampleID}_snps_and_indels.vcf.gz"
script:
  """
   vcfcat ${vcf} |\
   bcftools sort -m 2G |\
   bgziptabix  ${sampleID}_snps_and_indels.vcf.gz 
  """
}


process vep_annotate {
conda  '/exports/igmm/eddie/tomlinson-CRC-promethion/analysis/vep/vepenv'
publishDir "myresults/"
cpus 16
  input:
      path vcf
      val vepdir
      val reference_file_path   

  output:
      tuple val("${vcf.simpleName}"), file("${vcf.simpleName}_snps_indels_vep.vcf*")

script:
"""
zcat ${vcf} | \
vep \
--assembly GRCh38 \
--cache \
--cache_version 101 \
--dir_cache ${vepdir}/resources/vep/cache \
--dir_plugins ${vepdir}/resources/vep/plugins \
--everything \
--fasta ${reference_file_path} \
--fork ${task.cpus} \
--format vcf \
--offline \
--output_file STDOUT \
--plugin LoFtool \
--species homo_sapiens \
--stats_file variants.html |  \
 bgziptabix ${vcf.simpleName}_snps_indels_vep.vcf.gz
"""
}



process filtervep {

  conda  '/gpfs/igmmfs01/eddie/tomlinson-CRC-promethion/analysis/vep/vepenv'
  publishDir "myresults/"
  
  input:
  tuple val(sampleID), file(vep) 

  output:
  path "${sampleID}.tab.txt", emit: final_ch

script:
"""
filter_vep \
-i ${vep}  \
--ontology \
--format tab \
--output ${sampleID}.tab.txt \
--filter "IMPACT is HIGH" \
"""
}
