from sys import stdin, stdout, argv
from re import sub, DOTALL
from io import StringIO
from copy import deepcopy
from random import random
import json

from citeproc import CitationStylesStyle, CitationStylesBibliography
from citeproc import NAMES, DATES, NUMBERS
from citeproc.source import Reference, Name, Date, DateRange
from citeproc.source import Citation, CitationItem, Locator

def delf(x, i):
    if i in x: del x[i]

def name(given, family, suffix = None):
    n = dict(given = given, family = family)
    if suffix is not None: n['suffix'] = suffix
    return n

class APABibber(object):

    def __init__(self, std_apa_style_path):
        with open(std_apa_style_path, encoding = 'UTF-8') as f:
             self.std_apa_style = f.read()
        self.style = sub(' encoding="UTF-8"', '', self.std_apa_style)
          # lxml doesn't like the encoding declaration.
        self.style = sub(r'(<macro name="secondary-contributors">\s+<choose>\s+<if type=")',
            r'\1book ', self.style, count = 1)
          # Prevent an edited book from having its editors
          # mentioned twice.
        self.style = sub(
             '(<bibliography.+?) et-al-min="8" et-al-use-first="7"',
             r'\1', self.style)
          # We'll use our own hacky way to abbreviate the author
          # list, in order to get the ellipsis-followed-by-final-
          # author style required by APA.

    def bib1(self, d, trim = True, **rest):
        return self.bib([d], trim = trim, **rest)

    def bib(self, ds,
            trim = False,
            always_include_issue = False,
            include_isbn = False,
            abbreviate_given_names = True):

        ds = deepcopy(ds)
        for d in ds:
            d['id'] = str(random())
            for k in list(d.keys()):
                if d[k] is None: del d[k]
            if d['type'] == 'article-journal' and not always_include_issue:
                delf(d, 'issue')
            if d['type'] == 'report' and 'publisher' in d and 'URL' in d:
                d['URL'] = '{} website: {}'.format(
                    d.pop('publisher'), d['URL'])
            if d.get('author') and len(d['author']) > 7:
                d['author'] = (
                    d['author'][0:6] +
                    [{'given': '', 'family': '⣥<ellipsis>⣥'}] +
                    d['author'][-1:])

        sty = self.style
        if not abbreviate_given_names:
            sty = sub(r'\s+initialize-with="[^"]+"', '', sty)
        if include_isbn:
            sty = sub('(<text macro="access")',
                r'<text variable="ISBN" prefix=" ISBN " suffix = "."/> \1',
                sty, count = 1)
        
        bibliography = CitationStylesBibliography(
            CitationStylesStyle(StringIO(sty)),
            {ref.key: ref for ref in self.parse_references(ds)})
        bibliography.register(Citation(
            [ CitationItem(d['id']) for d in ds ]))
        s = bibliography.bibliography()
        if trim:
            s = sub(r'</?div[^>]*>', '', s)
            s = sub(' *\n *', '\n', s)
            s = s.strip()
            s = s.replace('\n', '\n\n')
              # To provide a bit more visual separation.
            
        s = s.replace('  ', ' ')
        s = sub(r'([.!?…])\.', r'\1', s)
        s = s.replace('..', '...')
          # These instances of ".." are assumed to be fake
          # ellipses ("...") that we accidentally truncated with
          # the previous statement.
        s = s.replace('&amp;', '&')
        s = sub('(\S)&', r'\1, &', s)
        s = sub(r'</i>, <i>(\d)', r', \1', s)
        s = sub(r'(\W)p\. (\S+[,–])', r'\1pp. \2', s)
        s = s.replace('⣥<ellipsis>⣥, ., &', '…')

        return s

    def parse_references(self, refs):
        def f(ref_):
            ref = deepcopy(ref_)
            ref_data = {}
            ref_key = ref.pop('id')
            ref_type = ref.pop('type')
            for key, value in ref.items():
                python_key = key.replace('-', '_')
                if python_key in NAMES:
                    value = [Name(**name_data) for name_data in value]
                elif python_key in DATES:
                    value = self.parse_date(value)
                elif python_key == 'shortTitle':
                    python_key = 'title_short'
                ref_data[python_key] = value
            return Reference(ref_key, ref_type, **ref_data)
        return list(map(f, refs))

    def parse_date(self, json_data):
        def parse_single_date(json_date):
            date_data = {}
            try:
                for i, part in enumerate(('year', 'month', 'day')):
                    date_data[part] = json_date[i]
            except IndexError:
                pass
            return date_data

        dates = list(map(parse_single_date, json_data['date-parts']))

        circa = json_data.get('circa', 0) != 0

        if len(dates) > 1:
            return DateRange(
                begin = Date(**dates[0]),
                end = Date(**dates[1]),
                circa = circa)
        else:
            return Date(circa = circa, **dates[0])

if __name__ == '__main__':
    # Do IPC.
    apa_style_path, = argv[1:]
    bibber = APABibber(apa_style_path)
    for l in stdin:
        o = json.loads(l)
        if o['command'] == 'quit':
            exit()
        elif o['command'] == 'bib1':
            print(json.dumps({'value': bibber.bib1(**o['args'])}))
        elif o['command'] == 'bib':
            print(json.dumps({'value': bibber.bib(**o['args'])}))
        else:
            print(json.dumps({'error': 'Illegal command: ' + o['command']}))
        stdout.flush()
