# -*- Python -*-

from os import environ
from apa import bib1, name

if 'APA_CSL_PATH' not in environ:
    raise Exception('The environment variable APA_CSL_PATH is not set')

def f(d, **kw):
    return bib1(environ['APA_CSL_PATH'], d,
        apa_tweaks = True, **kw)

def merge_dicts(d1, d2):
    return dict(list(d1.items()) + list(d2.items()))

def j(o = None, **field_kws):
    fields = merge_dicts(
        dict(type = 'article-journal',
            author =
                [name('Joesph', 'Bloggs'),
                name('J. Random', 'Hacker')],
            issued = {'date-parts': [[1983]]},
            title = 'The main title',
            container_title = 'Sciency Times',
            volume = '30', issue = '7',
            page = '293–315',
            DOI = '10.zzz/zzzzzz'),
        field_kws)
    if o is None: o = {}
    return f(fields, **o)

def test_journal_article():
    assert j() == 'Bloggs, J., & Hacker, J. R. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz'
      # Simple journal article
    assert j(doi = None), 'Bloggs, J., & Hacker, J. R. (1983). The main title. <i>Sciency Times, 30</i>, 293–315.'
      # No DOI
    assert j(o = {'always_include_issue': True}) == 'Bloggs, J., & Hacker, J. R. (1983). The main title. <i>Sciency Times, 30</i>(7), 293–315. doi:10.zzz/zzzzzz'
      # With issue number
    assert j(o = {'always_include_issue': True}, issue = None) == 'Bloggs, J., & Hacker, J. R. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz'
      # Issue number requested but unavailable
    assert j(o = {'abbreviate_given_names': False}), 'Bloggs, Joesph, & Hacker, J. Random. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz'
      # With full given names
    assert (j(o = {'abbreviate_given_names': False},
            author = [name('J.', 'Bloggs'), name('J. R.', 'Hacker')]) ==
        'Bloggs, J., & Hacker, J. R. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz')
     # Full given names requested but unavailable
    assert j(author = [name('J. J. J.', 'Schmidt')]) == 'Schmidt, J. J. J. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz'
      # Single author
    assert (j(author = [name('Ab', 'Alpha'), name('Be', 'Beta'),
            name('Ci', 'Gamma'), name('Do', 'Delta'),
            name('En', 'Epsilon'), name('Fo', 'Zeta'), name('Gy', 'Eta')]) ==
        'Alpha, A., Beta, B., Gamma, C., Delta, D., Epsilon, E., Zeta, F., & Eta, G. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz')
      # Seven authors
    assert (j(author = [name('Ab', 'Alpha'), name('Be', 'Beta'),
            name('Ci', 'Gamma'), name('Do', 'Delta'),
            name('En', 'Epsilon'), name('Fo', 'Zeta'), name('Gy', 'Eta'),
            name('Ha', 'Theta')]) ==
        'Alpha, A., Beta, B., Gamma, C., Delta, D., Epsilon, E., Zeta, F., … Theta, H. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz')
      # Eight authors
    assert (j(author = [name('Ab', 'Alpha', 'Jr.'), name('Be', 'Beta', 'Sr.'),
            name('Ci', 'Gamma', 'III'), name('Do', 'Delta', 'XIV')]) ==
        'Alpha, A., Jr., Beta, B., Sr., Gamma, C., III, & Delta, D., XIV. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz')
      # Authors with suffixes
    assert (j(author = [name('Mary-Jane', 'Sally')]) ==
        'Sally, M.-J. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz')
      # Given name with hyphen
    assert (j(author = [name('Áéíóú', 'Xyzzy'),
         name('Þómas Þybalt', 'Turner'), name('Ōy', 'Sam')]) ==
         'Xyzzy, Á., Turner, Þ. Þ., & Sam, Ō. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz')
      # Given names beginning with non-ASCII characters
    assert (j(title = 'But why?') ==
        'Bloggs, J., & Hacker, J. R. (1983). But why? <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz')
      # Title ending with question mark
    assert (j(title = 'Gadzooks!') ==
        'Bloggs, J., & Hacker, J. R. (1983). Gadzooks! <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz')
      # Title ending with exclamation point
    assert (j(title = 'And then…') ==
        'Bloggs, J., & Hacker, J. R. (1983). And then… <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz')
      # Title ending with ellipsis
    assert (j(page = 'S15–Z90') ==
        'Bloggs, J., & Hacker, J. R. (1983). The main title. <i>Sciency Times, 30</i>, S15–Z90. doi:10.zzz/zzzzzz')
      # Page numbers that aren't numbers
    assert (j(volume = None, issue = None, page = None, genre = 'Advance online publication') ==
        'Bloggs, J., & Hacker, J. R. (1983). The main title. <i>Sciency Times</i>. Advance online publication. doi:10.zzz/zzzzzz')
      # Advance online publication

def test_report():
    assert (f(dict(
            type = 'report',
            author =
               [name('Anna', 'Dreber'),
                name('Christer', 'Gerdes'),
                name('Patrik', 'Gränsmark')],
            issued = {'date-parts': [[2010]]},
            title = 'Beauty queens and battling knights: Risk taking and attractiveness in chess',
            genre = 'Discussion Paper No. 5314',
            publisher = 'Institute for the Study of Labor',
            URL = 'http://ftp.iza.org/dp5314.pdf')) ==
        'Dreber, A., Gerdes, C., & Gränsmark, P. (2010). <i>Beauty queens and battling knights: Risk taking and attractiveness in chess</i> (Discussion Paper No. 5314). Retrieved from Institute for the Study of Labor website: http://ftp.iza.org/dp5314.pdf')
      # Technical report

def test_informal():
    assert (f(dict(type = 'manuscript',
            author = [name('S. D.', 'Mitchell')],
            issued = {'date-parts': [[2000]]},
            title = 'The import of uncertainty',
            URL = 'http://philsci-archive.pitt.edu/archive/00000162/')) ==
        'Mitchell, S. D. (2000). <i>The import of uncertainty</i>. Retrieved from http://philsci-archive.pitt.edu/archive/00000162/')
      # Informally published paper

def b(o = None, **field_kws):
    return j(o, **merge_dicts(
        dict(type = 'book',
            journal = None, volume = None, issue = None,
            page = None, container_title = None,
            publisher = 'Ric-Rac Press',
            publisher_place = 'Tuscon, AZ', 
            ISBN = '0123456789'),
        field_kws))

def test_book():
    assert b() == 'Bloggs, J., & Hacker, J. R. (1983). <i>The main title</i>. Tuscon, AZ: Ric-Rac Press. doi:10.zzz/zzzzzz'
      # Whole book
    assert b(o = {'include_isbn': True}) == 'Bloggs, J., & Hacker, J. R. (1983). <i>The main title</i>. Tuscon, AZ: Ric-Rac Press. ISBN 0123456789. doi:10.zzz/zzzzzz'
      # Including ISBN
    assert (b(o = {'include_isbn': True}, DOI = None) ==
        'Bloggs, J., & Hacker, J. R. (1983). <i>The main title</i>. Tuscon, AZ: Ric-Rac Press. ISBN 0123456789.')
      # Including ISBN but no DOI
    assert b(volume = 3) == 'Bloggs, J., & Hacker, J. R. (1983). <i>The main title</i> (Vol. 3). Tuscon, AZ: Ric-Rac Press. doi:10.zzz/zzzzzz'
      # With a volume number
    assert (b(author = None, editor = [name('John Quixote', 'Doe')]) ==
        'Doe, J. Q. (Ed.). (1983). <i>The main title</i>. Tuscon, AZ: Ric-Rac Press. doi:10.zzz/zzzzzz')
      # With an editor and no authors

def e(o = None, **field_kws):
    return b(o, **merge_dicts(
        dict(type = 'chapter',
            page = '12–15',
            container_title = 'The book of love',
            editor = [name('John Quixote', 'Doe')]),
        field_kws))

def test_chapter():
    assert e() == 'Bloggs, J., & Hacker, J. R. (1983). The main title. In J. Q. Doe (Ed.), <i>The book of love</i> (pp. 12–15). Tuscon, AZ: Ric-Rac Press. doi:10.zzz/zzzzzz'
      # Book chapter with one editor
    assert (e(editor = [name('John Quixote', 'Doe'), name('Richard X.', 'Roe')]) ==
         'Bloggs, J., & Hacker, J. R. (1983). The main title. In J. Q. Doe & R. X. Roe (Eds.), <i>The book of love</i> (pp. 12–15). Tuscon, AZ: Ric-Rac Press. doi:10.zzz/zzzzzz')
      # Two editors
    assert (e(editor = [name('John Quixote', 'Doe'), name('Richard X.', 'Roe'),
            name('Kat', 'Gully')]) ==
        'Bloggs, J., & Hacker, J. R. (1983). The main title. In J. Q. Doe, R. X. Roe, & K. Gully (Eds.), <i>The book of love</i> (pp. 12–15). Tuscon, AZ: Ric-Rac Press. doi:10.zzz/zzzzzz')
      # Three editors
    #assert (e(editors = [name('John Quixote', 'Doe', 'Sr.')]) ==
    #    'Bloggs, J., & Hacker, J. R. (1983). The main title. In J. Q. Doe Sr. (Ed.), <i>The book of love</i> (pp. 12–15). Tuscon, AZ: Ric-Rac Press. doi:10.zzz/zzzzzz')
      # Editor with a suffix
      # (No, I'm not sure that's correct.)
    assert e(page = '12') == 'Bloggs, J., & Hacker, J. R. (1983). The main title. In J. Q. Doe (Ed.), <i>The book of love</i> (p. 12). Tuscon, AZ: Ric-Rac Press. doi:10.zzz/zzzzzz'
      # One-page chapter
    assert e(o = {'abbreviate_given_names': 0}) == 'Bloggs, Joesph, & Hacker, J. Random. (1983). The main title. In John Quixote Doe (Ed.), <i>The book of love</i> (pp. 12–15). Tuscon, AZ: Ric-Rac Press. doi:10.zzz/zzzzzz'
      # Full given names

test_journal_article()