#!/usr/bin/perl

use utf8;
use warnings;
use strict;
use Citematic::Get 'get';
use Citematic::QuickBib;
use Test::More;

# UTF-8 nonsense
   {my $builder = Test::More->builder;
    binmode $builder->output, ":utf8";
    binmode $builder->failure_output, ":utf8";
    binmode $builder->todo_output, ":utf8";}

my $qb = new Citematic::QuickBib;

sub apa
   {my $x = get(@_);
    defined $x or return undef;
    $qb->bib1($x,
        style_path => $ENV{APA_CSL_PATH} ||
            die('The environment variable APA_CSL_PATH is not set'),
        apa_tweaks => 1,
        always_include_issue => 1, include_isbn => 1)}
sub book {apa(book => 1, @_)}


note '~~~ Journal articles - using Google Scholar ~~~';

is apa(year => 1991, author => ['smith', 'dechter']),
    'Smith, H. L., & Dechter, A. (1991). No shift in locus of control among women during the 1970s. <i>Journal of Personality and Social Psychology, 60</i>(4), 638–640. doi:10.1037/0022-3514.60.4.638',
    'JPSP';
is apa(year => 1967, author => ['valins', 'ray']),
    'Valins, S., & Ray, A. A. (1967). Effects of cognitive desensitization on avoidance behavior. <i>Journal of Personality and Social Psychology, 7</i>(4), 345–350. doi:10.1037/h0025239',
    'JPSP (old article)';
is apa(year => 1966, author => ['lerner', 'simmons']),
    q{Lerner, M. J., & Simmons, C. H. (1966). Observer's reaction to the "innocent victim": Compassion or rejection? <i>Journal of Personality and Social Psychology, 4</i>(2), 203–210. doi:10.1037/h0023562},
    'JPSP (single quotes in given form of title)';
is apa(year => 2005, author => [qw(Bechara Damasio Tranel)], title => ['answers']),
    'Bechara, A., Damasio, H., Tranel, D., & Damasio, A. R. (2005). The Iowa Gambling Task and the somatic marker hypothesis: Some questions and answers. <i>Trends in Cognitive Sciences, 9</i>(4), 159–162. doi:10.1016/j.tics.2005.02.002',
    'Trends in Cognitive Sciences';
is apa(year => 2004, author => ['maia', 'McClelland']),
    'Maia, T. V., & McClelland, J. L. (2004). A reexamination of the evidence for the somatic marker hypothesis: What participants really know in the Iowa gambling task. <i>Proceedings of the National Academy of Sciences, 101</i>(45), 16075–16080. doi:10.1073/pnas.0406666101',
    'PNAS';
is get(year => 2004, author => ['maia', 'McClelland'])->{author}[0]{given},
    'Tiago V.',
    '…initials have periods (1)';
is apa(year => 1983, author => ['Tversky', 'Kahneman']),
    'Tversky, A., & Kahneman, D. (1983). Extensional versus intuitive reasoning: The conjunction fallacy in probability judgment. <i>Psychological Review, 90</i>(4), 293–315. doi:10.1037/0033-295X.90.4.293',
    'Psychological Review';
is get(year => 1983, author => ['Tversky', 'Kahneman'])->{author}[0]{given},
    'Amos',
    '…first name is preserved (1)';
is get(year => 1983, author => ['Tversky', 'Kahneman'])->{author}[1]{given},
    'Daniel',
    '…first name is preserved (2)';
is get(year => 1983, author => ['Tversky', 'Kahneman'])->{title},
    'Extensional versus intuitive reasoning: The conjunction fallacy in probability judgment',
    '…trailing period not left in title (1)';
is apa(author => ['Regenwetter', 'Dana', 'Davis-Stober'], title => ['transitivity']),
    'Regenwetter, M., Dana, J., & Davis-Stober, C. P. (2011). Transitivity of preferences. <i>Psychological Review, 118</i>(1), 42–56. doi:10.1037/a0021150',
    'Psychological Review (confusing period in MasterFILE record)';
is apa(year => 2010, author => ['trope', 'liberman'], title => ['construal-level theory']),
    'Trope, Y., & Liberman, N. (2010). Construal-level theory of psychological distance. <i>Psychological Review, 117</i>(2), 440–463. doi:10.1037/a0018963',
    'Psychological Review (article for which a correction exists)';
is apa(title => ['telling more than we can know'], year_max => 1980),
    'Nisbett, R. E., & Wilson, T. D. (1977). Telling more than we can know: Verbal reports on mental processes. <i>Psychological Review, 84</i>(3), 231–259. doi:10.1037/0033-295X.84.3.231',
    'Psychological Review (upper year bound)';
is apa(title => ['pac-man'], year_min => 1993, year_max => 1999),
    'Emes, C. E. (1997). Is Mr Pac Man eating our children? A review of the effect of video games on children. <i>Canadian Journal of Psychiatry, 42</i>(4), 409–414. doi:10.1177/070674379704200408',
    'Canadian Journal of Psychiatry (double year bounds)';
is get(title => ['pac-man'], year_min => 1993, year_max => 1999)->{author}[0]{given},
    'C. E.',
    '…initials have periods (2)';
is apa(title => ['alleged sex research']),
    'Benjamin, L. T., Jr., Whitaker, J. L., Ramsey, R. M., & Zeve, D. R. (2007). John B. Watson\'s alleged sex research: An appraisal of the evidence. <i>American Psychologist, 62</i>(2), 131–139. doi:10.1037/0003-066X.62.2.131',
    'American Psychologist (author with "Jr.", miscapitalized title with middle initial)';
is get(title => ['alleged sex research'])->{author}[0]{suffix},
    'Jr.',
    '…suffix has a period (1)';
is apa(year => 2012, author => ['mckerchar', 'renda']),
    'McKerchar, T. L., & Renda, C. R. (2012). Delay and probability discounting in humans: An overview. <i>Psychological Record, 62</i>(4), 817–834. doi:10.1007/BF03395837',
    'Psychological Record';
is apa(year => 2000, author => ['McMackin', 'Slovic']),
    'McMackin, J., & Slovic, P. (2000). When does explicit justification impair decision making? <i>Applied Cognitive Psychology, 14</i>(6), 527–541. doi:10.1002/1099-0720(200011/12)14:6<527::AID-ACP671>3.0.CO;2-J',
    'Applied Cognitive Psychology';
is apa(year => 1988, author => [qw(MacGregor Lichtenstein Slovic)]),
    'MacGregor, D., Lichtenstein, S., & Slovic, P. (1988). Structuring knowledge retrieval: An analysis of decomposed quantitative judgments. <i>Organizational Behavior and Human Decision Processes, 42</i>(3), 303–323. doi:10.1016/0749-5978(88)90003-9',
    'Organizational Behavior and Human Decision Processes';
is apa(title => ['heart and mind in conflict']),
    'Shiv, B., & Fedorikhin, A. (1999). Heart and mind in conflict: The interplay of affect and cognition in consumer decision making. <i>Journal of Consumer Research, 26</i>(3), 278–292. doi:10.1086/209563',
    'Journal of Consumer Research';
is apa(year => 2011, author => [qw(Dunn Greenhill Levinson Gray)]),
    'Dunn, M., Greenhill, S. J., Levinson, S. C., & Gray, R. D. (2011). Evolved structure of language shows lineage-specific trends in word-order universals. <i>Nature, 473</i>(7345), 79–82. doi:10.1038/nature09923',
    'Nature';
is apa(year => 2009, author => [qw(Chapman Kim Susskind Anderson)]),
    'Chapman, H. A., Kim, D. A., Susskind, J. M., & Anderson, A. K. (2009). In bad taste: Evidence for the oral origins of moral disgust. <i>Science, 323</i>(5918), 1222–1226. doi:10.1126/science.1165565',
    'Science';
is apa(author => ['lee', 'schwarz'], title => ['washing']),
    'Lee, S. W. S., & Schwarz, N. (2010). Washing away postdecisional dissonance. <i>Science, 328</i>(5979), 709. doi:10.1126/science.1186799',
    'Science (one-page article, author-title search)';
is apa(year => 1965, author => ['zajonc'], title => ['facilitation']),
    'Zajonc, R. B. (1965). Social facilitation. <i>Science, 149</i>(3681), 269–274. doi:10.1126/science.149.3681.269',
    'Science (funny "Source" format)';
is apa(year => 2002, author => ['Fantino', 'Esfandiari']),
    'Fantino, E., & Esfandiari, A. (2002). Probability matching: Encouraging optimal responding in humans. <i>Canadian Journal of Experimental Psychology, 56</i>(1), 58–63. doi:10.1037/h0087385',
    'Canadian Journal of Experimental Psychology (journal with foreign-language name)';
is apa(year => 1995, author => ['Buzsáki', 'Chrobak'], title => ['temporal']),
    'Buzsáki, G., & Chrobak, J. J. (1995). Temporal structure in spatially organized neuronal ensembles: A role for interneuronal networks. <i>Current Opinion in Neurobiology, 5</i>(4), 504–510. doi:10.1016/0959-4388(95)80012-3',
    q[Current Opinion in Neurobiology (diacritic in first author's name)];
is apa(year => 1998, author => ['Hsee'], title => ['less is better']),
    'Hsee, C. K. (1998). Less is better: When low-value options are valued more highly than high-value options. <i>Journal of Behavioral Decision Making, 11</i>(2), 107–121. doi:10.1002/(SICI)1099-0771(199806)11:2<107::AID-BDM292>3.0.CO;2-Y',
    'Journal of Behavioral Decision Making (year-author-title search)';
is apa(year => 2006, author => ['ditto', 'pizarro']),
    'Ditto, P. H., Pizarro, D. A., Epstein, E. B., Jacobson, J. A., & MacDonald, T. K. (2006). Visceral influences on risk-taking behavior. <i>Journal of Behavioral Decision Making, 19</i>(2), 99–113. doi:10.1002/bdm.520',
    'Journal of Behavioral Decision Making (miscapitalized title)';
is apa(year => 2007, author => ['levin', 'pederson']),
    'Levin, I. P., Weller, J. A., Pederson, A. A., & Harshman, L. A. (2007). Age-related differences in adaptive decision making: Sensitivity to expected value in risky choice. <i>Judgment and Decision Making, 2</i>, 225–233. Retrieved from http://journal.sjdm.org/7404/jdm7404.htm',
    'Judgment and Decision Making';
is apa(doi => '10.1111/j.1539-6924.2008.01065.x'),
    'Wilson, R. S., Arvai, J. L., & Arkes, H. R. (2008). My loss is your loss… sometimes: Loss aversion and the effect of motivational biases. <i>Risk Analysis, 28</i>(4), 929–938. doi:10.1111/j.1539-6924.2008.01065.x',
    'Risk Analysis';
is apa(title => ['short-term memory', 'we stand']),
    'Crowder, R. G. (1993). Short-term memory: Where do we stand? <i>Memory & Cognition, 21</i>(2), 142–145. doi:10.3758/BF03202725',
    'Memory & Cognition (title search, ampersand in journal title)';
is apa(year => 2000, author => ['Stanovich', 'West']),
    'Stanovich, K. E., & West, R. F. (2000). Individual differences in reasoning: Implications for the rationality debate? <i>Behavioral and Brain Sciences, 23</i>(5), 645–665. doi:10.1017/S0140525X00003435',
    'Behavioral and Brain Sciences (no ampersand)';
is apa(year => 2009, author => ['brown', 'locker']),
    'Brown, S., & Locker, E. (2009). Defensive responses to an emotive anti-alcohol message. <i>Psychology & Health, 24</i>(5), 517–528. doi:10.1080/08870440801911130',
    'Psychology & Health (extra junk between title and first <dt> on EBSCO page)';
is apa(title => ['money', 'kisses', 'shocks']),
    'Rottenstreich, Y., & Hsee, C. K. (2001). Money, kisses, and electric shocks: On the affective psychology of risk. <i>Psychological Science, 12</i>(3), 185–190. doi:10.1111/1467-9280.00334',
    'Psychological Science';
is apa(doi => '10.1177/1745691610393980'),
    q(Buhrmester, M., Kwang, T., & Gosling, S. D. (2011). Amazon's Mechanical Turk: A new source of inexpensive, yet high-quality, data? <i>Perspectives on Psychological Science, 6</i>(1), 3–5. doi:10.1177/1745691610393980),
    'Perspectives on Psychological Science (DOI search, two years in CrossRef record)';
is apa(year => 2011, title => ['yet high-quality, data?']),
    q(Buhrmester, M., Kwang, T., & Gosling, S. D. (2011). Amazon's Mechanical Turk: A new source of inexpensive, yet high-quality, data? <i>Perspectives on Psychological Science, 6</i>(1), 3–5. doi:10.1177/1745691610393980),
    'Perspectives on Psychological Science (title search containing question mark)';
is apa(year => 2009, author => ['Bruggeman', 'pick']),
    'Bruggeman, H., Piuneu, V. S., Rieser, J. J., & Pick, H. L., Jr. (2009). Biomechanical versus inertial information: Stable individual differences in perception of self-rotation. <i>Journal of Experimental Psychology: Human Perception and Performance, 35</i>(5), 1472–1480. doi:10.1037/a0015782',
    'J Exp Psych: Human Perception and Performance (author with "Jr.", MEDLINE record)';
is get(year => 2009, author => ['Bruggeman', 'pick'])->{author}[3]{suffix},
    'Jr.',
    '…suffix has a period (2)';
is apa(year => 1994, author => ['shiu', 'pashler']),
    'Shiu, L., & Pashler, H. (1994). Negligible effect of spatial precuing on identification of single digits. <i>Journal of Experimental Psychology: Human Perception and Performance, 20</i>(5), 1037–1054. doi:10.1037/0096-1523.20.5.1037',
    'J Exp Psych: Human Perception and Performance (author with hyphen followed by lowercase letter in first name)';
is apa(year => 1997, author => ['bettman', 'payne']),
    'Luce, M. F., Bettman, J. R., & Payne, J. W. (1997). Choice processing in emotionally difficult decisions. <i>Journal of Experimental Psychology: Learning, Memory, and Cognition, 23</i>(2), 384–405. doi:10.1037/0278-7393.23.2.384',
    'J Exp Psych: Learning, Memory, and Cognition (comma in journal title)';
is apa(year => 1955, author => ['Walter'], title => ['autokinetic']),
    'Walter, N. (1955). A study of the effects of conflicting suggestions upon judgments in the autokinetic situation. <i>Sociometry, 18</i>(2), 138–146. doi:10.2307/2786000',
    'Sociometry (article from 1955)';
is apa(year => 1955, author => ['asch'], title => ['pressure']),
    'Asch, S. E. (1955). Opinions and social pressure. <i>Scientific American, 193</i>(5), 31–35. doi:10.1038/scientificamerican1155-31',
    'Scientific American';
is apa(title => ['on land and underwater', 'memory']),
    'Godden, D. R., & Baddeley, A. D. (1975). Context-dependent memory in two natural environments: On land and underwater. <i>British Journal of Psychology, 66</i>(3), 325–331. doi:10.1111/j.2044-8295.1975.tb01468.x',
    'British Journal of Psychology (phrase-in-title search)';
is apa(title => ['on the psychology of drinking']),
    'Aarts, H., Dijksterhuis, A., & de Vries, P. (2001). On the psychology of drinking: Being thirsty and perceptually ready. <i>British Journal of Psychology, 92</i>(4), 631–642. doi:10.1348/000712601162383',
    'British Journal of Psychology (red-herring year and unnecessary "Pt" in MEDLINE record)';
is apa(year => 2002, author => ['Aarts', 'Dijksterhuis']),
    'Aarts, H., & Dijksterhuis, A. (2002). Category activation effects in judgment and behaviour: The moderating role of perceived comparability. <i>British Journal of Social Psychology, 41</i>(1), 123–138. doi:10.1348/014466602165090',
    'British Journal of Psychology (byline)';
is apa(year => 2010, author => ['bradley', 'byrd-craven']),
    q(Vaughn, J. E., Bradley, K. I., Byrd-Craven, J., & Kennison, S. M. (2010). The effect of mortality salience on women's judgments of male faces. <i>Evolutionary Psychology, 8</i>(3), 477–491. doi:10.1177/147470491000800313),
    'Evolutionary Psychology';
is apa(title => ['pretty women inspire']),
    'Wilson, M., & Daly, M. (2004). Do pretty women inspire men to discount the future? <i>Proceedings of the Royal Society B, 271</i>(Suppl. 4), S177–S179. doi:10.1098/rsbl.2003.0134',
    'Proceedings of the Royal Society B (article with "S" page numbers)';
is apa(year => 2008, author => ['knutson', 'greer']),
    'Knutson, B., & Greer, S. M. (2008). Anticipatory affect: Neural correlates and consequences for choice. <i>Philosophical Transactions of the Royal Society B, 363</i>(1511), 3771–3786. doi:10.1098/rstb.2008.0155',
    'Philosophical Transactions of the Royal Society B';
is apa(year => 2010, author => ['Scheibe', 'Carstensen']),
    'Scheibe, S., & Carstensen, L. L. (2010). Emotional aging: Recent findings and future trends. <i>The Journals of Gerontology, Series B: Psychological Sciences and Social Sciences, 65</i>(2), 135–144. doi:10.1093/geronb/gbp132',
      # As specified in http://www.oxfordjournals.org/our_journals/geronb/for_authors/general.html
    'Journals of Gerontology B';
is apa(year => 2003, author => ['oppenheimer'], title => ['not so fast']),
    'Oppenheimer, D. M. (2003). Not so fast! (and not so frugal!): Rethinking the recognition heuristic. <i>Cognition, 90</i>(1), B1–B9. doi:10.1016/S0010-0277(03)00141-0',
    'Cognition (article with "B" page numbers)';
is apa(year => 1987, author => ['Grassia', 'Pearson']),
    'Hammond, K. R., Hamm, R. M., Grassia, J., & Pearson, T. (1987). Direct comparison of the efficacy of intuitive and analytical cognition in expert judgment. <i>IEEE Transactions on Systems, Man, and Cybernetics, 17</i>(5), 753–770. doi:10.1109/TSMC.1987.6499282',
    'IEEE Transactions on Systems, Man, and Cybernetics';
is apa(year => 2009, author => ['Keysers', 'Gazzola'], title => ['mirror']),
    'Keysers, C., & Gazzola, V. (2009). Expanding the mirror: Vicarious activity for actions, emotions, and sensations. <i>Current Opinion in Neurobiology, 19</i>(6), 666–671. doi:10.1016/j.conb.2009.10.006',
    'Current Opinion in Neurobiology (disambiguating with a title search)';
is apa(author => ['Keysers', 'Gazzola'], title => ['unsmoothed']),
    'Gazzola, V., & Keysers, C. (2009). The observation and execution of actions share motor and somatosensory voxels in all tested subjects: Single-subject analyses of unsmoothed fMRI data. <i>Cerebral Cortex, 19</i>(6), 1239–1255. doi:10.1093/cercor/bhn181',
    'Cerebral Cortex (disambiguating with a title search)';
is apa(doi => '10.1023/A:1022456626538'),
    q{Krahé, B., Scheinberger-Olwig, R., & Bieneck, S. (2003). Men's reports of nonconsensual sexual interactions with women: Prevalence and impact. <i>Archives of Sexual Behavior, 32</i>(2), 165–175. doi:10.1023/A:1022456626538},
    'Archives of Sexual Behavior (DOI search, no title in CrossRef record)';
is apa(author => ['toates'], title => ['integrative theoretical framework']),
    'Toates, F. (2009). An integrative theoretical framework for understanding sexual motivation, arousal, and behavior. <i>Journal of Sex Research, 46</i>(2, 3), 168–193. doi:10.1080/00224490902747768',
    'Journal of Sex Research (article attributed to multiple months and multiple issues)';
is apa(year => 2007, author => ['whitaker', 'saltzman']),
    'Whitaker, D. J., Haileyesus, T., Swahn, M., & Saltzman, L. S. (2007). Differences in frequency of violence and reported injury between relationships with reciprocal and nonreciprocal intimate partner violence. <i>American Journal of Public Health, 97</i>(5), 941–947. doi:10.2105/AJPH.2005.079020',
    'American Journal of Public Health';
is get(year => 2007, author => ['whitaker', 'saltzman'])->{author}[1]{given},
    'Tadesse',
    '…first name is preserved (3)';
is apa(year => 2014, title => ['Powered versus manual toothbrushing']),
    'Yaacob, M., Worthington, H. V., Deacon, S. A., Deery, C., Walmsley, A. D., Robinson, P. G., & Glenny, A.-M. (2014). Powered versus manual toothbrushing for oral health. <i>Cochrane Database of Systematic Reviews</i>. doi:10.1002/14651858.CD002281.pub3',
    'Cochrane Database';
is apa(doi => 'doi:10.1037/0033-295X.84.3.231'),
    'Nisbett, R. E., & Wilson, T. D. (1977). Telling more than we can know: Verbal reports on mental processes. <i>Psychological Review, 84</i>(3), 231–259. doi:10.1037/0033-295X.84.3.231',
    'Psychological Review (DOI search, with "doi:", DOI in PsycINFO)';
is apa(doi => '10.1080/00224545.1979.9933632'),
    'Zak, I. (1979). Modal personality of young Jews and Arabs in Israel. <i>Journal of Social Psychology, 109</i>(1), 3–10. doi:10.1080/00224545.1979.9933632',
    'Journal of Social Psychology (DOI search, without "doi:", DOI not in PsycINFO)';
is apa(doi => '10.1007/s11238-010-9234-3'),
    'Zeisberger, S., Vrecko, D., & Langer, T. (2012). Measuring the time stability of Prospect Theory preferences. <i>Theory and Decision, 72</i>(3), 359–386. doi:10.1007/s11238-010-9234-3',
    'Theory and Decision (DOI search, multiple years in CrossRef)';
is apa(doi => '10.1037/0022-3514.58.2.308'),
    'Greenberg, J., Pyszczynski, T., Solomon, S., Rosenblatt, A., Veeder, M., Kirkland, S., & Lyon, D. (1990). Evidence for terror management theory II: The effects of mortality salience on reactions to those who threaten or bolster the cultural worldview. <i>Journal of Personality and Social Psychology, 58</i>(2), 308–318. doi:10.1037/0022-3514.58.2.308',
    'JPSP (DOI search, "et al" in CrossRef)';
is apa(title => ['toward a synthesis of cognitive biases']),
    'Hilbert, M. (2012). Toward a synthesis of cognitive biases: How noisy information processing can bias human decision making. <i>Psychological Bulletin, 138</i>(2), 211–237. doi:10.1037/a0025940',
    'Psychological Bulletin (multiple DOIs in PsycINFO record)';
is apa(title => ['false consensus effect', 'meta-analysis']),
    'Mullen, B., Atkins, J. L., Champion, D. S., Edwards, C., Hardy, D., Story, J. E., & Vanderklok, M. (1985). The false consensus effect: A meta-analysis of 115 hypothesis tests. <i>Journal of Experimental Social Psychology, 21</i>(3), 262–283. doi:10.1016/0022-1031(85)90020-4',
    'Journal of Experimental Social Psychology (only one author in PsycINFO record)';
is apa(year => 1997, author => ['landolt', 'dutton']),
    'Landolt, M. A., & Dutton, D. G. (1997). Power and personality: An analysis of gay male intimate abuse. <i>Sex Roles, 37</i>(5), 335–359. doi:10.1023/A:1025649306193';
like apa(doi => '10.1007/s11194-006-9016-1'),
    qr!\AWheeler, J. G., George, W. H., & Marlatt, G. A. \(2006\). Relapse prevention for sexual offenders: Considerations for the "abstinence violation effect"\. <i>Sexual Abuse, 18</i>\(3\), 233–248\. doi:(?:10\.1007/s11194-006-9016-1|10\.1177/107906320601800302)\z!,
      # Annoyingly, two different DOIs work.
    'Sexual Abuse (DOI search for title with double quotes in CrossRef)';
is apa(title => ['stripping sex of meaning']),
    'Goldenberg, J. L., Cox, C. R., Pyszczynski, T., Greenberg, J., & Solomon, S. (2002). Understanding human ambivalence about sex: The effects of stripping sex of meaning. <i>Journal of Sex Research, 39</i>(4), 310–320. doi:10.1080/00224490209552155',
    'Journal of Sex Research ("of" capitalized in MEDLINE)';
is apa(title => ['reconsiderations about greek']),
    'Percy, W. A., III. (2005). Reconsiderations about Greek homosexualities. <i>Journal of Homosexuality, 49</i>(3, 4), 13–61. doi:10.1300/J082v49n03_02',
    'Journal of Homosexuality (author with "III")';
is apa(title => ['clinician', 'old dogs']),
    'Carpenter, K. M., Cheng, W. Y., Smith, J. L., Brooks, A. C., Amrhein, P. C., Wain, R. M., & Nunes, E. V. (2012). "Old dogs" and new skills: How clinician characteristics relate to motivational interviewing skills before, during, and after training. <i>Journal of Consulting and Clinical Psychology, 80</i>(4), 560–573. doi:10.1037/a0028362',
    'Journal of Consulting and Clinical Psychology (author with "V" as a middle initial)';
is apa(doi => '10.1037/a0028362'),
    'Carpenter, K. M., Cheng, W. Y., Smith, J. L., Brooks, A. C., Amrhein, P. C., Wain, R. M., & Nunes, E. V. (2012). "Old dogs" and new skills: How clinician characteristics relate to motivational interviewing skills before, during, and after training. <i>Journal of Consulting and Clinical Psychology, 80</i>(4), 560–573. doi:10.1037/a0028362',
    'Journal of Consulting and Clinical Psychology (curly quotes in CrossRef title)';
is apa(title => ['trust for personalized online']),
    'Bleier, A., & Eisenbeiss, M. (2015). The importance of trust for personalized online advertising. <i>Journal of Retailing, 91</i>(3), 390–409. doi:10.1016/j.jretai.2015.04.001',
    'Journal of Retailing';
is apa(doi => '10.1111/j.1360-0443.1997.tb02916.x'),
    'McCall, M. (1997). The effects of physical attractiveness on gaining access to alcohol: When social policy meets social decision making. <i>Addiction, 92</i>(5), 597–600. doi:10.1111/j.1360-0443.1997.tb02916.x',
    'Addiction (weird byline) (1)';
is apa(title => ['adulthood functioning: the joint effects']),
    'Hill, E. M., Ross, L. T., Mudd, S. A., & Blow, F. C. (1997). Adulthood functioning: The joint effects of parental alcoholism, gender and childhood socio-economic stress. <i>Addiction, 92</i>(5), 583–596. doi:10.1111/j.1360-0443.1997.tb02915.x',
    'Addiction (weird byline) (2)';
is apa(author => ['foxcroft', 'lister-sharp'], title => ['concerns']),
    'Foxcroft, D. R., Lister-Sharp, D., & Lowe, G. (1997). Alcohol misuse prevention for young people: A systematic review reveals methodological concerns and lack of reliable evidence of effectiveness. <i>Addiction, 92</i>(5), 531–537. doi:10.1111/j.1360-0443.1997.tb02911.x',
    'Addiction (weird byline) (3)';
is apa(year => 1998, author => ['agresti', 'coull']),
    'Agresti, A., & Coull, B. A. (1998). Approximate is better than "exact" for interval estimation of binomial proportions. <i>The American Statistician, 52</i>(2), 119–126. doi:10.2307/2685469',
    'The American Statistician (backtick in given form of title)';
is apa(year => 2011, author => ['knutson'], title => ['gain', 'loss learning']),
    'Knutson, B., Samanez-Larkin, G. R., & Kuhnen, C. M. (2011). Gain and loss learning differentially contribute to life financial outcomes. <i>PLOS ONE</i>. doi:10.1371/journal.pone.0024390',
    'PLOS ONE';
is apa(doi => 'doi:10.1371/journal.pone.0047225'),
    'Peters, J., Miedl, S. F., & Büchel, C. (2012). Formal comparison of dual-parameter temporal discounting models in controls and pathological gamblers. <i>PLOS ONE</i>. doi:10.1371/journal.pone.0047225',
    'PLOS ONE (DOI search, editor in CrossRef record)';
is apa(title => ['formal comparison of dual-parameter temporal']),
    'Peters, J., Miedl, S. F., & Büchel, C. (2012). Formal comparison of dual-parameter temporal discounting models in controls and pathological gamblers. <i>PLOS ONE</i>. doi:10.1371/journal.pone.0047225',
    'PLOS ONE ("page" apparently needed for CrossRef to find record)';
is apa(year => 2010, author => ['Waterman'], title => ['promiscuous', 'squirrel']),
    'Waterman, J. M. (2010). The adaptive function of masturbation in a promiscuous African ground squirrel. <i>PLOS ONE</i>. doi:10.1371/journal.pone.0013060',
    'PLOS ONE (period instead of comma in MEDLINE record)';
is apa(year => 2007, author => ['kogler', 'Kühberger']),
    'Kogler, C., & Kühberger, A. (2007). Dual process theories: A key for understanding the diversification bias? <i>Journal of Risk and Uncertainty, 34</i>(2), 145–154. doi:10.1007/s11166-007-9008-7',
    'Journal of Risk and Uncertainty';
is apa(year => 1979, author => ['kahneman', 'tversky'], title => ['prospect']),
    'Kahneman, D., & Tversky, A. (1979). Prospect theory: An analysis of decision under risk. <i>Econometrica, 47</i>(2), 263–291. doi:10.2307/1914185',
    'Econometrica';
is apa(author => ['koop'], title => ['rank-ordered logit models']),
    'Koop, G., & Poirier, D. J. (1994). Rank-ordered logit models: An empirical analysis of Ontario voter preferences. <i>Journal of Applied Econometrics, 9</i>(4), 369–388. doi:10.1002/jae.3950090406',
    'Journal of Applied Econometrics';
is get(author => ['koop'], title => ['rank-ordered logit models'])->{author}[1]{given},
    'D. J.',
    '…periods included in initials';
is apa(year => 1979, author => ['simon'], title => ['business organizations']),
    'Simon, H. A. (1979). Rational decision making in business organizations. <i>American Economic Review, 69</i>(4), 493–513.',
    'American Economic Review';
is get(year => 1979, author => ['simon'], title => ['business organizations'])->{title},
    'Rational decision making in business organizations',
    '…trailing period not left in title (2)';
is apa(year => 1997, author => ['weber', 'milliman']),
    'Weber, E. U., & Milliman, R. A. (1997). Perceived risk attitudes: Relating risk perception to risky choice. <i>Management Science, 43</i>(2), 123–144. doi:10.1287/mnsc.43.2.123',
    'Management Science';
is apa(author => ['bertrand', 'shafir'], title => ['advertising content']),
    'Bertrand, M., Karlan, D., Mullainathan, S., Shafir, E., & Zinman, J. (2010). What\'s advertising content worth? Evidence from a consumer credit marketing field experiment. <i>Quarterly Journal of Economics, 125</i>(1), 263–306. doi:10.1162/qjec.2010.125.1.263',
    'Quarterly Journal of Economics';
is apa(year => 2010, author => ['meier', 'sprenger'], title => ['credit']),
    'Meier, S., & Sprenger, C. (2010). Present-biased preferences and credit card borrowing. <i>American Economic Journal: Applied Economics, 2</i>(1), 193–210. doi:10.1257/app.2.1.193',
    'American Economic Journal: Applied Economics';


note '~~~ Journal articles - using URLs ~~~';

is apa(url => 'http://psycnet.apa.org/psycinfo/1964-07399-001'),
    'Spence, D. P. (1964). Conscious and preconscious influences on recall: Another example of the restricting effects of awareness. <i>Journal of Abnormal and Social Psychology, 68</i>(1), 92–99. doi:10.1037/h0049342',
    'URL: PsycNET';
is apa(url => 'http://psycnet.apa.org/psycinfo/2003-99569-011'),
    'Redelmeier, D. A., Katz, J., & Kahneman, D. (2003). Memories of colonoscopy: A randomized trial. <i>Pain, 104</i>(1, 2), 187–194. doi:10.1016/S0304-3959(03)00003-4',
    'URL: PsycNET (article attributed to multiple issues)';
is apa(url => 'https://eric.ed.gov/?id=EJ108085'),
    'Skinner, B. F. (1974). Designing higher education. <i>Daedalus, 103</i>(4), 196–202.',
    'URL: ERIC';
is apa(url => 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2937254'),
    'Swihart, B. J., Caffo, B., James, B. D., Strand, M., Schwartz, B. S., & Punjabi, N. M. (2010). Lasagna plots: A saucy alternative to spaghetti plots. <i>Epidemiology, 21</i>(5), 621–625. doi:10.1097/EDE.0b013e3181e5b06a',
    'URL: PMC';
is apa(url => 'https://www.jstor.org/stable/4493343?seq=1#page_scan_tab_contents'),
    'Greene, E. S. (2005). Revising illegitimacy: The use of epithets in the Homeric hymn to Hermes. <i>Classical Quarterly, 55</i>(2), 343–349. doi:10.1093/cq/bmi036',
    'URL: JSTOR';
is apa(url => 'http://onlinelibrary.wiley.com/doi/10.1111/acer.13216/full'),
    'Fairbairn, N., Hayashi, K., Milloy, M.-J., Nolan, S., Nguyen, P., Wood, E., & Kerr, T. (2016). Hazardous alcohol use associated with increased sexual risk behaviors among people who inject drugs. <i>Alcoholism, 40</i>(11), 2394–2400. doi:10.1111/acer.13216',
    'URL: Wiley';
is apa(url => 'http://link.springer.com/article/10.1007/BF00227282'),
    'Horak, F. B., Shupert, C. L., Dietz, V., & Horstmann, G. (1994). Vestibular and somatosensory contributions to responses to head and body displacements in stance. <i>Experimental Brain Research, 100</i>(1), 93–106. doi:10.1007/BF00227282',
    'URL: SpringerLink';
is apa(url => 'http://www.sciencedirect.com/science/article/pii/S0309174016305587'),
    'Pieszka, M., Szczurek, P., Bederska-Łojewska, D., Migdał, W., Pieszka, M., Gogol, P., & Jagusiak, W. (2017). The effect of dietary supplementation with dried fruit and vegetable pomaces on production parameters and meat quality in fattening pigs. <i>Meat Science, 126</i>(Suppl. C), 1–10. doi:10.1016/j.meatsci.2016.11.016',
    'URL: ScienceDirect';
is apa(url => 'https://www.ncbi.nlm.nih.gov/pubmed/18726137'),
    'Ströhle, A. (2009). Physical activity, exercise, depression and anxiety disorders. <i>Journal of Neural Transmission, 116</i>(6), 777–784. doi:10.1007/s00702-008-0092-x',
    'URL: PubMed';
is get(url => 'https://www.ncbi.nlm.nih.gov/pubmed/30199416')->{author}[6]{family},
    'Yuval',
    'URL: PubMed (mononym, last name)';
ok !exists(get(url => 'https://www.ncbi.nlm.nih.gov/pubmed/30199416')->{author}[6]{given}),
    'URL: PubMed (mononym, first name)';
is apa(url => 'https://ideas.repec.org/a/eee/jfpoli/v37y2012i5p520-529.html'),
    'Øvrum, A., Alfnes, F., Almli, V. L., & Rickertsen, K. (2012). Health information and diet choices: Results from a cheese experiment. <i>Food Policy, 37</i>(5), 520–529. doi:10.1016/j.foodpol.2012.05.005',
    'URL: IDEAS';


note '~~~ Book chapters ~~~';

is apa(title => ['gender role journeys', 'metaphor']),
    q[O'Neil, J. M., & Egan, J. (1992). Men's and women's gender role journeys: A metaphor for healing, transition, and transformation. In B. R. Wainrib (Ed.), <i>Gender issues across the life cycle</i> (pp. 107–123). New York, NY: Springer. ISBN 978-0-8261-7680-6.],
    'Gender issues across the life cycle (one editor)';
is apa(author => ['yates', 'veinott', 'patalano']),
    'Yates, J. F., Veinott, E. S., & Patalano, A. L. (2003). Hard decisions, bad decisions: On decision quality and decision aiding. In S. L. Schneider & J. Shanteau (Eds.), <i>Emerging perspectives on judgment and decision research</i> (pp. 1–63). New York, NY: Cambridge University Press. ISBN 978-0-521-80151-5.',
    'Emerging perspectives on JDM (two editors)';
is apa(title => ['self-reflection', 'self-persuasion']),
    'Wilson, T. D. (1990). Self-persuasion via self-reflection. In J. M. Olson & M. P. Zanna (Eds.), <i>Self-inference processes: The Ontario symposium</i> (Vol. 6, pp. 43–67). Hillsdale, NJ: Lawrence Erlbaum. ISBN 978-0-8058-0551-2.',
    'Self-inference processes (multiple-volume work)';
is apa(year => 2012, title => ['relapse and relapse prevention']),
    'Hsu, S. H., & Marlatt, G. A. (2012). Addiction syndrome: Relapse and relapse prevention. In H. Shaffer, D. A. LaPlante, & S. E. Nelson (Eds.), <i>APA addiction syndrome handbook</i> (Vol. 2, pp. 105–132). Washington, DC: American Psychological Association. ISBN 978-1-4338-1105-0.',
    'APA addiction syndrome handbook (EBSCO record with volume subtitle)';
is apa(year => 2008, author => ['cosmides', 'tooby'], title => ['emotions']),
    'Tooby, J., & Cosmides, L. (2008). The evolutionary psychology of the emotions and their relationship to internal regulatory variables. In M. Lewis, J. M. Haviland-Jones, & L. F. Barrett (Eds.), <i>Handbook of emotions</i> (3rd ed., pp. 114–137). New York, NY: Guilford Press. ISBN 978-1-59385-650-2.',
    'Handbook of emotions (book with an edition number)';
is apa(year => 1992, author => ['massaro'], title => ['fuzzy']),
    'Massaro, D. W. (1992). Broadening the domain of the fuzzy logical model of perception. In H. L. Pick Jr., P. W. van den Broek, & D. C. Knill (Eds.), <i>Cognition: Conceptual and methodological issues</i> (pp. 51–84). Washington, DC: American Psychological Association. ISBN 978-1-55798-165-3.',
    'Cognition: Conceptual and methodological issues (editor with "Jr.")';


note '~~~ Entire books ~~~';

is book(year => 1956, title => ['when prophecy fails'], author => ['festinger']),
    'Festinger, L., Riecken, H. W., & Schachter, S. (1956). <i>When prophecy fails</i>. Minneapolis, MN: University of Minnesota Press. doi:10.1037/10030-000',
    'When prophecy fails';
is book(doi => '10.1037/10030-000'),
    'Festinger, L., Riecken, H. W., & Schachter, S. (1956). <i>When prophecy fails</i>. Minneapolis, MN: University of Minnesota Press. doi:10.1037/10030-000',
    'When prophecy fails (DOI search)';
is book(title => ['The dialogical alternative', 'Towards a theory']),
      # Putting the two title pieces together wouldn't work because
      # the LOC doesn't regard the title and subtitle as contiguous.
    'Wold, A. H. (Ed.). (1992). <i>The dialogical alternative: Towards a theory of language and mind</i>. Oslo, Norway: Scandinavian University Press. ISBN 978-82-00-21651-3.',
    'The dialogical alternative (one editor)';
is book(year => 1997, author => ['duncan', 'brooks-gunn'], title => ['growing up poor']),
    'Duncan, G. J., & Brooks-Gunn, J. (Eds.). (1997). <i>Consequences of growing up poor</i>. New York, NY: Russell Sage Foundation. ISBN 978-0-87154-143-7.',
    'Consequences of growing up poor (two editors)';
is book(author => ['Gilovich', 'Griffin', 'Kahneman']),
    'Gilovich, T., Griffin, D. W., & Kahneman, D. (Eds.). (2002). <i>Heuristics and biases: The psychology of intuitive judgment</i>. Cambridge, UK: Cambridge University Press. ISBN 978-0-521-79260-8. doi:10.1017/CBO9780511808098',
    'Heuristics and biases (three editors)';
is book(year => 1953, title => ['Essays in positive economics']),
    'Friedman, M. (1953). <i>Essays in positive economics</i>. Chicago: University of Chicago Press.',
    'Essays in positive economics';
is book(year => 1989, author => ['levinson'], title => ['family violence in cross-cultural']),
    'Levinson, D. (1989). <i>Family violence in cross-cultural perspective</i>. Newbury Park, CA: Sage. ISBN 978-0-8039-3075-9.',
    'Family violence in cross-cultural perspective';
is book(year => 1984, author => ['Brownmiller'], title => ['Femininity']),
    'Brownmiller, S. (1984). <i>Femininity</i>. New York, NY: Simon & Schuster. ISBN 978-0-671-24692-1.',
    'Femininity';
is book(year => 2009, author => ['stearns'], title => ['sexuality']),
    'Stearns, P. N. (2009). <i>Sexuality in world history</i>. London, UK: Routledge. ISBN 978-0-415-77776-6.',
    'Sexuality in world history';
is book(year => 2010, author => ['thorndike-christ'], title => ['measurement']),
    'Thorndike, R. M., & Thorndike-Christ, T. (2010). <i>Measurement and evaluation in psychology and education</i> (8th ed.). Boston, MA: Prentice Hall. ISBN 978-0-13-240397-9.',
    'Measurement and evaluation in psychology and education';
is book(year => 1988, title => ['Statistical Power Analysis for the Behavioral']),
    'Cohen, J. (1988). <i>Statistical power analysis for the behavioral sciences</i> (2nd ed.). Hillsdale, NJ: L. Erlbaum. ISBN 978-0-8058-0283-2.',
    'Statistical power analysis for the behavioral sciences';
is get(book => 1, year => 1988, title => ['Statistical Power Analysis for the Behavioral'])->{edition},
    '2nd',
    q{…edition doesn't have "ed." or spaces};
is book(year => 2010, author => ['aronson', 'wilson', 'akert']),
    'Aronson, E., Wilson, T. D., & Akert, R. M. (2010). <i>Social psychology</i> (7th ed.). Upper Saddle River, NJ: Prentice Hall. ISBN 978-0-13-814478-4.',
    'Social psychology';
is book(year => 2008, title => ['nudge'], author => ['thaler', 'sunstein']),
    'Thaler, R. H., & Sunstein, C. R. (2008). <i>Nudge: Improving decisions about health, wealth, and happiness</i>. New Haven, CT: Yale University Press. ISBN 978-0-300-12223-7.',
    'Nudge';
is book(year => 2009, author => ['hastie', 'friedman']),
    'Hastie, T., Tibshirani, R., & Friedman, J. H. (2009). <i>The elements of statistical learning: Data mining, inference, and prediction</i> (2nd ed.). New York, NY: Springer. ISBN 978-0-387-84857-0.',
    'The elements of statistical learning';
is book(year => 2000, title => ['programming perl']),
    q(Wall, L., Christiansen, T., & Orwant, J. (2000). <i>Programming Perl</i> (3rd ed.). Beijing, PRC: O'Reilly. ISBN 978-0-596-00027-1.),
    'Programming Perl';
is book(year => 2000, author => ['carothers'], title => ['analysis']),
    'Carothers, N. L. (2000). <i>Real analysis</i>. Cambridge, UK: Cambridge University Press. ISBN 978-0-521-49749-7. doi:10.1017/CBO9780511814228',
    'Real analysis';
is book(isbn => '978-0-521-49749-7'),
    'Carothers, N. L. (2000). <i>Real analysis</i>. Cambridge, UK: Cambridge University Press. ISBN 978-0-521-49749-7. doi:10.1017/CBO9780511814228',
    'Real analysis (ISBN search)';
is book(year => 2005, title => [q(student's introduction to english)]),
    q(Huddleston, R. D., & Pullum, G. K. (2005). <i>A student's introduction to English grammar</i>. Cambridge, UK: Cambridge University Press. ISBN 978-0-521-84837-4. doi:10.1017/CBO9780511815515),
    q[A student's introduction to English grammar (title search with single quote)];
is book(year => 2002, author => ['Schechter'], title => ['functional', 'principles']),
    'Schechter, M. (2002). <i>Principles of functional analysis</i> (2nd ed.). Providence, RI: American Mathematical Society. ISBN 978-0-8218-2895-3.',
    'Principles of functional analysis';
is book(isbn => '8200216519'),
    'Wold, A. H. (Ed.). (1992). <i>The dialogical alternative: Towards a theory of language and mind</i>. Oslo, Norway: Scandinavian University Press. ISBN 978-82-00-21651-3.',
    'The dialogical alternative (search by ISBN-10, pre-2007)';
is book(isbn => '978-82-00-21651-3'),
    'Wold, A. H. (Ed.). (1992). <i>The dialogical alternative: Towards a theory of language and mind</i>. Oslo, Norway: Scandinavian University Press. ISBN 978-82-00-21651-3.',
    'The dialogical alternative (search by ISBN-13, pre-2007)';
is book(isbn => '978-1-4338-0407-6'),
    'Wenzel, A., Brown, G. K., & Beck, A. T. (2009). <i>Cognitive therapy for suicidal patients: Scientific and clinical applications</i> (1st ed.). Washington, DC: American Psychological Association. ISBN 978-1-4338-0407-6. doi:10.1037/11862-000',
    'Cognitive therapy for suicidal patients (search by ISBN-13, post-2007)';
is book(isbn => '1433804077'),
    'Wenzel, A., Brown, G. K., & Beck, A. T. (2009). <i>Cognitive therapy for suicidal patients: Scientific and clinical applications</i> (1st ed.). Washington, DC: American Psychological Association. ISBN 978-1-4338-0407-6. doi:10.1037/11862-000',
    'Cognitive therapy for suicidal patients (search by ISBN-10, post-2007)';


note '~~~ arXiv manuscripts ~~~';

is apa(arxiv_id => '1504.00641'),
    'Patel, A. B., Nguyen, T., & Baraniuk, R. G. (2015). <i>A probabilistic theory of deep learning</i>. Retrieved from http://arxiv.org/abs/1504.00641',
    'A probabilistic theory of deep learning';


done_testing;
