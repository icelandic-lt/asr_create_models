#!/usr/bin/env python3


import requests
import sys
import json


"""
Takes in a file with one word per line and generates the pronounciation. 


Using https://gitlab.com/tiro-is/g2p-service/

Words that fail with the Icelandic model are tested with the Ice-Eng model.

"""


def parallel_process(function, iterable, n_jobs=10):
    from multiprocessing.pool import Pool

    with Pool(processes=n_jobs) as pool:
        res = pool.map(function, iterable)

    return res


def call_g2p(word):

    return [
        word,
        requests.get(
            "https://nlp.talgreinir.is/pron/" + word + "?max_variants_number=1"
        ),
    ]


def main(path2file):

    words = [x.rstrip() for x in open(path2file)]
    results = []
    re_reun = []

    response = parallel_process(call_g2p, words)
    for word, res in response:
        r = json.loads(res.text)[0]
        if r["results"]:
            results.append([word, r["results"][0]["pronunciation"]])
        else:
            re_reun.append(word)

    for word in re_reun:
        response = requests.get(
            "https://nlp.talgreinir.is/pron/"
            + word
            + "?max_variants_number=1&?language_code=en-IS"
        )
        res = json.loads(response.text)[0]
        if res["results"]:
            results.append([word, res["results"][0]["pronunciation"]])

    for line in results:
        print("\t".join(line))


if __name__ == "__main__":

    path2file = sys.argv[1]
    main(path2file)
