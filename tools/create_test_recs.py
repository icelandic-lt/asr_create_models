#!/usr/bin/env python3


import requests, os, glob, random, shutil, sox
from tqdm import tqdm


DATA_DIR = "/home/dem/Projects/h10/create_models/data"


def convert_to_WAVE(audio_file):
    """
    Given an .mp3 file, convert it to wave and replace in the same loaction.
    Using sox as it is mostlikey already installed on the machine.
    """
    audio_out = audio_file.replace(".mp3", ".wav")
    tfm = sox.Transformer()
    tfm.convert(samplerate=16000, n_channels=1)
    status = tfm.build(input_filepath=audio_file, output_filepath=audio_out)
    if status == True:
        os.remove(audio_file)
    return status


def get_all_voice_ids():
    to_return = []
    for line in requests.get(
        "https://tts.tiro.is/v0/voices",
        json={
            "ExtraMetadata": {"VoiceVersion": "string"},
            "Gender": "Male",
            "LanguageCode": "is-IS",
            "LanguageName": "Íslenska",
            "SupportedEngines": ["standard"],
            "VoiceId": "Alfur",
        },
    ).json():
        to_return.append(line["VoiceId"])
    return to_return


def create_sample(dir):
    all_voice_ids = get_all_voice_ids()

    os.makedirs(os.path.join(dir, "test_set"), exist_ok=True)
    audio_dir = os.path.join(dir, "test_set", "audio")
    if os.path.exists(audio_dir):
        shutil.rmtree(audio_dir)
    os.makedirs(audio_dir, exist_ok=True)
    with open(os.path.join(dir, "test_set", "text"), "w") as text_file, open(
        os.path.join(dir, "test_set", "audio2id"), "w"
    ) as audio2id, open(os.path.join(dir, "test_set", "utt2spk"), "w") as utt2spk:
        test_set = [x for x in open(os.path.join(dir, "test"))]
        for idx, text in tqdm(enumerate(test_set), total=len(test_set)):
            idx = idx + 1
            voice = random.choice(all_voice_ids)
            audio_file_name = os.path.join(audio_dir, f"{idx}_{voice}")
            res = requests.post(
                "https://tts.tiro.is/v0/speech",
                json={
                    "OutputFormat": "mp3",
                    "SampleRate": "16000",
                    "Text": text,
                    "TextType": "text",
                    "VoiceId": voice,
                },
            )
            if res.status_code != 200:
                print(voice, res.text.rstrip(), text)
            else:
                with open(audio_file_name + ".mp3", "wb") as fh:
                    fh.write(res.content)
                convert_to_WAVE(audio_file_name + ".mp3")

                text_file.write(f"{idx}_{voice} {text}")
                audio2id.write(f"{audio_file_name}.wav {idx}_{voice}\n")
                utt2spk.write(f"{idx}_{voice} {voice}\n")
    print("Done creating samples")


if __name__ == "__main__":
    import sys

    dir = sys.argv[1]
    create_sample(dir)
