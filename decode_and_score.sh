#!/usr/bin/env bash


[ -f ./path.sh ] && . ./path.sh

stage=0
nj=4
. utils/parse_options.sh || exit 1;

if [ $# -ne 4 ]; then
    echo "$1 set               # Name of the set e.g. althingi_dev"
    echo "$2 audio_segments    # Path to the folder containing the audio segments"
    echo "$3 res_folder        # Path to the results folder"
    echo "$4 data              # Path to kaldi data folder for the data"
    exit 1
fi

set=$1
audio_segments=$2
res_folder=$3
data=$4

reference_text=$data/text
outdir="${res_folder}/${set}"

if [ $stage -le 0 ]; then
    echo "Running ${set}"
    mkdir -p $outdir

    start=`date +%s`
    python3 src/recognize.py \
        -i $audio_segments \
        -o "${outdir}/decode" \
        -nj $nj
    end=`date +%s`
    runtime=$((end-start))
    echo "Numer of segments decoded $(wc -l $audio_segments)"
    echo "Decodetime for ${set}: $runtime sek" 
    
fi

if [ $stage -le 1 ]; then
    echo "Computing WER and SER ${outdir}/wer_${set}"
    cat ${outdir}/decode | utils/compute-wer --mode=present \
            ark:$reference_text ark,p:- >& ${outdir}/wer_${set}
fi


if [ $stage -le 2 ]; then
    echo "${outdir}/decode"
    echo $reference_text
    echo $data/utt2spk
    echo ${outdir}/per_utt


    cat ${outdir}/decode | utils/align-text --special-symbol="'***'" ark:$reference_text ark:- ark,t:- |  \
    utils/wer_per_utt_details.pl --special-symbol "'***'" | tee ${outdir}/per_utt |\
    utils/wer_per_spk_details.pl $data/utt2spk > ${outdir}/per_spk || exit 1;

    cat ${outdir}/per_utt | \
    utils/wer_ops_details.pl --special-symbol "'***'" | \
    sort -b -i -k 1,1 -k 4,4rn -k 2,2 -k 3,3 > ${outdir}/ops || exit 1;
fi