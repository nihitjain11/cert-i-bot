#!/bin/python3

# Required ENV Variables
# None, instead creates TIMESTAMP

import subprocess
import sys

def bash(COMMAND):
    # return subprocess.run(COMMAND.split(), stdout=subprocess.PIPE,stderr=subprocess.PIPE, text=True)
    return subprocess.getstatusoutput(COMMAND)

# print('opening file')
with open(sys.argv[1],'r') as file:
    # print('inside file now')
    for line in file:
        if line[0] in ["#","\n"]:
            # print('skipping comment and emptylines')
            continue
        try:
            print('trying command: '+str(line))
            result = bash(line) # (status_code,output/error_msg)
            # print("exitcode: ",result[0])
            if result[0] != 0:
                # print('raising error')
                raise Exception(result[1])
            if line[0] == "echo":
                print (line)

        except Exception as e:
            # print('error caught')
            print(e)