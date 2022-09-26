# About
This repo conatins a recepie for creating Kaldi language models from a few data sources. The goal is to develop Kaldi models for voice control and question answering systems for Icelandic. Voice control refers to a one-way communication between human and system with the aim of soliciting an action. From an ASR perspective, this requires a special attention to the type of language modelling as the utterance might not adhere to normal rules of continuous language. ASR for question answering has a similar design criteria with the specialized utterance structure being in the form of questions. 

The tasks that we created/gathered data for are unit conversion, Trivia questions, Addresses, Icelandic social security numbers, names and Icelandic phone numbers. 

# Setup 
Point to your Kaldi installation by setting the `KALDI_ROOT` variable in `path.sh`. Run `setup.sh` and the folder `utils` and `steps` should appear in the directory. 

To test and decode the models you will need a TSC docker image. The image is stored using git LFS and should be downloaded to the folder `tsc-image`, if not the image can compiled using the repo [Tiro Speech Core](https://github.com/tiro-is/tiro-speech-core)

To install the package for the ASR client:
```
python3 -m venv .venv
. .venv/bin/activate
python3 -m pip install -r requirements.txt
```

Te fetch the data, install Git LFS and run the following command:
```
git lfs fetch --all
```


# Usage 
The script `run.sh` can be used as template to add further data. The script creates a language model and HCLG graph, given that the user provides an Kaldi acoustic model. 

This script has saven stages: 
1. stage: Data specific preperation.
2. stage: Identifies out-of-vocabulary, given a pre-existing pronounciation dictionary and creating the pronounciation of the OOV word using a [g2p service](https://gitlab.com/tiro-is/g2p-service).
3. stage: Prepares the lang directory. 
4. stage: Creates the models using lmplz form KenLm.
5. stage: Assembling the HCLG graph.
6. stage: Creates a bundle that can be used with TSC server and a tar.gz file with the model.
7. stage: Creates test data by generating audio files with [TTS voice](tts.tiro.is) and decodes by using the TSC and client `tools/recognize.py`. The clients requirements are in `requirements.txt`. Both the task specific model and the provided models are decoded and compared using WER. The outputs are piped to the file `results`.

# Data

## Unit conversion
The thought here was to create a model for common queries with multiple unit conversion tasks. We generated training data based on template sentences where the unit (distance, currency, volume, etc.) and a number was added in the right inflection. Some examples are:
```
Isl: Hversu margar íslenskar krónur fæ ég fyrir einn dollara?
Eng: How many Icelandic kronur do I get for one dollar?
	
Isl: Hvað er einn desilítri margir lítrar?
Eng: What is one deciliter  many liters? 

Isl: Breyttu fimm mílum í kílómetra
	Eng: Convert five miles into kilometers
```
The sentence generation script is on [Github](https://github.com/tiro-is/unit-conversion). For this script we needed a list of numbers in the expend form along with the inflection. Because of the high number of inflections for each number this is a non trivial task, for that reason we wrote a tool called Númi which writes the numbers out given an integer and inflection e.g.

```
Input: 92, "ft_hk_ef"
Output: níutíu og tveggja

Input: 121, "ft_kk_þgf",
Output: "eitt hundrað tuttugu og einum", "hundrað tuttugu og einum"
```
The code for this tool is on [Github](https://pypi.org/project/numi/) and is available as a pip package `pip install numi`.

## Trivia questions
We gathered data from three sources; from question authors on a local game show Gettu betur, from an open source collection of [Trivia-question](https://github.com/sveinn-steinarsson/is-trivia-questions) and from a question answering crowdsourcing platform called [Spurningar.is](https://spurningar.is). We were not able to get permission to make the questions from the Gettu betur authors publicly available so they were solely used for the model training.

The data is as follows. 

| Source              | Number of sentences |
| ------------------- | ------------------- |
| is-trivia-questions | 11309               |
| Gettu Betur         | 4184                |
| Spurning.is         | 18304               |

 
The data was normalized with regards to numbers and abbreviations using Regian along with some manual parsing. The scripts and data for the open source part is available on [Github](https://github.com/cadia-lvl/is-trivia-questions ).

## Form fields
Next four tasks focus on common attributes needed for various purposes that need special attention regarding vocabulary and language model structure. We chose attributes that are common to many tasks keeping in mind to get a wide range of attribute types. This way it is possible to reconfigure or adapt the models to a variety of new tasks. The four attributes chosen are home addresses, full names, personal id numbers (kennitala) and phone numbers.  The code for these task is available on [Github](https://github.com/cadia-lvl/lm-is-forms).

### Home addresses
The national registry has a list of all (legal) home addresses in Iceland. This data is available on their website, skra.is. The addresses were normalized with handwritten rules for each special address type. 

### Names
To generate names we used the BIN database to collect first names, middle names and surnames (both patronymic and matronymic). No normalization step was needed for this attribute. 

### Personal identification numbers (kennitala)
Every Icelandic person and company has a personal identification number used for identification in various tasks. The number follows a specific verifiable pattern and can be read out in various different ways. For example the personal identification number “241270 2329” can be read like any of the following representations:

```
tveir fjórir einn tveir sjö núll tveir þrír tveir níu
tuttugu og fjórir tólf sjötíu tuttugu og þrír tuttugu og níu
tuttugu og fjórir tólf sjötíu tuttugu og þrír tveir níu
tuttugu og fjórir tólf sjötíu tveir þrír tuttugu og níu
tuttugu og fjórir tólf sjötíu tveir þrír tveir níu
tuttugu og fjórir tólf sjö núll tveir þrír tveir níu
tuttugu og fjórir tólf sjö núll tveir þrír tuttugu og níu
tuttugu og fjórir tólf sjö núll tuttugu og þrír tveir níu
tuttugu og fjórir tólf sjö núll tuttugu og þrír tuttugu og níu
tveir fjórir tólf sjö núll tuttugu og þrír tuttugu og níu
tuttugu og fjórir einn tveir sjötíu tuttugu og þrír tuttugu og níu
```

We generated a long list of possible identification numbers and normalized each one in up to eleven different forms to allow for different readings of each number.

### Phone numbers
The phone numbers were generated and normalized in a similar way to the personal identification numbers. We generated a list of possible phone numbers and spelled each one out in nine different ways to allow for different readings of the numbers.


# Results 




# Acknowledgements
This project was funded by the Language Technology Programme for Icelandic 2019-2023. The programme, which is managed and coordinated by Almannarómur, is funded by the Icelandic Ministry of Education, Science and Culture.
