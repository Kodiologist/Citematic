from sys import stdin, stdout, argv
from re import sub, DOTALL
from io import StringIO
from copy import deepcopy
from random import random
import json

from citeproc import CitationStylesStyle, CitationStylesBibliography
from citeproc import NAMES, DATES
from citeproc.source import Reference, Name, Date, DateRange
from citeproc.source import Citation, CitationItem
from citeproc.string import String

# ------------------------------------------------------------
# Public
# ------------------------------------------------------------

def name(given, family, suffix = None):
    n = dict(given = given, family = family)
    if suffix is not None: n['suffix'] = suffix
    return n

def bib1(style_path, d, trim = True, **rest):
    return bib(style_path, [d], trim = trim, **rest)

def bib(style_path,
        ds,
        trim = False,
        apa_tweaks = True,
        # The below options are ignored unless apa_tweaks is on.
        always_include_issue = False,
        include_isbn = False,
        abbreviate_given_names = True):

    style = get_style(style_path, apa_tweaks,
        include_isbn, abbreviate_given_names)

    ds = deepcopy(ds)
    for d in ds:
        d['id'] = str(random())
        for k in list(d.keys()):
            if d[k] is None: del d[k]
        if apa_tweaks:
            # By default, don't include the issue number for
            # journal articles.
            if not always_include_issue and d['type'] == 'article-journal':
                delf(d, 'issue')
            # Use the weird "Retrieved from Dewey, Cheatem, &
            # Howe website: http://example.com" format perscribed
            # for reports.
            if d['type'] == 'report' and 'publisher' in d and 'URL' in d:
                d['URL'] = '{} website: {}'.format(
                    d.pop('publisher'), d['URL'])
            # Abbreviate a long list of authors with an ellipsis
            # and the final author.
            if d.get('author') and len(d['author']) > 7:
                d['author'] = (
                    d['author'][0:6] +
                    [{'given': '', 'family': '⣥<ellipsis>⣥'}] +
                    d['author'][-1:])

    bibliography = CitationStylesBibliography(
        style,
        {ref.key: ref for ref in parse_references(ds)})
    bibliography.register(Citation(
        [ CitationItem(d['id']) for d in ds ]))
    s = bibliography.bibliography()
    if trim:
        s = sub(r'</?div[^>]*>', '', s)
        s = sub(' *\n *', '\n', s)
        s = s.strip()
        s = s.replace('\n', '\n\n')
          # To provide a bit more visual separation.

    # Fix spacing and punctuation issues.
    s = s.replace('  ', ' ')
    s = sub(r'([.!?…])\.', r'\1', s)
    s = s.replace('&amp;', '&')
    s = s.replace('‘', "'").replace('’', "'").replace('“', '"').replace('”', '"')
    if apa_tweaks:
        # Italicize the stuff between a journal name and a volume
        # number.
        s = sub(r'</i>, <i>(\d)', r', \1', s)
        # Make "p." into "pp." when more than one page is cited.
        s = sub(r'(\W)p\. (\S+[,–])', r'\1pp. \2', s)
        # Replace the ellipsis placeholder.
        s = s.replace('⣥<ellipsis>⣥, ., &', '…')

    return s

# ------------------------------------------------------------
# Private
# ------------------------------------------------------------

def delf(x, i):
    if i in x: del x[i]

def sub1(*p, **kw):
    return sub(*p, count = 1, **kw)

style_cache = {}

def get_style(style_path, apa_tweaks, include_isbn, abbreviate_given_names):

    idx = (style_path, apa_tweaks, include_isbn, abbreviate_given_names)
    if idx in style_cache:
        return style_cache[idx]

    with open(style_path, encoding = 'UTF-8') as f:
         text = f.read()
    text = sub1(' encoding="[^"]+"', '', text)
      # lxml doesn't like encoding declarations.

    if apa_tweaks:
        text = sub1(r'(<macro name="secondary-contributors">\s+<choose>\s+<if type=")',
            r'\1book ', text)
          # Prevent an edited book from having its editors
          # mentioned twice.
        text = sub1(
             '(<bibliography.+?) et-al-min="8" et-al-use-first="7"',
             r'\1', text)
          # We'll use our own hacky way to abbreviate the author
          # list, in order to get the ellipsis-followed-by-final-
          # author style required by APA.
        if not abbreviate_given_names:
            text = sub(r'\s+initialize-with="[^"]+"', '', text)
        if include_isbn:
            text = sub1('(<text macro="access")',
                r'<text variable="ISBN" prefix=" ISBN " suffix = "."/> \1',
                text)

    style = CitationStylesStyle(StringIO(text))
    style_cache[idx] = style
    return style

def parse_references(refs):
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
                value = parse_date(value)
            elif python_key == 'shortTitle':
                python_key = 'title_short'
            else:
                value = String(value)
            ref_data[python_key] = value
        return Reference(ref_key, ref_type, **ref_data)
    return list(map(f, refs))

def parse_date(data):
    def parse_single_date(date):
        date_data = {}
        try:
            for i, part in enumerate(('year', 'month', 'day')):
                date_data[part] = date[i]
        except IndexError:
            pass
        return date_data

    dates = list(map(parse_single_date, data['date-parts']))

    circa = data.get('circa', 0) != 0

    if len(dates) > 1:
        return DateRange(
            begin = Date(**dates[0]),
            end = Date(**dates[1]),
            circa = circa)
    else:
        return Date(circa = circa, **dates[0])

# ------------------------------------------------------------
# Mainline code
# ------------------------------------------------------------

if __name__ == '__main__':
    # Accept IPC commands.
    for l in stdin:
        o = json.loads(l)
        if o['command'] == 'quit':
            exit()
        elif o['command'] == 'bib1':
            print(json.dumps({'value': bib1(**o['args'])}))
        elif o['command'] == 'bib':
            print(json.dumps({'value': bib(**o['args'])}))
        else:
            print(json.dumps({'error': 'Illegal command: ' + o['command']}))
        stdout.flush()
