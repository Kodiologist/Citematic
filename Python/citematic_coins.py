# http://ocoins.info/

from collections import defaultdict
import urllib.parse, html

# ----------------------------------------------------------
# * Public
# ----------------------------------------------------------

def coins(csl):
    return '<span class="Z3988" title="{}"></span>'.format(
        html.escape(coins_data(csl)))

def coins_data(csl):
    csl = defaultdict(lambda: None, csl)
    article = 'article' in csl['type']
    l = []
    for a in csl['author'] or []:
        l += ['au', a['family'] + ', ' + a['given']
            if 'given' in a else a['family']]
    return kv(l + [
        'ctx_ver',   'Z39.88-2004',
        'rft_val_fmt',   article and
            'info:ofi/fmt:kev:mtx:journal' or
            'info:ofi/fmt:kev:mtx:book',
        'genre',   cond(
            csl['genre'] ==
                'Advance online publication', 'preprint',
            article,                          'article',
            csl['type'] == 'chapter',         'bookitem',
            csl['type'] == 'book',            'book',
            csl['type'] == 'report',          'report',
            True,                             'document'),
        'rft_id',   'DOI' in csl and "info:doi/" + csl['DOI'] or csl['URL'],
        'atitle',   csl['title'],
        (article and 'jtitle' or 'btitle'),   csl['container-title'],
        'date',   csl['issued']['date-parts'][0][0],
        'volume',   csl['volume'],
        'issue',   csl['issue'],
        'artnum',   csl['number'],
        'pages',   csl['pages'],
        'place',   csl['publisher-place'],
        'pub',   csl['publisher'],
        'isbn',   csl['ISBN']])

# ----------------------------------------------------------
# * Private
# ----------------------------------------------------------

def kv(l):
    result = []
    for k, v in zip(l[::2], l[1::2]):
        if v is None:
            continue
        if not (k.startswith('ctx_') or k.startswith('rft_')):
            k = 'rft.' + k
        result.append('{}={}'.format(
            urllib.parse.quote(bytes(k, 'UTF-8')),
            urllib.parse.quote(bytes(str(v), 'UTF-8'))))
    return '&'.join(result)

def cond(*x):
    for condition, value in zip(x[::2], x[1::2]):
        if condition:
            return value
