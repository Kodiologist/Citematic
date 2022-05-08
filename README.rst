Citematic::Get uses Google Scholar, the Library of Congress's online catalog, CrossRef_, and a variety of other websites (including PubMed, APA PsycNET, JSTOR, and ERIC) to get bibliographic data for search terms, completely avoiding paywalls. It returns at most one result per invocation, so if you aren't looking for a specific item, you're probably better off with web interfaces. It does elaborate work to get exactly correct APA style (by both cleaning the input bibliographic data and tweaking the output references-section entries), and has test cases for over 100 items, including journal articles, book chapters, and entire books.

The actual output of the ``get`` function provided by Citematic::Get is a nested data structure of `Citation Style Language`_ 1.0 variables (as specified in `the input data schema`__, except that no ``id`` is provided). The included Python module "quickbib" uses citeproc-py_ to generate bibliographies from CSL data using `any CSL style you like`__ (but with special support for APA style, because neither CSL nor citeproc-py can get it 100% right with only their built-in features). Citematic::QuickBib provides a Perl interface to quickbib, and the Perl script ``cite`` provides a handy command-line interface to the whole mess. Finally, Citematic::Get also has a function ``digest_ris`` for parsing `RIS`_, and the Python module "citematic_coins" has a function ``coins`` to generate `ContextObjects in Spans`_ (COinS) from CSL input data.

.. __: https://github.com/citation-style-language/schema/blob/master/csl-data.json
.. __: http://zotero.org/styles

Examples
============================================================
  
* ``$ cite 1983 tversky kahneman``

    Tversky, A., & Kahneman, D. (1983). Extensional versus intuitive reasoning: The conjunction fallacy in probability judgment. <i>Psychological Review, 90</i>, 293–315. doi:10.1037/0033-295X.90.4.293

* ``$ cite nisbett -t 'telling more than we can know'``

    Nisbett, R. E., & Wilson, T. D. (1977). Telling more than we can know: Verbal reports on mental processes. <i>Psychological Review, 84</i>, 231–259. doi:10.1037/0033-295X.84.3.231

* ``$ cite 10.1080/00224545.1979.9933632`` (a DOI)

    Zak, I. (1979). Modal personality of young Jews and Arabs in Israel. <i>Journal of Social Psychology, 109</i>, 3–10. doi:10.1080/00224545.1979.9933632

* ``$ cite 'Yates, J. F., Veinott, E. S., & Patalano, A. L. (2003).'``

    Yates, J. F., Veinott, E. S., & Patalano, A. L. (2003). Hard decisions, bad decisions: On decision quality and decision aiding. In S. L. Schneider & J. Shanteau (Eds.), <i>Emerging perspectives on judgment and decision research</i> (pp. 1–63). New York, NY: Cambridge University Press.

* ``$ cite 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2937254'``

    Swihart, B. J., Caffo, B., James, B. D., Strand, M., Schwartz, B. S., & Punjabi, N. M. (2010). Lasagna plots: A saucy alternative to spaghetti plots. <i>Epidemiology, 21</i>, 621–625. doi:10.1097/EDE.0b013e3181e5b06a

* ``$ cite --book 2000 -t 'programming perl'``

    Wall, L., Christiansen, T., & Orwant, J. (2000). <i>Programming Perl</i> (3rd ed.). Beijing, PRC: O'Reilly.

* ``$ cite 0394720245`` (an ISBN; implies ``--book``)

    Caro, R. A. (1974). <i>The power broker: Robert Moses and the fall of New York</i>. New York, NY: Vintage Books.

* ``$ cite arxiv:1504.00641``

    Patel, A. B., Nguyen, T., & Baraniuk, R. G. (2015). <i>A probabilistic theory of deep learning</i>. Retrieved from http://arxiv.org/abs/1504.00641

You can put bounds on the year, rather than searching for an exact year, by using syntax like this (not supported for Library of Congress searches):

- ``1990..`` — Items published in 1990 or later
- ``..2000`` — Items published in 2000 or earlier
- ``1990..2000`` — Items published between 1990 and 2000 inclusive

See ``cite --help`` for a description of command-line options. See ``Perl/test_citematic.pm`` for more examples of what Citematic::Get can find and ``Python/test_apa.py`` for more examples of what quickbib can format.

Installation
============================================================

#. Ensure you have the following Perl modules. You can install modules with ``sudo cpan install WWW::Mechanize`` or ``sudo cpanm WWW::Mechanize`` (using cpanminus_) or your package manager.

   * Citematic::Get requires: Business::ISBN File::Slurp HTML::Entities HTTP::Cookies::Mozilla HTTP::Request::Common JSON List::Util LWP::Simple Text::Aspell URI URI::Escape XML::Simple parent
   * Citematic::QuickBib requires: IPC::Run JSON
   * ``cite`` requires: File::Slurp Getopt::Long::Descriptive

#. You'll also need Firefox or another Mozilla browser, because Citematic uses Mozilla cookies to pass robot checks.

#. Install ``Get.pm``, ``QuickBib.pm``, and ``COinS.pm`` themselves, as by putting them in ``/etc/perl/Citematic``.

#. Ensure you have Python 3, then get and install (as by putting it in ``/usr/lib/python3/dist-packages``) citeproc-py_ and its own dependencies, as well as the files ``quickbib.py`` and ``citematic_coins.py`` provided by Citematic. The version of citeproc-py with which this version of Citematic has been tested is 0.3.0.

#. Download `apa.csl`_ (and, if you'll be running quickbib's one test for it, `mla.csl`_) and set the environment variable ``APA_CSL_PATH`` to where you put it (ditto ``MLA_CSL_PATH``).

#. Copy the example configuration file to ``$HOME/.citematic`` and edit it. You'll need to `register for CrossRef`_ before you can use your email address for ``crossref_email``.

Running the tests
============================================================

For quickbib, enter the Python directory and say ``py.test``. This requires `pytest`_.

For Citematic::Get, say ``perl test_citematic.pl`` and ``perl test_ris_input.pl``. This requires Test::More.

citematic_coins has no real test suite, but see ``coins_demo.py``.

Caveats
============================================================

The bibliographic data that exists is imperfect and only so much can be done automatically. For example, when the title of an article is provided in title case, we need to convert it to sentence case for APA style, but it's hard to tell whether some words should capitalized or uncapitalized (e.g., "China" is the word for the country but "china" is a synonym for "ceramic"). And in writing the test suite, I've found that bibliographic data contains a non insignificant number of outright errors. I've implemented some corrections for specific databases and specific journals, but not specific articles.

Every query is cached, but the cache never times out. You'll need to delete the cache file or edit it by hand in order to see any updates to the databases.

Why did you call it "Sittymatic"?
============================================================

It's pronounced "CITE-uh", you numskull.

Licenses
============================================================

Citematic contains some code in modified form to which the below copyrights and licenses apply. Citematic itself is licensed under the GPL ≥3.

License for citeproc-py
----------------------------------------

Copyright 2011-2013 Brecht Machiels. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those of the authors and should not be interpreted as representing official policies, either expressed or implied, of the copyright holder.

License for Connotea Code
----------------------------------------

Copyright 2005-2007 Nature Publishing Group.

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the `GNU General Public License`_ for more details.

License for Citematic
----------------------------------------

Citematic is copyright 2011–2022 Kodi Arfer.

Citematic is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

Citematic is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the `GNU General Public License`_ for more details.

.. _`Citation Style Language`: http://citationstyles.org/downloads/specification.html
.. _RIS: https://en.wikipedia.org/wiki/RIS_%28file_format%29
.. _`ContextObjects in Spans`: http://ocoins.info/
.. _`apa.csl`: https://github.com/citation-style-language/styles/blob/master/apa.csl
.. _`mla.csl`: https://github.com/citation-style-language/styles/blob/master/mla.csl
.. _CrossRef: http://crossref.org/
.. _`register for CrossRef`: http://www.crossref.org/requestaccount/
.. _`pytest`: http://pytest.org/
.. _cpanminus: https://github.com/miyagawa/cpanminus
.. _citeproc-py: https://github.com/brechtm/citeproc-py
.. _`GNU General Public License`: http://www.gnu.org/licenses/
