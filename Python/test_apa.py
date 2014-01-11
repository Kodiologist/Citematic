# -*- Python -*-

from os import environ
from quickbib import bib, name

if 'APA_CSL_PATH' not in environ:
    raise Exception('The environment variable APA_CSL_PATH is not set')

def f(ds, multi = False, **kw):
    if not multi: ds = [ds]
    for d in ds:
        for k in d: d[k.replace('_', '-')] = d.pop(k)
    bibl = bib(environ['APA_CSL_PATH'], ds, apa_tweaks = True, **kw)
    return bibl if multi else bibl[0]

def merge_dicts(d1, d2):
    return dict(list(d1.items()) + list(d2.items()))

def jf(**field_kws):
    return merge_dicts(
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

def j(o = None, **field_kws):
    if o is None: o = {}
    return f(jf(**field_kws), **o)

def test_journal_article():
    assert j() == 'Bloggs, J., & Hacker, J. R. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz'
      # Simple journal article
    assert j(DOI = None), 'Bloggs, J., & Hacker, J. R. (1983). The main title. <i>Sciency Times, 30</i>, 293–315.'
      # No DOI
    assert j(o = {'always_include_issue': True}) == 'Bloggs, J., & Hacker, J. R. (1983). The main title. <i>Sciency Times, 30</i>(7), 293–315. doi:10.zzz/zzzzzz'
      # With issue number
    assert j(o = {'always_include_issue': True}, issue = None) == 'Bloggs, J., & Hacker, J. R. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz'
      # Issue number requested but unavailable
    assert j(o = {'abbreviate_given_names': False}), 'Bloggs, Joesph, & Hacker, J. Random. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz'
      # With full given names
    assert (j(o = {'url_after_doi': True}, URL = 'http://example.com') ==
        'Bloggs, J., & Hacker, J. R. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz. Retrieved from http://example.com')
      # With URL
    assert (j(o = {'url_after_doi': True}) ==
        'Bloggs, J., & Hacker, J. R. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz')
      # URL requested but not available
    assert (j(DOI = None, URL = 'http://example.com') ==
        'Bloggs, J., & Hacker, J. R. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. Retrieved from http://example.com')
      # No DOI, so URL included by default
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
      # Given name with hyphen followed by a capital
    assert (j(author = [name('Mary-jane', 'Sally')]) ==
        'Sally, M. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz')
      # Given name with hyphen follow by a lowercase letter
      # (Actually, I'm not sure if this should be
      # "M." or "M.-j." or "M.-J.".)
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

def test_sorting():
    d = jf()
    l = [d, d,
       jf(title = 'Quails'),
       jf(issued = {'date-parts': [[1984]]}),
       jf(author = [name('Joesph', 'Aloggs'), name('J. Random', 'Hacker')]),
       d]
    assert f(l, multi = True) == [
        'Aloggs, J., & Hacker, J. R. (1983). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz',
        'Bloggs, J., & Hacker, J. R. (1983a). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz',
        'Bloggs, J., & Hacker, J. R. (1983b). Quails. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz',
        'Bloggs, J., & Hacker, J. R. (1984). The main title. <i>Sciency Times, 30</i>, 293–315. doi:10.zzz/zzzzzz']

def test_report():
# Technical report
    def r(publisher_website):
        return f(publisher_website = publisher_website, ds = dict(
            type = 'report',
            author =
               [name('Anna', 'Dreber'),
                name('Christer', 'Gerdes'),
                name('Patrik', 'Gränsmark')],
            issued = {'date-parts': [[2010]]},
            title = 'Beauty queens and battling knights: Risk taking and attractiveness in chess',
            genre = 'Discussion Paper No. 5314',
            publisher = 'Institute for the Study of Labor',
            URL = 'http://ftp.iza.org/dp5314.pdf'))
    assert (r(True) ==
        'Dreber, A., Gerdes, C., & Gränsmark, P. (2010). <i>Beauty queens and battling knights: Risk taking and attractiveness in chess</i> (Discussion Paper No. 5314). Retrieved from Institute for the Study of Labor website: http://ftp.iza.org/dp5314.pdf')
    assert (r(False) ==
        'Dreber, A., Gerdes, C., & Gränsmark, P. (2010). <i>Beauty queens and battling knights: Risk taking and attractiveness in chess</i> (Discussion Paper No. 5314). Institute for the Study of Labor. Retrieved from http://ftp.iza.org/dp5314.pdf')

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

def test_mononyms():
    assert b(author = [dict(family = 'Jimbo')]) == 'Jimbo. (1983). <i>The main title</i>. Tuscon, AZ: Ric-Rac Press. doi:10.zzz/zzzzzz'
      # Just a mononym as author.
    assert b(author = [name('John', 'Doe'), dict(family = 'Jimbo')]) == 'Doe, J., & Jimbo. (1983). <i>The main title</i>. Tuscon, AZ: Ric-Rac Press. doi:10.zzz/zzzzzz'
      # A mononym at the end of the author list.
    assert b(author = [name('John', 'Doe'), dict(family = 'Jimbo'), name('Richard', 'Roe')]) == 'Doe, J., Jimbo, & Roe, R. (1983). <i>The main title</i>. Tuscon, AZ: Ric-Rac Press. doi:10.zzz/zzzzzz'
      # A mononym in the middle.
    # I haven't tested a mononym as the first item of a two-author
    # list, because who's to say if it should end with a comma?

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

def test_magazine_article():
    assert (f(dict(type = 'article-magazine',
            author = [name('John', 'Cloud')],
            issued = {'date-parts': [[2006, 2, 13]]},
            container_title = 'Time',
            title = 'The third wave of therapy',
            URL = 'http://www.time.com/time/magazine/article/0,9171,1156613-1,00.html')) ==
        'Cloud, J. (2006, February 13). The third wave of therapy. <i>Time</i>. Retrieved from http://www.time.com/time/magazine/article/0,9171,1156613-1,00.html')

def test_newspaper_article():
    assert (f(dict(type = 'article-newspaper',
            author = [name('Benedict', 'Carey')],
            issued = {'date-parts': [[2011, 6, 23]]},
            container_title = 'The New York Times',
            title = 'Expert on mental illness reveals her own fight',
            URL = 'http://www.nytimes.com/2011/06/23/health/23lives.html')) ==
        'Carey, B. (2011, June 23). Expert on mental illness reveals her own fight. <i>The New York Times</i>. Retrieved from http://www.nytimes.com/2011/06/23/health/23lives.html')
  # Yes, the "The" in "The New York Times" is included: see
  # http://www.apastyle.org/learn/faqs/cite-newspaper.aspx

def test_conference_paper():
  # If I understand
  #   http://forums.zotero.org/discussion/4782/csl-getting-conference-name-to-show-up-properly-in-bibliography#Comment_20601 ,
  # correctly, "paper-conference" should only be used for papers
  # published in proceedings; otherwise, one should use "speech".
    assert (f(dict(type = 'speech',
            URL = 'http://www.bapfelbaumphd.com/Sexual_Reality.html',
            author = [name('Bernard', 'Apfelbaum')],
            issued = {'date-parts': [[1984, 11]]},
            title = 'Sexual reality and how we dismiss it',
            genre = 'paper',
            publisher = 'American Association of the Advancement of Science',
            event_place = 'San Francisco State University, San Francisco, CA')) ==
        'Apfelbaum, B. (1984, November). <i>Sexual reality and how we dismiss it</i>. Paper presented at the meeting of the American Association of the Advancement of Science, San Francisco State University, San Francisco, CA. Retrieved from http://www.bapfelbaumphd.com/Sexual_Reality.html')

def test_video():
  # http://blog.apastyle.org/apastyle/2011/10/how-to-create-a-reference-for-a-youtube-video.html
    assert (f(dict(type = 'speech',
            URL = 'http://www.youtube.com/watch?v=6nyGCbxD848',
            title = 'Real ghost girl caught on Video Tape 14',
            author = [name('M.', 'Apsolon')],
            issued = {'date-parts': [[2011, 9, 9]]},
            genre = 'video')) ==
        'Apsolon, M. (2011, September 9). <i>Real ghost girl caught on Video Tape 14</i> [Video file]. Retrieved from http://www.youtube.com/watch?v=6nyGCbxD848')
