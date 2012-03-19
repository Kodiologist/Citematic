# -*- Python -*-

from os import environ
from quickbib import bib1, name

if 'MLA_CSL_PATH' not in environ:
    raise Exception('The environment variable MLA_CSL_PATH is not set')

def f(d, **kw):
    return bib1(environ['MLA_CSL_PATH'], d, **kw)

def merge_dicts(d1, d2):
    return dict(list(d1.items()) + list(d2.items()))

def j(o = None, **field_kws):
    fields = merge_dicts(
        dict(type = 'article-journal',
            author =
                [name('Robert F.', 'Pasternack'),
                name('Peter J.', 'Collins')],
            issued = {'date-parts': [[1995]]},
            title = 'Resonance light scattering: A new technique for studying chromophore aggregation',
            container_title = 'Science',
            volume = '269',
            page = '935–9',
            DOI = '10.1126/science.7638615'),
        field_kws)
    if o is None: o = {}
    return f(fields, **o)

def test_journal_article():
    assert j() == 'Pasternack, Robert F., and Peter J. Collins. "Resonance Light Scattering: A New Technique for Studying Chromophore Aggregation". <i>Science</i> 269 (1995): 935–9. Web.'
