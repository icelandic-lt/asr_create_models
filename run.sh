#!/usr/bin/env bash


# The goal is to create an HCLG-graph using an exsting acoustic model.
# To do that we need to update the Language model and possibly the lexicon


# Set up the environment variables
. ./cmd.sh
. ./path.sh
. .venv/bin/activate

run_test=true

stage=0
model_name=$1
# d=`date +%F`
d="sept"
# model_name="unit-conversion-$d"
# model_name="trivia-$d"
# model_name="addresses-$d"
# model_name="kennitolur-$d"
# model_name="names-$d"
# model_name="phone_numbers-$d"
data=data/$model_name
exp=$data/exp

model_root_dir=models
model_dir=$model_root_dir/20211012 # This is a TSC model dir from where we get the acoustic model 
pron_dict=data/prondict.tsv

lm_order=4

# Variables that don't have to be changed
dictdir=$data/dict
langdir=$data/lang
lexicon=$data/lexicon


export_dir=$model_root_dir/${model_name}_${lm_order}g


mkdir -p $data $data/lexiconData $dictdir $langdir $export_dir $exp

echo The model name is $model_name

# Trivia
# Combining text data 
# Creating a test and training set
if [[ $model_name == "trivia-"* ]]; then
    echo "Prepping $model_name"
    gettu_betur=../lm-trivia/data_GB/final.txt
    spurningar_is=../is-trivia-questions/data_spurning-is/final.txt
    is_trivia=../is-trivia-questions/data_is-triva/final.txt

    cat $gettu_betur $spurningar_is $is_trivia | sed 's/\.//g' >> $data/all
    sort -u $data/all > tmp && mv tmp $data/all

    #TODO Change -n to some thing that makes sense when you have all the $data
    # shuf -n 500  $data/all | sort > $data/test
    # comm -3 $data/test $data/all | sed 's/\t//g' > $data/train 
    mv $data/all $data/train
    echo "Done prepping $model_name"

fi

###### Data prep for unit conversion 
# Combining text data 
# Creating a test and training set
if [[ stage -le 0 ]] && [[ $model_name == "unit-conversion"* ]]; then
    echo "Prepping $model_name"
    unitConversionData=../unit-conversion/output/sentences.tsv
    cut -f3- $unitConversionData | sed 's/\?//' | sort -u > $data/train
        shuf $data/train | head -n 100 > $data/test
    echo "Done prepping $model_name" 
fi

###### Data prep for addresses 
if [[ stage -le 0 ]] && [[ $model_name == "addresses-"* ]];  then
    echo "Prepping $model_name"
    addresses=../lm-is-forms/output/addresses.txt
    cat $addresses | sort -u > $data/train
    sort -u $data/all >  $data/train
    echo "Done prepping $model_name"                     
fi
###### Data prep for kennitolur 
if [[ stage -le 0 ]] && [[ $model_name == "kennitolur"* ]]; then
    echo "Prepping $model_name"
    kennitolur=../lm-is-forms/output/kennitalas_normalized.txt
    cat $kennitolur  | sort -u > $data/train
    shuf $data/train | head -n 100 > $data/test

    echo "Done prepping $model_name"
fi

###### Data prep for names 
if [[ stage -le 0 ]] && [[ $model_name == "names-"* ]]; then
    echo "Prepping $model_name"
    names=../lm-is-forms/output/names.txt
    cat $names | sort -u > $data/train
    shuf $data/train | head -n 100 > $data/test    
    echo "Done prepping $model_name"
fi

###### Data prep for phone_numbers 
if  [[ stage -le 0 ]] && [[ $model_name == "phone_numbers-"* ]]; then
    echo "Prepping $model_name"
    phoneNumbers=../lm-is-forms/output/phone_numbers_normalized.txt
    cat $phoneNumbers | sort -u > $data/train
    shuf $data/train | head -n 100 > $data/test
    echo "Done prepping $model_name"
fi



# Updating the lexicon
if [ $stage -le 1 ]; then
    echo "Identify OOV words"
    cat $data/train | tr ' ' '\n' | sort -u | grep -Ev '^$' \
    > $data/lexiconData/all_words
    
    comm -23 $data/lexiconData/all_words <(cut -f1 $pron_dict | sort -u) \
    > $data/lexiconData/oov_words

    ./tools/run_g2p.py $data/lexiconData/oov_words | sort -u > $data/lexiconData/oov_words_with_pron
    
    ./tools/get_words_from_lexicon.py $data/lexiconData/all_words $pron_dict > $lexicon
    cat $data/lexiconData/oov_words_with_pron >> $lexicon 
    sort -u $lexicon | sed '/^$/d' > $data/temp && mv $data/temp $lexicon

    cat $data/lexiconData/oov_words_with_pron >> $pron_dict 
    sort -u $pron_dict | sed '/^$/d' > $data/temp && mv $data/temp $pron_dict

fi

# Creating the dict and lang
if [ $stage -le 2 ]; then
    echo "Converting to lexicon.txt"
    rm $dictdir/*
    cat $lexicon <(echo "<unk> oov") > $dictdir/lexicon.txt

    cut -f2- $lexicon  | tr ' ' '\n' | LC_ALL=C sort -u > $dictdir/nonsilence_phones.txt
    
    join -t '' \
        <(grep : $dictdir/nonsilence_phones.txt) \
        <(grep -v : $dictdir/nonsilence_phones.txt | awk '{print $1 ":"}' | sort) \
        | awk '{s=$1; sub(/:/, ""); print $1 " " s }' \
        > $dictdir/extra_questions.txt

    echo sil > $dictdir/silence_phones.txt
    echo oov >> $dictdir/silence_phones.txt
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
    # utils/build_const_arpa_lm.sh \
    #   $langdir/kenlm_${lm_order}g.arpa.gz \
    #   $langdir \
    #   $data/lang_${lm_order}g
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
    
    cp -r $exp/${model_name}_${lm_order}g_graph/* $export_dir/graph 
    cp "${langdir}_${lm_order}g/G.fst" $export_dir/.
    tar -czvf  "${export_dir}.tar.gz" $export_dir
    sed -i 's/--formatter.*//' $export_dir/main.conf
    sed -i 's/--const.*//' $export_dir/main.conf
    sed -i '/^$/d' $export_dir/main.conf
fi


if [ $stage -le 6 ] && [ $run_test = true ]; then 
    # We test the model on indomain data generated with TTS and see if it
    # isnt actually doing what it is supposed to be doing. We compare the 
    # model to a larger speech recognizer. The trained model should be 
    # alot more acurate.
    # Create the test data
    # ./tools/create_test_recs.py $data
    
    # Pop open a new termianl and start the server 
    gnome-terminal -- bash -c "./tools/start_TSC_server.sh $PWD/$export_dir 50051; exec bash" 

    # Wait for the server to startup
    sleep 5
    
    # Decode using the model we trained 
    ./tools/decode_and_score.sh --stage 0 \
        $data/test_set/audio2id \
        $data/test_set/local_results \
        $data/test_set \
        "0.0.0.0:50051"

    gnome-terminal -- bash -c "./tools/start_TSC_server.sh $PWD/$model_dir 50052; exec bash" 

    ./tools/decode_and_score.sh --stage 0 \
        $data/test_set/audio2id \
        $data/test_set/tiro_results \
        $data/test_set \
        "0.0.0.0:50052"


    # Compare results
    local=$(grep "WER" <  $data/test_set/local_results/wer)  
    tiro=$(grep "WER" <  $data/test_set/tiro_results/wer)  

    echo $data/test_set/local_results/wer
    echo $data/test_set/tiro_results/wer
    message="${model_name}\nLocal: ${local}\nTiro: ${tiro}\n"
    echo -e $message
    echo -e $message >> results
fi


# Scraps

# for model_name in *_4g; do 
#     echo $model_name; 
#     rm -r $model_name/graph/${model_name}_graph $model_name/${model_name}_graph
#     # m_name=$(echo $model_name | sed 's/_4g//')
#     # cp -r /home/dem/Projects/h10/create_models/data/${m_name}/exp/${model_name}_graph/* $model_name/graph  ;
# done

# for model_name in *_4g; do 

# sed -i 's/--const-arpa-rxfilename=G.carpa/; --const-arpa-rxfilename=G.carpa/' $model_name/main.conf
# sed -i 's/--formatter/; --formatter/' $model_name/main.conf

# done

# for x in  "trivia-sept" "addresses-sept" "kennitolur-sept" "names-sept" "phone_numbers-sept" "unit-conversion-sept"; do 
#     model=models/${x}_4g
#     cp data/$x/test $model/.
# done