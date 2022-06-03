#!/usr/bin/env bash


# The goal is to create an HCLG-graph using an exsting acoustic model.
# To do that we need to update the Language model and possibly the lexicon


# Set up the environment variables (again)
. ./cmd.sh
. ./path.sh



d=`date +%F`
model_name="trivia-$d"
model_name='trivia-2022-05-31'
data=$model_name
exp=$data/exp

model_root_dir=models
model_dir=$model_root_dir/20211012 # This is a TSC model dir from where we get the acoustic model 
pron_dict=$model_root_dir/prondict.20220208.tsv

lm_order=3

# Variables that don't have to be changed
dictdir=$data/dict
langdir=$data/lang
lexicon=$data/lexicon


export_dir=$model_root_dir/${model_name}_${lm_order}g


mkdir -p $data $data/lexiconData $dictdir $langdir $export_dir $exp
# Trivia
# Combining text data 
# Creating a test and training set
if [ $stage -le -10 ]; then
    gettu_betur=../lm-trivia/data_GB/final.txt
    spurningar_is=../is-trivia-questions/data_spurning-is/final.txt
    is_trivia=../is-trivia-questions/data_is-triva/final.txt

    cat $gettu_betur $spurningar_is $is_trivia >> $data/all
    sort -u $data/all > tmp && mv tmp $data/all

    # TODO Change -n to some thing that makes sense when you have all the $data
#     shuf -n 500  $data/all | sort > $data/test
#     comm -3 $data/test $data/all | sed 's/\t//g' > $data/train 
fi

###### Data prep for unit conversion 
# Combining text data 
# Creating a test and training set
if [ $stage -le -10 ]; then
    unitConversionData=../unit-conversion/out.tsv
    cut -f3- $unitConversionData | to_lower.py > $data/all
    sort -u $data/all > tmp && mv tmp $data/all

    # TODO Change -n to some thing that makes sense when you have all the $data
    shuf -n 500  $data/all | sort > $data/test
    comm -3 $data/test $data/all | sed 's/\t//g' > $data/train 
fi


# Updating the lexicon
if [ $stage -le 1 ]; then
    echo "Identify OOV words"
    cut -d' ' -f2- $data/train | tr ' ' '\n' | sort -u | grep -Ev '^$' \
    > $data/lexiconData/all_words
    
    comm -23 $data/lexiconData/all_words <(cut -f1 $pron_dict | sort -u) \
    > $data/lexiconData/oov_words

    ./g2p.py $data/lexiconData/all_words | sort -u > $data/lexiconData/oov_words_with_pron

    mv $data/lexiconData/oov_words_with_pron $lexicon
fi

# Creating the dict and lang
if [ $stage -le 2 ]; then

    echo "Converting to lexicon.txt"
    cat $lexicon <(echo "<unk> oov") > $dictdir/lexicon.txt

    cut -f2- $lexicon  | tr ' ' '\n' | LC_ALL=C sort -u > $dictdir/nonsilence_phones.txt
    
    join -t '' \
        <(grep : $dictdir/nonsilence_phones.txt) \
        <(grep -v : $dictdir/nonsilence_phones.txt | awk '{print $1 ":"}' | sort) \
        | awk '{s=$1; sub(/:/, ""); print $1 " " s }' \
        > $dictdir/extra_questions.txt

    for w in sil oov; do echo $w; done > $dictdir/silence_phones.txt
    echo "sil" > $dictdir/optional_silence.txt

    utils/prepare_lang.sh \
        --phone-symbol-table $model_dir/phones.txt \
        $dictdir "<unk>" $data/tmp $langdir
fi  

# Create the language model
if [ $stage -le 3 ]; then
    echo "Preparing a pruned ${lm_order}-gram language model"
    lmplz \
        --skip_symbols \
        -o ${lm_order} \
        -S 70% \
        --text $data/train \
        --discount_fallback \
        --limit_vocab_file <(cut -d' ' -f1 $langdir/words.txt | egrep -v "<eps>|<unk>") \
        | gzip -c > $langdir/kenlm_${lm_order}g.arpa.gz 

    utils/format_lm.sh \
      $langdir \
      $langdir/kenlm_${lm_order}g.arpa.gz \
      $lexicon \
      $data/lang_${lm_order}g

    echo "Build constant ARPA language model"
    utils/build_const_arpa_lm.sh \
      $langdir/kenlm_${lm_order}g.arpa.gz \
      $langdir \
      $data/lang_${lm_order}g
fi

# Finally assemble the HCLG graph
if [ $stage -le 4 ]; then
    utils/mkgraph.sh \
        --self-loop-scale 1.0 \
        $data/lang_${lm_order}g \
        $model_dir \
        $exp/${model_name}_${lm_order}g_graph
fi

# Create a bundle for TSC and upload tar ball to git lfs
if [ $stage -le 5 ]; then
    cp -r $model_dir/{conf,ivector_extractor,final.mdl,frame_subsampling_factor,main.conf,phones.txt,tree} $export_dir/. 
    mkdir -p $export_dir/graph
    
    cp -r $exp/${model_name}_${lm_order}g_graph $export_dir/. && mv $export_dir/${model_name}_${lm_order}g_graph $export_dir/graph
    tar -czvf  "${export_dir}.tar.gz" $export_dir
fi


