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
   {$qb->bib1(get(@_),
        style_path => $ENV{APA_CSL_PATH} ||
            die('The environment variable APA_CSL_PATH is not set'),
        apa_tweaks => 1,
        always_include_issue => 1, include_isbn => 1)}

note '~~~ Journal articles (EBSCO) ~~~';

is apa(year => 1991, author => ['smith', 'dechter']),
    'Smith, H. L., & Dechter, A. (1991). No shift in locus of control among women during the 1970s. <i>Journal of Personality and Social Psychology, 60</i>(4), 638–640. doi:10.1037/0022-3514.60.4.638',
    'JPSP';
is apa(year => 1967, author => ['valins', 'ray']),
    'Valins, S., & Ray, A. A. (1967). Effects of cognitive desensitization on avoidance behavior. <i>Journal of Personality and Social Psychology, 7</i>(4, Pt. 1), 345–350. doi:10.1037/h0025239',
    'JPSP (old article)';
is apa(year => 2005, author => [qw(Bechara Damasio Tranel)]),
    'Bechara, A., Damasio, H., Tranel, D., & Damasio, A. R. (2005). The Iowa Gambling Task and the somatic marker hypothesis: Some questions and answers. <i>Trends in Cognitive Sciences, 9</i>(4), 159–162. doi:10.1016/j.tics.2005.02.002',
    'Trends in Cognitive Sciences';
is apa(year => 2004, author => ['maia', 'McClelland']),
    'Maia, T. V., & McClelland, J. L. (2004). A reexamination of the evidence for the somatic marker hypothesis: What participants really know in the Iowa gambling task. <i>Proceedings of the National Academy of Sciences, 101</i>(45), 16075–16080. doi:10.1073/pnas.0406666101',
    'PNAS';
is apa(year => 1997, author => ['Wallen', 'Tannenbaum']),
    'Wallen, K., & Tannenbaum, P. L. (1997). Hormonal modulation of sexual behavior and affiliation in rhesus monkeys. <i>Annals of the New York Academy of Sciences, 807</i>, 185–202. doi:10.1111/j.1749-6632.1997.tb51920.x',
    'Annals of the NYAS';
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
is apa(year => 2010, author => ['trope', 'liberman'], title => ['construal-level theory']),
    'Trope, Y., & Liberman, N. (2010). Construal-level theory of psychological distance. <i>Psychological Review, 117</i>(2), 440–463. doi:10.1037/a0018963',
    'Psychological Review (article for which a correction exists)';
is apa(year => 1994, title => ['earth is round']),
    'Cohen, J. (1994). The earth is round (p < .05). <i>American Psychologist, 49</i>(12), 997–1003. doi:10.1037/0003-066X.49.12.997',
    'American Psychologist ("<" in article title)';
is apa(title => ['alleged sex research']),
    'Benjamin, L. T., Jr., Whitaker, J. L., Ramsey, R. M., & Zeve, D. R. (2007). John B. Watson\'s alleged sex research: An appraisal of the evidence. <i>American Psychologist, 62</i>(2), 131–139. doi:10.1037/0003-066X.62.2.131',
    'American Psychologist (miscapitalized title with middle initial)';
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
TODO:
   {local $TODO = 'The ending page number in PsycINFO is currently 1225 rather than the correct 1226';
    is apa(year => 2009, author => [qw(Chapman Kim Susskind Anderson)]),
        'Chapman, H. A., Kim, D. A., Susskind, J. M., & Anderson, A. K. (2009). In bad taste: Evidence for the oral origins of moral disgust. <i>Science, 323</i>(5918), 1222–1226. doi:10.1126/science.1165565',
        'Science';}
is apa(author => ['lee', 'schwarz'], title => ['washing']),
    'Lee, S. W., & Schwarz, N. (2010). Washing away postdecisional dissonance. <i>Science, 328</i>(5979), 709. doi:10.1126/science.1186799',
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
    'Levin, I. P., Weller, J. A., Pederson, A. A., & Harshman, L. A. (2007). Age-related differences in adaptive decision making: Sensitivity to expected value in risky choice. <i>Judgment and Decision Making, 2</i>(4), 225–233. Retrieved from http://journal.sjdm.org/7404/jdm7404.htm',
    'Judgment and Decision Making';
is apa(title => ['short-term memory', 'we stand']),
    'Crowder, R. G. (1993). Short-term memory: Where do we stand? <i>Memory & Cognition, 21</i>(2), 142–145. doi:10.3758/BF03202725',
    'Memory & Cognition (title search, ampersand in journal title)';
TODO:
   {local $TODO = 'The ending page number in PsycINFO is currently 726 rather than the correct 665';
    is apa(year => 2000, author => ['Stanovich', 'West']),
        'Stanovich, K. E., & West, R. F. (2000). Individual differences in reasoning: Implications for the rationality debate? <i>Behavioral and Brain Sciences, 23</i>(5), 645–665. doi:10.1017/S0140525X00003435',
        'Behavioral and Brain Sciences (no ampersand)';}
is apa(year => 2009, author => ['brown', 'locker']),
    'Brown, S., & Locker, E. (2009). Defensive responses to an emotive anti-alcohol message. <i>Psychology & Health, 24</i>(5), 517–528. doi:10.1080/08870440801911130',
    'Psychology & Health (extra junk between title and first <dt> on EBSCO page)';
is apa(title => ['money', 'kisses', 'shocks']),
    'Rottenstreich, Y., & Hsee, C. K. (2001). Money, kisses, and electric shocks: On the affective psychology of risk. <i>Psychological Science, 12</i>(3), 185–190. doi:10.1111/1467-9280.00334',
    'Psychological Science';
is apa(doi => '10.1177/1745691610393980'),
    q(Buhrmester, M., Kwang, T., & Gosling, S. D. (2011). Amazon's Mechanical Turk: A new source of inexpensive, yet high-quality, data? <i>Perspectives on Psychological Science, 6</i>(1), 3–5. doi:10.1177/1745691610393980),
    'Perspectives on Psychological Science (DOI search, two years in CrossRef record)';
is apa(title => ['yet high-quality, data?']),
    q(Buhrmester, M., Kwang, T., & Gosling, S. D. (2011). Amazon's Mechanical Turk: A new source of inexpensive, yet high-quality, data? <i>Perspectives on Psychological Science, 6</i>(1), 3–5. doi:10.1177/1745691610393980),
    'Perspectives on Psychological Science (title search containing question mark)';
is apa(year => 2009, author => ['Bruggeman', 'pick']),
    'Bruggeman, H., Piuneu, V. S., Rieser, J. J., & Pick, H. L., Jr. (2009). Biomechanical versus inertial information: Stable individual differences in perception of self-rotation. <i>Journal of Experimental Psychology: Human Perception and Performance, 35</i>(5), 1472–1480. doi:10.1037/a0015782',
    'J Exp Psych: Human Perception and Performance (author with "Jr.")';
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
    'Aarts, H., Dijksterhuis, A., & De Vries, P. (2001). On the psychology of drinking: Being thirsty and perceptually ready. <i>British Journal of Psychology, 92</i>(4), 631–642. doi:10.1348/000712601162383',
    'British Journal of Psychology (red-herring year and unnecessary "Pt" in MEDLINE record)';
is apa(title => ['pretty women inspire']),
    'Wilson, M., & Daly, M. (2004). Do pretty women inspire men to discount the future? <i>Proceedings of the Royal Society B, 271</i>(Suppl. 4), S177–S179. doi:10.1098/rsbl.2003.0134',
    'Proceedings of the Royal Society B (article with "S" page numbers)';
is apa(year => 2008, author => ['knutson', 'greer']),
    'Knutson, B., & Greer, S. M. (2008). Anticipatory affect: Neural correlates and consequences for choice. <i>Philosophical Transactions of the Royal Society B, 363</i>(1511), 3771–3786. doi:10.1098/rstb.2008.0155',
    'Philosophical Transactions of the Royal Society B';
is apa(year => 2003, author => ['oppenheimer'], title => ['not so fast']),
    'Oppenheimer, D. M. (2003). Not so fast! (and not so frugal!): Rethinking the recognition heuristic. <i>Cognition, 90</i>(1), B1–B9. doi:10.1016/S0010-0277(03)00141-0',
    'Cognition (article with "B" page numbers)';
is apa(year => 1987, author => ['Grassia', 'Pearson']),
    'Hammond, K. R., Hamm, R. M., Grassia, J., & Pearson, T. (1987). Direct comparison of the efficacy of intuitive and analytical cognition in expert judgment. <i>IEEE Transactions on Systems, Man, and Cybernetics, 17</i>(5), 753–770.',
    'IEEE Transactions on Systems, Man, and Cybernetics';
is apa(year => 2009, author => ['Keysers', 'Gazzola'], title => ['mirror']),
    'Keysers, C., & Gazzola, V. (2009). Expanding the mirror: Vicarious activity for actions, emotions, and sensations. <i>Current Opinion in Neurobiology, 19</i>(6), 666–671. doi:10.1016/j.conb.2009.10.006',
    'Current Opinion in Neurobiology (disambiguating with a title search)';
is apa(year => 2009, author => ['Keysers', 'Gazzola'], title => ['unsmoothed']),
    'Gazzola, V., & Keysers, C. (2009). The observation and execution of actions share motor and somatosensory voxels in all tested subjects: Single-subject analyses of unsmoothed fMRI data. <i>Cerebral Cortex, 19</i>(6), 1239–1255. doi:10.1093/cercor/bhn181',
    'Cerebral Cortex (disambiguating with a title search)';
is apa(author => ['redelmeier', 'kahneman'], title => ['colonoscopy']),
    'Redelmeier, D. A., Katz, J., & Kahneman, D. (2003). Memories of colonoscopy: A randomized trial. <i>Pain, 104</i>(1, 2), 187–194. doi:10.1016/S0304-3959(03)00003-4',
    'Pain (article attributed to multiple issues)';
is apa(year => 2007, author => ['whitaker', 'saltzman']),
    'Whitaker, D. J., Saltzman, L. S., Haileyesus, T., & Swahn, M. (2007). Differences in frequency of violence and reported injury between relationships with reciprocal and nonreciprocal intimate partner violence. <i>American Journal of Public Health, 97</i>(5), 941–947. doi:10.2105/AJPH.2005.079020',
    'American Journal of Public Health';
is get(year => 2007, author => ['whitaker', 'saltzman'])->{author}[0]{given},
    'Daniel J.',
    '…first name and middle initial are preserved';
is get(year => 2007, author => ['whitaker', 'saltzman'])->{author}[-1]{given},
    'Monica',
    '…first name is preserved (3)';
is apa(doi => 'doi:10.1037/0033-295X.84.3.231'),
    'Nisbett, R. E., & Wilson, T. D. (1977). Telling more than we can know: Verbal reports on mental processes. <i>Psychological Review, 84</i>(3), 231–259. doi:10.1037/0033-295X.84.3.231',
    'Psychological Review (DOI search, with "doi:", DOI in PsycINFO)'; 
is apa(doi => '10.1080/00224545.1979.9933632'),
    'Zak, I. (1979). Modal personality of young Jews and Arabs in Israel. <i>Journal of Social Psychology, 109</i>(1), 3–10. doi:10.1080/00224545.1979.9933632',
    'Journal of Social Psychology (DOI search, without "doi:", DOI not in PsycINFO)';
is apa(doi => '10.1007/s11238-010-9234-3'),
    'Zeisberger, S., Vrecko, D., & Langer, T. (2012). Measuring the time stability of prospect theory preferences. <i>Theory and Decision, 72</i>(3), 359–386. doi:10.1007/s11238-010-9234-3',
    'Theory and Decision (DOI search, multiple years in CrossRef)';
is apa(title => ['toward a synthesis of cognitive biases']),
    'Hilbert, M. (2012). Toward a synthesis of cognitive biases: How noisy information processing can bias human decision making. <i>Psychological Bulletin, 138</i>(2), 211–237. doi:10.1037/a0025940',
    'Psychological Bulletin (multiple DOIs in PsycINFO record)';
is apa(title => ['happiness makes us selfish']),
    'Tan, H. B., & Forgas, J. P. (2010). When happiness makes us selfish, but sadness makes us fair: Affective influences on interpersonal strategies in the dictator game. <i>Journal of Experimental Social Psychology, 46</i>(3), 571–576. doi:10.1016/j.jesp.2010.01.007',
    'Journal of Experimental Social Psychology (impoverished PsycINFO record)';
is apa(year => 1997, author => ['landolt', 'dutton']),
    'Landolt, M. A., & Dutton, D. G. (1997). Power and personality: An analysis of gay male intimate abuse. <i>Sex Roles, 37</i>(5, 6), 335–359. doi:10.1023/A:1025649306193',
    'Sex Roles (article attributed to multiple issues)';
is apa(year => 2006, author => ['wheeler', 'george', 'marlatt']),
    'Wheeler, J. G., George, W. H., & Marlatt, G. A. (2006). Relapse prevention for sexual offenders: Considerations for the "abstinence violation effect". <i>Sexual Abuse, 18</i>(3), 233–248. doi:10.1177/107906320601800302',
    'Sexual Abuse (single quotes in given form of title)';
is apa(doi => '10.1177/107906320601800302'),
    'Wheeler, J. G., George, W. H., & Marlatt, G. A. (2006). Relapse prevention for sexual offenders: Considerations for the "abstinence violation effect". <i>Sexual Abuse, 18</i>(3), 233–248. doi:10.1177/107906320601800302',
    'Sexual Abuse (DOI search for title with double quotes in CrossRef)';
is apa(title => ['hormones and history'], author => ['zehr']),
    'Wallen, K., & Zehr, J. L. (2004). Hormones and history: The evolution and development of primate female sexuality. <i>Journal of Sex Research, 41</i>(1), 101–112. doi:10.1080/00224490409552218',
    'Journal of Sex Research';
is apa(title => ['reconsiderations about greek']),
    'Percy, W. A., III. (2005). Reconsiderations about Greek homosexualities. <i>Journal of Homosexuality, 49</i>(3, 4), 13–61. doi:10.1300/J082v49n03_02',
    'Journal of Homosexuality (author with "III")';
is apa(year => 1997, author => ['holdershaw', 'gendall']),
    'Holdershaw, J., Gendall, P., & Garland, R. (1997). The widespread use of odd pricing in the retail sector. <i>Marketing Bulletin, 8</i>, 53–58.',
    'Marketing Bulletin (last author missing from EBSCO record)';
  # I believe this journal has no issue numbers.
is apa(year => 1999, author => ['bone', 'ellen']),
    'Bone, P. F., & Ellen, P. S. (1999). Scents in the marketplace: Explaining a fraction of olfaction. <i>Journal of Retailing, 75</i>(2), 243–262. doi:10.1016/S0022-4359(99)00007-X',
    'Journal of Retailing (difficult-to-interpret byline in text)';
is apa(doi => '10.1111/j.1360-0443.1997.tb02916.x'),
    'McCall, M. (1997). The effects of physical attractiveness on gaining access to alcohol: When social policy meets social decision making. <i>Addiction, 92</i>(5), 597–600. doi:10.1111/j.1360-0443.1997.tb02916.x',
    'Addiction (weird byline) (1)';
is apa(title => ['adulthood functioning: the joint effects']),
    'Hill, E. M., Thomson Ross, L., Mudd, S. A., & Blow, F. C. (1997). Adulthood functioning: The joint effects of parental alcoholism, gender and childhood socio-economic stress. <i>Addiction, 92</i>(5), 583–596. doi:10.1111/j.1360-0443.1997.tb02915.x',
    'Addiction (weird byline) (2)';
is apa(author => ['foxcroft', 'lister-sharp'], title => ['concerns']),
    'Foxcroft, D. R., Lister-Sharp, D., & Lowe, G. (1997). Alcohol misuse prevention for young people: A systematic review reveals methodological concerns and lack of reliable evidence of effectiveness. <i>Addiction, 92</i>(5), 531–537. doi:10.1111/j.1360-0443.1997.tb02911.x',
    'Addiction (weird byline) (3)';
is apa(year => 1998, author => ['agresti', 'coull']),
    'Agresti, A., & Coull, B. A. (1998). Approximate is better than "exact" for interval estimation of binomial proportions. <i>The American Statistician, 52</i>(2), 119–126. doi:10.2307/2685469',
    'The American Statistician (backtick in given form of title)';
is apa(year => 2011, author => ['knutson'], title => ['gain', 'loss learning']),
    'Knutson, B., Samanez-Larkin, G. R., & Kuhnen, C. M. (2011). Gain and loss learning differentially contribute to life financial outcomes. <i>PLoS ONE</i>. doi:10.1371/journal.pone.0024390',
    'PLoS ONE';


note '~~~ Journal articles (IDEAS) ~~~';

is apa(year => 2007, author => ['kogler', 'Kühberger']),
    'Kogler, C., & Kühberger, A. (2007). Dual process theories: A key for understanding the diversification bias? <i>Journal of Risk and Uncertainty, 34</i>(2), 145–154. doi:10.1007/s11166-007-9008-7',
    'Journal of Risk and Uncertainty';
is apa(year => 1979, author => ['kahneman', 'tversky'], title => ['prospect']),
    'Kahneman, D., & Tversky, A. (1979). Prospect theory: An analysis of decision under risk. <i>Econometrica, 47</i>(2), 263–291. doi:10.2307/1914185',
    'Econometrica';
is apa(year => 1979, author => ['simon'], title => ['business organizations']),
    'Simon, H. A. (1979). Rational decision making in business organizations. <i>American Economic Review, 69</i>(4), 493–513.',
    'American Economic Review';
is get(year => 1979, author => ['simon'], title => ['business organizations'])->{title},
    'Rational decision making in business organizations',
    '…trailing period not left in title (2)';
is apa(year => 2002, author => ['Bosch-Domènech', 'Montalvo']),
    'Bosch-Domènech, A., Montalvo, J. G., Nagel, R., & Satorra, A. (2002). One, two, (three), infinity, …: Newspaper and lab beauty-contest experiments. <i>American Economic Review, 92</i>(5), 1687–1701. doi:10.1257/000282802762024737',
    'American Economic Review (surname with a diacritic and title with parentheses)';
is apa(year => 1997, author => ['weber', 'milliman']),
    'Weber, E. U., & Milliman, R. A. (1997). Perceived risk attitudes: Relating risk perception to risky choice. <i>Management Science, 43</i>(2), 123–144. doi:10.1287/mnsc.43.2.123',
    'Management Science';
is apa(author => ['bertrand', 'shafir'], title => ['advertising content']),
    'Bertrand, M., Karlan, D. S., Mullainathan, S., Shafir, E., & Zinman, J. (2010). What\'s advertising content worth? Evidence from a consumer credit marketing field experiment. <i>Quarterly Journal of Economics, 125</i>(1), 263–305. doi:10.1162/qjec.2010.125.1.263',
    'Quarterly Journal of Economics';


note '~~~ Book chapters ~~~';

is apa(title => ['gender role journeys', 'metaphor']),
    q[O'Neil, J. M., & Egan, J. (1992). Men's and women's gender role journeys: A metaphor for healing, transition, and transformation. In B. R. Wainrib (Ed.), <i>Gender issues across the life cycle</i> (pp. 107–123). New York, NY: Springer. ISBN 0-8261-7680-1.],
    'Gender issues across the life cycle (one editor)';
is apa(author => ['yates', 'veinott', 'patalano']),
    'Yates, J. F., Veinott, E. S., & Patalano, A. L. (2003). Hard decisions, bad decisions: On decision quality and decision aiding. In S. L. Schneider & J. Shanteau (Eds.), <i>Emerging perspectives on judgment and decision research</i> (pp. 1–63). New York, NY: Cambridge University Press. ISBN 0-521-80151-6.',
    'Emerging perspectives on JDM (two editors)';
is apa(title => ['self-reflection', 'self-persuasion']),
    'Wilson, T. D. (1990). Self-persuasion via self-reflection. In J. M. Olson & M. P. Zanna (Eds.), <i>Self-inference processes: The Ontario symposium</i> (Vol. 6, pp. 43–67). Hillsdale, NJ: Lawrence Erlbaum. ISBN 0-8058-0551-6.',
    'Self-inference processes (multiple-volume work)';
is apa(year => 2008, author => ['cosmides', 'tooby'], title => ['emotions']),
    'Tooby, J., & Cosmides, L. (2008). The evolutionary psychology of the emotions and their relationship to internal regulatory variables. In M. Lewis, J. M. Haviland-Jones, & L. F. Barrett (Eds.), <i>Handbook of emotions</i> (3rd ed., pp. 114–137). New York, NY: Guilford Press. ISBN 1-59385-650-4.',
    'Handbook of emotions (book with an edition number)';
is apa(year => 1992, author => ['massaro'], title => ['fuzzy']),
    'Massaro, D. W. (1992). Broadening the domain of the fuzzy logical model of perception. In H. L. Pick Jr., P. W. van den Broek, & D. C. Knill (Eds.), <i>Cognition: Conceptual and methodological issues</i> (pp. 51–84). Washington, DC: American Psychological Association. ISBN 1-55798-165-5.',
    'Cognition: Conceptual and methodological issues (editor with "Jr.")';


=for wholebooks

note '~~~ Entire books ~~~';

is apa(title => ['when prophecy fails'], author => ['festinger']),
    'Festinger, L., Henry, W., & Schachter, S. (1956). <i>When prophecy fails</i>. Minneapolis, MN: University of Minnesota Press.',
    'When prophecy fails (authors)';
is apa(title => ['gender issues', 'life cycle']),
    'Wainrib, B. R. (Ed.). (1992). <i>Gender issues across the life cycle</i>. New York, NY: Springer',
    'Gender issues across the life cycle (one editor)';
is apa(year => 1997, author => ['duncan', 'brooks-gunn'], title => ['consequences']),
    'Duncan, G. J., & Brooks-Gunn, J. (Eds.). (1997). Consequences of growing up poor. New York, NY: Russell Sage Foundation.',
    'Consequences of growing up poor (two editors)';
is apa(year => 2010, author => ['thorndike', 'thorndike-christ']),
    'Thorndike, R. M., & Thorndike-Chirst, T. (2010). <i>Measurement and evaluation in psychology and education</i> (8th ed.). Boston: Prentice Hall.',
    'Measurement and evaluation in psychology and education';
is apa(year => 2010, author => ['aronson', 'wilson', 'akert']),
    'Aronson, E., Wilson, T. D., & Akert, R. M. (2010). <i>Social psychology</i> (7th ed.). Upper Saddle River, NJ: Pearson Education.',
    'Social psychology';

=cut



done_testing;
