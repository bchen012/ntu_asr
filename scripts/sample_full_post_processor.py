#!/usr/bin/env python
'''
Sample script that shows how to postprocess full results from the kaldi-gstreamer-worker, encoded as JSON.
It adds a sentence confidence score to the 1-best hypothesis, deletes all other hypotheses and
adds a dot (.) to the end of the 1-best hypothesis. It assumes that the results contain at least two hypotheses,
The confidence scores are now normalized
'''

import sys
import json, ast
import logging
from math import exp

def disfluenciesRemover(inString):
    disfluencies = [
        'uh',
        'um',
        'oh',
        'ah',
        'er',
        'em',
        'ah',
        'lah',
        'huh',
        'hmm',
        'erm',
        'um-hum',
        '<v-noise>',
        '<noise>',
    ]
    newline = ''
    words = inString.split()
    for word in words:
        if word.strip().lower() in disfluencies:
            continue
        else:
            newline += word + ' '
    
    return newline.strip()
    
def post_process_json(trans):
    try:
        #event_intermediate = json.loads(trans)
        #event = ast.literal_eval(event_intermediate)
        event = json.loads(trans)
        #logging.info("post_process_json")
        #logging.info(type(event))
        
        if "result" in event:
            confidence = 1.0e+10;
            if len(event["result"]["hypotheses"]) > 1:
                likelihood1 = event["result"]["hypotheses"][0]["likelihood"]
                likelihood2 = event["result"]["hypotheses"][1]["likelihood"]
                confidence = likelihood1 - likelihood2
                confidence = 1 - exp(-confidence)
            
            event["result"]["hypotheses"][0]["confidence"] = confidence
            event["result"]["hypotheses"][0]["transcript"] = disfluenciesRemover(event["result"]["hypotheses"][0]["transcript"]) + "."
            #del event["result"]["hypotheses"][1:]
        
        return json.dumps(event)
        
    except:
        exc_type, exc_value, exc_traceback = sys.exc_info()
        logging.error("Failed to process JSON result: %s : %s " % (exc_type, exc_value))
        return str


if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG, format="%(levelname)8s %(asctime)s %(message)s ")

    lines = []
    while True:
        l = sys.stdin.readline()
        if not l: break # EOF
        if l.strip() == "":
            if len(lines) > 0:
                result_json = post_process_json("".join(lines))
                print (result_json)
                if sys.version_info[0] < 3:
                    print ()
                else:
                    print ("")
                sys.stdout.flush()
                lines = []
        else:
            lines.append(l)

    if len(lines) > 0:
        result_json = post_process_json("".join(lines))
        print (result_json)
        lines = []
