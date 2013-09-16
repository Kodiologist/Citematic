#!/usr/bin/env python3

from sys import stderr
from os import environ
import yaml, cgi
from citematic_coins import coins

bib_path = environ['DAYLIGHT_BIB_PATH']

with open(bib_path) as o:
    database = yaml.load(o)

print('''<!DOCTYPE html>

<html lang="en-US">
<head>
   <meta charset="UTF-8">
   <title>Bibliography in COinS</title>   
</head>

<body>''')
for n, x in enumerate(database):
    print('{} of {} ({})…'.format(n + 1, len(database), x['KEY']), file = stderr)
    print('<p>{}: {}\n'.format(cgi.escape(x['KEY']), coins(x['csl'])))
print('</body></html>')
