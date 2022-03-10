#!/usr/bin/env python3


import re
from unittest import result
import requests
import sys
import json


'''
Takes in a file with one word per line and generates the pronounciation. 


Using https://gitlab.com/tiro-is/g2p-service/

Words that fail with the Icelandic model are tested with the Ice-Eng model.

'''


def main(path2file):

    words = [x.rstrip() for x in open(path2file)]
    results = []
    re_reun=[]
    for word in words:
        response  = requests.get('https://nlp.talgreinir.is/pron/'+ word +'?max_variants_number=1')
        res=json.loads(response.text)[0]
        if res['results']:
            results.append([word, res['results'][0]['pronunciation']])
        else:
            re_reun.append(word)

    for word in re_reun:
        response  = requests.get('https://nlp.talgreinir.is/pron/'+ word +'?max_variants_number=1&?language_code=en-IS')
        res=json.loads(response.text)[0]
        if res['results']:
            results.append([word, res['results'][0]['pronunciation']])

    for line in results:
        print('\t'.join(line))


if __name__ == '__main__':
    
    path2file = sys.argv[1]
    main(path2file)