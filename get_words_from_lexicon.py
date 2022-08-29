#!/usr/bin/env python3


import sys


def main():
    lexicon = {}
    for line in open(sys.argv[2]):
        w, p = line.rstrip().split("\t")
        if w in lexicon:
            lexicon[w].append(p)
        else:
            lexicon[w] = [p]

    for w in open(sys.argv[1]):
        w = w.rstrip()
        if w in lexicon:
            for p in lexicon[w]:
                print(f"{w}\t{p}")


if __name__ == "__main__":
    main()
