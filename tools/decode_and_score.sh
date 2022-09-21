#!/usr/bin/env bash


[ -f ./path.sh ] && . ./path.sh

stage=0
nj=4
. utils/parse_options.sh || exit 1;

if [ $# -ne 4 ]; then
    echo "$1 audio_segments    # Path to the file containing the audio segments"
    echo "$2 res_folder        # Path to the results folder"
    echo "$3 data              # Path to kaldi data folder for the data"
    echo "$4 server            # ASR server"
    exit 1
fi


audio_segments=$1
outdir=$2
data=$3
server=$4

reference_text=$data/text

if [ $stage -le 0 ]; then
    mkdir -p $outdir
    python3 tools/recognize.py \
        -i $audio_segments \
        -o "${outdir}/decode" \
        -nj $nj \
        -c $server
fi

if [ $stage -le 1 ]; then
    echo "Computing WER and SER ${outdir}/wer_${set}"
    cat ${outdir}/decode | compute-wer --mode=present \
            ark:$reference_text ark,p:- >& ${outdir}/wer
fi


if [ $stage -le 2 ]; then
    echo "${outdir}/decode"
    echo $reference_text
    echo $data/utt2spk
    echo ${outdir}/per_utt


    cat ${outdir}/decode | align-text --special-symbol="'***'" ark:$reference_text ark:- ark,t:- |  \
    utils/scoring/wer_per_utt_details.pl --special-symbol "'***'" | tee ${outdir}/per_utt |\
    utils/scoring/wer_per_spk_details.pl $data/utt2spk > ${outdir}/per_spk || exit 1;

    cat ${outdir}/per_utt | \
    utils/scoring/wer_ops_details.pl --special-symbol "'***'" | \
    sort -b -i -k 1,1 -k 4,4rn -k 2,2 -k 3,3 > ${outdir}/ops || exit 1;
fi