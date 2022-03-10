#!/usr/bin/env bash


# The goal is to create an HCLG-graph using an exsting acoustic model.
# To do that we need to update the Language model and possibly the lexicon


# Set up the environment variables (again)
. ./cmd.sh
. ./path.sh



model_root_dir=../models
model_dir=$model_root_dir/20211012 # This is a TSC model dir form where we get the acoustic model 
pron_dict=$model_root_dir/prondict.20220208.tsv
model_key='trivia'

lm_order=3

# Variables that don't have to be changed
dictdir=data/dict
langdir=data/lang
lexicon=data/trivia_lexicon



export_dir=$model_root_dir/${model_key}_${lm_order}g


if [ ! -d data ]; then mkdir data; fi;


# Trivia
# Combining text data 
# Creating a test and training set
if [ $stage -le 0 ]; then
    gettu_betur=../lm-trivia/normalized/gettu_betur_nom_regina_no_syms
    # TODO add the trivia question 
    trivia_questions=

    cat $gettu_betur > data/all_trivia_questions
    cat $trivia_questions >> data/all_trivia_questions
    sort -u data/all_trivia_questions > tmp && mv tmp data/all_trivia_questions

    # TODO Change -n to some thing that makes sense when you have all the data
    shuf -n 500  data/all_trivia_questions | sort > data/trivia_test
    comm -3 data/trivia_test data/all_trivia_questions | sed 's/\t//g' > data/trivia_train 
fi


# Updating the lexicon
if [ $stage -le 1 ]; then
    echo "Identify OOV words"
    cut -d' ' -f2- data/trivia_train | tr ' ' '\n' | sort -u | grep -Ev '^$' \
    > data/trivia_wordlist
    
    comm -23 data/trivia_wordlist <(cut -f1 $pron_dict | sort -u) \
    > data/trivia_oov_wordlist

    ./g2p.py data/trivia_wordlist | sort -u > data/trivia_oov_with_pron

fi

# Creating the dict and lang
if [ $stage -le 2 ]; then

    mkdir -p $langdir && mkdir -p $dictdir 
    
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
        $dictdir "<unk>" data/tmp $langdir
fi  

# Create the language model
if [ $stage -le 3 ]; then
    echo "Preparing a pruned ${lm_order}-gram language model"
    /opt/kenlm/build/bin/lmplz \
        --skip_symbols \
        -o ${lm_order} \
        -S 70% \
        --text data/trivia_train \
        --limit_vocab_file <(cut -d' ' -f1 data/lang/words.txt | egrep -v "<eps>|<unk>") \
        | gzip -c > data/lang/kenlm_${lm_order}g.arpa.gz 

    utils/format_lm.sh \
      data/lang \
      data/lang/kenlm_${lm_order}g.arpa.gz \
      $lexicon \
      data/lang_${lm_order}g

    echo "Build constant ARPA language model"
    utils/build_const_arpa_lm.sh \
      data/lang/kenlm_${lm_order}g.arpa.gz \
      data/lang \
      data/lang_${lm_order}g
fi

# Finally assemble the HCLG graph
if [ $stage -le 4 ]; then
    if [ ! -d exp ]; then mkdir exp; fi;
    utils/mkgraph.sh \
        --self-loop-scale 1.0 \
        data/lang_${lm_order}g \
        $model_dir \
        exp/${model_key}_${lm_order}g_graph
fi

# Create a bundle for TSC
if [ $stage -le 5 ]; then
    if [ ! -d $export_dir ]; then mkdir $export_dir; fi;
    cp -r $model_dir/{conf,ivector_extractor,final.mdl,frame_subsampling_factor,main.conf,phones.txt,tree,norm} $export_dir/. 
    mkdir -p $export_dir/graph
    
    cp -r exp/${model_key}_${lm_order}g_graph $export_dir/. && mv $export_dir/${model_key}_${lm_order}g_graph $export_dir/grap
fi