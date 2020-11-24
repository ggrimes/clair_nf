
nextflow.enable.dsl=2

include { clair_calls;  concat_vcf; vep_annotate; filtervep} from './modules/clair.nf'

params.bam ="../../data/raw/D**.{bam,bam.bai}"
params.take=1
bam_ch = Channel
            .fromFilePairs(params.bam) {file -> file.name.replaceAll(/.bam|.bai$/,'')}
            .take(params.take)

params.vepdir ="/exports/igmm/eddie/tomlinson-CRC-promethion/analysis/vep"
params.model = "/exports/igmm/eddie/tomlinson-CRC-promethion/analysis/clair/ont/model"
params.reference_file_path = "/exports/igmm/eddie/tomlinson-CRC-promethion/analysis/clair/hg38.fa"
params.out_prefix = "$baseDir/claircalls/var"
params.threshold = 0.2
params.clair="/exports/igmm/eddie/tomlinson-CRC-promethion/analysis/clair/clair-env/bin/clair.py"

chr_ch=Channel
    .of(1..21, 'X', 'Y')

workflow {


  clair_calls( bam_ch, params.reference_file_path, params.clair, chr_ch, params.model, params.threshold,  )
  concat_vcf( clair_calls.out.groupTuple())
  vep_annotate( concat_vcf.out,params.vepdir,params.reference_file_path )
  filtervep(vep_annotate.out)
}

