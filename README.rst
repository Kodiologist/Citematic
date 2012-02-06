Citematic uses `EBSCOhost`_, `IDEAS`_ (i.e., `RePEc`_), and `CrossRef`_ to get an APA-style citation for search terms. In the case of EBSCOhost, it also tries to get full-text URLs. It returns at most one result per invocation, so if you aren't looking for a specific item, you're probably better off with the web interfaces.

Examples
============================================================

Supposing you've made an alias or symlink ``cite`` to ``Citematic.pm``:
  
* ``$ cite 1983 tversky kahneman``

    Tversky, A., & Kahneman, D. (1983). Extensional versus intuitive reasoning: The conjunction fallacy in probability judgment. \|Psychological Review, 90\|, 293–315. \`doi:10.1037/0033-295X.90.4.293\`

* ``$ cite nisbett -t 'telling more than we can know'``

    Nisbett, R. E., & Wilson, T. D. (1977). Telling more than we can know: Verbal reports on mental processes. \|Psychological Review, 84\|, 231–259. \`doi:10.1037/0033-295X.84.3.231\`

* ``$ cite 10.1080/00224545.1979.9933632``

    Zak, I. (1979). Modal personality of young Jews and Arabs in Israel. \|Journal of Social Psychology, 109\|, 3–10. \`doi:10.1080/00224545.1979.9933632\`

* ``$ cite 'McMackin, J., & Slovic, P. (2000).'``

    McMackin, J., & Slovic, P. (2000). When does explicit justification impair decision making? \|Applied Cognitive Psychology, 14\|, 527–541. \`doi:10.1002/1099-0720(200011/12)14:6<527::AID-ACP671>3.0.CO;2-J\`

See the test suite for more.

Installation
============================================================

First, ensure you have each of the Perl modules listed at the top of ``Citematic.pm``. You can install modules with ``sudo cpan install WWW::Mechanize`` or ``sudo cpanm WWW::Mechanize`` (using cpanminus_) or your package manager. Getopt::Long::Descriptive is also required for the command-line interface. Test::More is required to run the tests.

Next, copy the example configuration file to ``$HOME/.citematic`` and edit it. `Registering for CrossRef`_ is easy. Getting access to EBSCOhost is harder. There's a good chance that your school (if you're using Citematic, you must be a student or an academic, right? right?) or your local library has an institutional subscription that you can use from home. You may be able to log in with a single HTTP ``POST`` (the Firefox extension `Tamper Data`_ is helpful for figuring out how), in which case editing ``ebsco_login`` will be particularly easy. And if your IP address is already authenticated, then you don't need to log in at all, and you can set ``ebsco_login`` to a no-op like whitespace. (Perl programmers note that ``$_`` refers to a WWW::Mechanize object in this context.)

Caveats
============================================================

If you look at the code, you'll see that a great many cases need to be covered in order to parse all the idiosyncratic record formats. You'd hope that all that data would be systematically structured, huh? It isn't really, hence regexes. I've done a pretty good job (if I do say so myself) of covering psychology articles (particularly those represented in PsycINFO and PsycARTICLES), but more regexes will no doubt be needed if you plunge further into the depths of, say, MEDLINE. And while I implemented support for IDEAS so I can get economics articles, fields like mathematics and chemistry will probably need more databases. In short, I wrote this program for my own use, so I took pains to support the sort of articles I read (in experimental social psychology and JDM), but the further your interests are from mine, the more work you'd have to do to make Citematic useful. Patches are more than welcome; I would love for Citematic to be universal.

Another thing: every query is cached, but the cache never times out. You'll need to delete the cache file or edit it by hand (or in the case of EBSCO, use the ``-i`` option) in order to see any updates to the databases.

Will I get in trouble for using this program?
============================================================

So far as I can tell from `EBSCOhost's terms of use`_, `St. Louis Fed's legal-notices page`_, and `CrossRef's terms and conditions`_, no. You will notice that Citematic does not use Google Scholar or Scirus, which forbid automated queries.

There may be some restrictions on what you can do with the data you get, which apply just the same as if you'd used the web interface (e.g., EBSCO's terms say something about "non-commercial use"), but given that fair-use laws apply, I doubt you'll have any problems.

And, of course, since this is mostly done with web scraping, server-side changes could suddenly render Citematic inoperable.

Why didn't you use Z39.80?
============================================================

I couldn't get it to work.

Why did you call it "Sittymatic"?
============================================================

It's pronounced "CITE-uh", you numskull.

License
============================================================

Citematic is copyright 2012 Kodi Arfer.

Citematic is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

Citematic is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the `GNU General Public License`_ for more details.

.. _EBSCOhost: http://ebscohost.com/
.. _IDEAS: http://ideas.repec.org/
.. _RePEc: http://repec.org
.. _CrossRef: http://crossref.org/
.. _`registering for CrossRef`: http://www.crossref.org/requestaccount/
.. _`EBSCOhost's terms of use`: http://support.epnet.com/ehost/terms.html
.. _`St. Louis Fed's legal-notices page`: http://research.stlouisfed.org/legal.html
.. _`CrossRef's terms and conditions`: http://www.crossref.org/requestaccount/termsandconditions.html
.. _cpanminus: https://github.com/miyagawa/cpanminus
.. _`Tamper Data`: https://addons.mozilla.org/en-US/firefox/addon/tamper-data/
.. _`GNU General Public License`: http://www.gnu.org/licenses/
