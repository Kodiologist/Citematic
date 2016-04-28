from sys import stdin, stdout, argv
from string import ascii_lowercase
from re import sub, DOTALL
from io import StringIO
from collections import defaultdict
from copy import deepcopy
from random import random
import json

from citeproc import CitationStylesStyle, CitationStylesBibliography
from citeproc import NAMES, DATES
from citeproc.source import Reference, Name, Date, DateRange, Pages
from citeproc.source import Citation, CitationItem
from citeproc.string import String
import citeproc.formatter.plain
import citeproc.formatter.html

# ------------------------------------------------------------
# Public
# ------------------------------------------------------------

def name(given, family, suffix = None):
    n = dict(given = given, family = family)
    if suffix is not None: n['suffix'] = suffix
    return n

def bib1(style_path, d, **rest):
    return bib(style_path, [d], **rest)[0]

def bib(style_path,
        ds,
        return_cites_and_keys = False,
        formatter = "chocolate",
        dumb_quotes = True,
          # Turning this off won't educate any straight quotes in
          # the data, but leaving it on will stupefy all the
          # smart quotes in the output.
        apa_tweaks = True,
        # The below options are ignored unless apa_tweaks is on.
        always_include_issue = False,
        include_isbn = False,
        url_after_doi = False,
        publisher_website = True,
        abbreviate_given_names = True):

    if isinstance(formatter, str):
        try:             formatter = formatter_from_name[formatter]
        except KeyError: raise ValueError('Unknown formatter "{}"'.format(formatter))        

    style = get_style(style_path, apa_tweaks,
        include_isbn, url_after_doi, abbreviate_given_names)

    ds = deepcopy(ds)
    if apa_tweaks:
    # Distinguish entries that would have identical authors and years
    # by adding suffixes to the years.
        # Group works by author and year.
        #
        # (Actually, we use only an initial subset of authors,
        # the same number that would be included in an inline citation
        # after the first inline citation. This is 2 for 2 authors
        # and 1 otherwise.)
        ay = defaultdict(list)
        for d in ds:
            names = d.get('author') or d.get('editor')
            if len(names) != 2:
                names = [names[0]]
            k = repr(names)  + '/' + str(d['issued']['date-parts'][0][0])
            if not any(d is v for v in ay[k]):
                ay[k].append(d)
        # If any group has more than one element, add suffixes.
        for v in ay.values():
            if len(v) > 1:
                for i, d in enumerate(sorted(v, key = title_sort_key)):
                   d['year_suffix'] = ascii_lowercase[i]
    for d in ds:
        if 'id' not in d:
            d['id'] = str(random())
        for k in list(d.keys()):
            if d[k] is None: del d[k]
        if apa_tweaks:
            # By default, don't include the issue number for
            # journal articles.
            if not always_include_issue and d['type'] == 'article-journal':
                delf(d, 'issue')
            # Use the weird "Retrieved from Dewey, Cheatem, &
            # Howe website: http://example.com" format prescribed
            # for reports.
            if publisher_website and d['type'] == 'report' and 'publisher' in d and 'URL' in d:
                d['URL'] = '{} website: {}'.format(
                    d.pop('publisher'), d['URL'])
            # Add structure words for presentations and include
            # the event place.
            if d['type'] == 'speech' and d['genre'] == 'paper':
                d['event'] = 'meeting of the {}, {}'.format(
                    d.pop('publisher'), d['event-place'])
            if d['type'] == 'speech' and d['genre'] == 'video':
                d['medium'] = 'Video file'
                del d['genre']
            # When abbreviating given names, remove hyphens
            # preceding lowercase letters. Otherwise, weird
            # stuff happens.
            if abbreviate_given_names and 'author' in d:
               for a in d['author']:
                   if 'given' in a:
                       a['given'] = sub(
                           '-(.)',
                           lambda mo:
                               ("" if mo.group(1).islower() else "-") +
                               mo.group(1),
                           a['given'])
            # Abbreviate a long list of authors with an ellipsis
            # and the final author.
            if 'author' in d and len(d['author']) > 7:
                d['author'] = (
                    d['author'][0:6] +
                    [{'given': '', 'family': '⣥<ellipsis>⣥'}] +
                    d['author'][-1:])

    bibliography = CitationStylesBibliography(
        style,
        {ref.key: ref for ref in parse_references(ds)},
        formatter)
    cites = [ Citation([CitationItem(d['id'])]) for d in ds ]
    for c in cites: bibliography.register(c)
    def sort_key_f(item):
        ref = item.reference
        names = [(name['family'].lower(), name['given'][0].lower() if 'given' in name else '')
            for name in ref.get('author') or ref.get('editor')
            if name.family != '⣥<ellipsis>⣥']
        return (names, ref['issued']['year'],
            title_sort_key(ref),
            ref['page']['first'] if 'page' in ref else '')
    if len(ds) > 1:
        # Sort the bibliography
        # bibliography.sort()   # Doesn't appear to handle leading "the"s correctly.
        bibliography.items = sorted(bibliography.items, key = sort_key_f)
        bibliography.keys = [item.key for item in bibliography.items]
    bibl = bibliography.bibliography()

    for i, s in enumerate(bibl):
        s = ''.join(s)
        # Fix spacing and punctuation issues.
        s = s.replace('  ', ' ')
        s = sub(r'([.!?…])\.', r'\1', s)
        if dumb_quotes:
            s = s.replace('‘', "'").replace('’', "'").replace('“', '"').replace('”', '"')
        if apa_tweaks:
            if formatter is citeproc.formatter.html or formatter is chocolate:
                # Italicize the stuff between a journal name and a volume
                # number.
                s = sub(r'</i>, <i>(\d)', r', \1', s)
                # Remove redundant periods that are separated
                # from the first end-of-sentence mark by an </i>
                # tag.
                s = sub(r'([.!?…]</i>)\.', r'\1', s)
            # If there are two authors and the first is a mononym,
            # remove the comma after it.
            s = sub('^([^.,]+), &', r'\1 &', s)
            # Make "p." into "pp." when more than one page is cited.
            s = sub(r'(\W)p\. (\S+[,–])', r'\1pp. \2', s)
            # Replace the ellipsis placeholder.
            s = s.replace('⣥<ellipsis>⣥, ., &', '…')
        bibl[i] = s

    if return_cites_and_keys:
        fcites = [bibliography.cite(c, lambda x: None) for c in cites]
        return (fcites, bibliography.keys, bibl)
    else:
        return bibl

# ------------------------------------------------------------
# Private
# ------------------------------------------------------------

def delf(x, i):
    try:             del x[i]
    except KeyError: pass

def sub1(*p, **kw):
    return sub(*p, count = 1, **kw)

def title_sort_key(d):
    s = d.get('title') or d.get('container-title')
    return sub1(r'^a\s+|^the\s+', '', s.lower())

class chocolate(object):
    "A formatter that isn't quite plain."

    def preformat(text):  return text

    def _tagger(tag): return lambda s: "<{0}>{1}</{0}>".format(tag, s)

    Italic = _tagger('i')
    Oblique = Italic
    Bold = str
    Light = str
    Underline = str
    Superscript = _tagger('sup')
    Subscript = _tagger('sub')
    SmallCaps = str

    class Bibliography(str):
        def __new__(cls, items):
            items = map(str, items)
            return super().__new__(cls, '\n\n'.join(items))

formatter_from_name = dict(
    plain = citeproc.formatter.plain,
    html = citeproc.formatter.html,
    chocolate = chocolate)

style_cache = {}

def get_style(style_path, apa_tweaks, include_isbn, url_after_doi, abbreviate_given_names):

    idx = (style_path, apa_tweaks, include_isbn, url_after_doi, abbreviate_given_names)
    if idx in style_cache:
        return style_cache[idx]

    with open(style_path, encoding = 'UTF-8') as f:
         text = f.read()
    text = sub1(' encoding="[^"]+"', '', text)
      # lxml doesn't like encoding declarations.

    if apa_tweaks:
        text = sub1(r'(<macro name="container-title">.+?) text-case="title"',
            r'\1', text, flags = DOTALL)
          # Prevent automatic case changes of the container
          # title, in case it has internal capitalization (e.g.,
          # "NeuroReport").
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
        text = sub1(r'(<macro name="locators">\s+<choose>\s+)<if (.+?)</if>',
            r'''\1
            <if type="speech">
              <group prefix=" [" suffix="]">
                  <text variable="medium"/>
              </group>
            </if>
            <else-if type="software">
              <text value=" [Software]"/>
            </else-if>
            <else-if \2</else-if>''', text, flags = DOTALL)
          # Include "[Video file]" and "[Software]".
        text = sub1(r'(<else-if type=")(.+?" match="any">\s+<!--.+?-->\s+<choose>\s+<if variable="version">)',
           r'\1software \2',
           text)
          # Include "(Version ...)" for our nonstandard "software" type.
        if not abbreviate_given_names:
            text = sub(r'\s+initialize-with="[^"]+"', '', text)
        if include_isbn:
            text = sub1('(<text macro="access")',
                r'<text variable="ISBN" prefix=" ISBN " suffix = "."/> \1',
                text)
        if url_after_doi:
            text = sub1('(<text variable="DOI" prefix="doi:"/>)',
                r'<group delimiter=". ">\1<text variable="URL" prefix="Retrieved from "/></group>',
                text)

    style = CitationStylesStyle(StringIO(text), validate = False)
      # Validation is turned off since standard stylesheets,
      # including apa.csl, appear not to be valid.
    style_cache[idx] = style
    return style

def parse_references(refs):
    def f(ref_):
        ref = deepcopy(ref_)
        ref_data = {}
        ref_key = ref.pop('id').lower()
          # We need a lower() here because of the one
          # in the constructor of CitationItem.
        ref_type = ref.pop('type')
        for key, value in ref.items():
            python_key = key.replace('-', '_')
            if python_key in NAMES:
                value = [Name(**name_data) for name_data in value]
            elif python_key in DATES:
                value = parse_date(value)
            elif python_key == 'shortTitle':
                python_key = 'title_short'
            elif python_key == 'page':
                value.replace('–', '-')
                if '-' in value:
                    first, last = value.split('-')
                    value = Pages(first = first, last = last)
                else:
                    value = Pages(first = value)
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
