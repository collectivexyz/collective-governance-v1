#!/usr/bin/env python3
""" parse foundry deployment into library path statement """
import sys
import json
import os

def usage(name: str): 
  """ print the usage """
  print('%s deployment.json ...' % name)

def parse_deployment(path: str, file: str) -> str:
  """ parse a deployment file into a library path """
  basename = os.path.basename(file)
  (basefile, _) = os.path.splitext(basename)
  (basecontract, _) = os.path.splitext(basefile)
  with open(file, 'r') as json_stream:
    jsondata = json_stream.read().rstrip().lstrip()
    js = json.loads(jsondata)
    if 'deployedTo' in js:
      deployed_to = js['deployedTo']
      return path + basefile + ':' + basecontract + ':' + deployed_to
    else:
      raise Exception('Invalid deployment json')
  
if __name__ == '__main__':
  if len(sys.argv) > 1:
    library_path = []
    contract_path = 'contracts/'
    parse_contract_path = False
    for file in sys.argv[1:]:
      if file == '-c':
        parse_contract_path = True
      elif parse_contract_path:
        contract_path = file
      else:
        library_path.append(parse_deployment(contract_path, file))
    print(','.join(library_path))
  else:
    usage(sys.argv[0])