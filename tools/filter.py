#!/usr/bin/env python3


# Wasn't able to find a nice looking way to do this is bash 


import sys


def main():
    inp1 =sys.argv[1]
    inp2 = sys.argv[2]

    filter = set([x.rstrip() for x in open(inp1)])

    for line in open(inp2):
        word = line.split('\t')[0]
        if word in filter:
            print(line.rstrip())

if __name__ == '__main__':
    main()