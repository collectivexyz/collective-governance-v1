#!/usr/bin/env python3
"""
Convert the 'output' from solc into a readable json format for conversion by the
SPHINX template.
"""

import sys
import json

def contract_filter(contract: str) -> bool:
  """ return true if this is a contract of interest """
  return contract.startswith('contracts')

def usage(name: str):
  """ print usage """
  print('%s: docgen docgen.json' % name)

def contract_name(doc:str) -> str:
  """ return the contract name """
  name = doc.replace('=======', '')
  return name.rstrip().lstrip()

def short_name(contract:str) -> str:
  """ return the name of the contract from contract string """
  if ':' in contract:
    return contract.rpartition(':')[-1]
  return contract

def merge(method_a: dict, method_b: dict) -> dict:
  """ merge to method dicts of dicts """
  keySet = method_a.keys() | method_b.keys()
  method_dict = {}
  for k in keySet:
    method_data = {}
    if k in method_a and k in method_b:
      method_data = method_a[k] | method_b[k]
    elif k in method_b:
      method_data = method_b[k]
    elif k in method_a:
      method_data = method_a[k]
    method_dict[k] = method_data
  return method_dict

def parse_docgen(path: str) -> dict: 
  """ parse the solc docgen """
  docgen_data = {}
  with open(path, 'r') as docgen_stream:
    doclines = docgen_stream.readlines()
    doclines = [ line.rstrip().lstrip() for line in doclines ]
    while len(doclines) > 5:
      while len(doclines[0]) == 0 and len(doclines) > 0:
        doclines = doclines[1:]
      if len(doclines) >= 5:
        (contract, devdesc, devdoc, userdesc, userdoc) = doclines[:5]
        doclines = doclines[5:]
        contract = contract_name(contract)
        if contract_filter(contract):
          contract_meta = {}
          devdoc_parsed = {}
          userdoc_parsed = {}
          if devdesc == 'Developer Documentation':
            devdoc_parsed = json.loads(devdoc)
          else:
            print('Documentation not in expected format: %s' % devdesc)
            sys.exit(1)
          if userdesc == 'User Documentation': 
            userdoc_parsed = json.loads(userdoc)
          else:
            print('Documentation not in expected format: %s' % userdesc)
            sys.exit(1)
          contract_meta = devdoc_parsed | userdoc_parsed
          if 'methods' in contract_meta:
            del contract_meta['methods']
          if 'kind' in contract_meta:
            del contract_meta['kind']
          contract_meta['name'] = short_name(contract)
          contract_meta['devdoc'] = devdoc_parsed
          contract_meta['userdoc'] = userdoc_parsed
          contract_methods = merge(userdoc_parsed['methods'], devdoc_parsed['methods'])
          contract_meta['mergedoc'] = userdoc_parsed | devdoc_parsed | { 'kind' : 'merged'}
          contract_meta['mergedoc']['methods'] = contract_methods
          docgen_data[contract] = contract_meta
    if any(len(line) > 0 for line in doclines):
      print('WARNING: Not all doc lines parsed')
  return docgen_data

if __name__ == '__main__':
  if len(sys.argv) > 1:
    docgen_file = sys.argv[1]
    output_file = sys.argv[2]
    docgen = parse_docgen(docgen_file)
    with open(output_file, 'w') as output_stream:
      output_stream.write(json.dumps(docgen, indent=2, sort_keys = True))
  else:
    usage(sys.argv[0])