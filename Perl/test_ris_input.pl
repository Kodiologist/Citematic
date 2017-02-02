#!/usr/bin/perl

use utf8;
use warnings;
use strict;
use Citematic::Get 'digest_ris';
use Citematic::QuickBib;
use Test::More;

my $qb = new Citematic::QuickBib;

sub apa
   {my $ris = @_ == 2
      ? do {local $_ = $_[1]; $_[0]->(); $_}
      : $_[0];
    $ris =~ s/^ +//mg;
    my $x = digest_ris($ris);
    defined $x or return undef;
    $qb->bib1($x,
        style_path => $ENV{APA_CSL_PATH} ||
            die('The environment variable APA_CSL_PATH is not set'),
        apa_tweaks => 1,
        always_include_issue => 1, include_isbn => 1,
        url_after_doi => 1)}

# Elsevier
# http://www.sciencedirect.com/science/article/pii/S0143622801000091
is apa(
       "TY  - JOUR
        T1  - Should flood insurance be mandatory? Insights in the wake of the 1997 New Year’s Day flood in Reno–Sparks, Nevada
        JO  - Applied Geography
        VL  - 21
        IS  - 3
        SP  - 199
        EP  - 221
        PY  - 2001/7//
        T2  -\x20
        AU  - Blanchard-Boehm, R.D
        AU  - Berry, K.A
        AU  - Showalter, P.S
        SN  - 0143-6228
        DO  - http://dx.doi.org/10.1016/S0143-6228(01)00009-1
        UR  - http://www.sciencedirect.com/science/article/pii/S0143622801000091
        KW  - Flood insurance decision
        KW  - Flood mitigation
        KW  - Flood hazard
        KW  - National Flood Insurance Program
        KW  - Risk perception
        KW  - Vulnerability
        ER  - "),
    q(Blanchard-Boehm, R. D., Berry, K. A., & Showalter, P. S. (2001). Should flood insurance be mandatory? Insights in the wake of the 1997 New Year's Day flood in Reno–Sparks, Nevada. <i>Applied Geography, 21</i>(3), 199–221. doi:10.1016/S0143-6228(01)00009-1),
    'Elseiver: Applied Geography';

# Wiley
# http://link.springer.com/article/10.1007%2FBF02736122
is apa(
       'TY  - JOUR
        PY  - 2005
        J2  - Computational Statistics
        SN  - 0943-4062
        T2  - Computational Statistics
        VL  - 20
        IS  - 1
        DO  - 10.1007/BF02736122
        TI  - Fast algorithms for the calculation of Kendall’s τ
        UR  - http://dx.doi.org/10.1007/BF02736122
        PB  - Springer-Verlag
        DA  - 2005/03/01
        KW  - Kendall’s Tau
        KW  - Algorithm
        KW  - O(n log n)
        AU  - Christensen, David
        SP  - 51-62
        LA  - English
        ER  - '),
    q(Christensen, D. (2005). Fast algorithms for the calculation of Kendall's τ. <i>Computational Statistics, 20</i>(1), 51–62. doi:10.1007/BF02736122),
    'Wiley: Computational Statistics';

# Sage
# http://ann.sagepub.com/content/26/2/224
is apa(
       "TY  - JOUR
        A1  - Crosby, Everett U.
        T1  - Fire Prevention
        Y1  - 1905/09/01\x20
        JF  - The ANNALS of the American Academy of Political and Social Science\x20
        JO  - The ANNALS of the American Academy of Political and Social Science\x20
        SP  - 224\x20
        EP  - 238\x20
        M3  - 10.1177/000271620502600215\x20
        VL  - 26\x20
        IS  - 2\x20
        UR  - http://ann.sagepub.com/content/26/2/224.short\x20
        ER  -\n\n"),
    'Crosby, E. U. (1905). Fire prevention. <i>The ANNALS of the American Academy of Political and Social Science, 26</i>(2), 224–238. doi:10.1177/000271620502600215',
    'Sage: ANNALS Am Academy Polit Soc Science';

# IEEE Xplore
# http://ieeexplore.ieee.org/xpl/articleDetails.jsp?arnumber=777375
is apa(
       "TY  - JOUR
        \x0dJO  - Pattern Analysis and Machine Intelligence, IEEE Transactions on\x0d
        TI  - Lower bounds for Bayes error estimation\x0d
        T2  - Pattern Analysis and Machine Intelligence, IEEE Transactions on\x0d
        IS  - 7\x0d
        SN  - 0162-8828\x0d
        VO  - 21\x0d
        SP  - 643\x0d
        EP  - 645\x0d
        AU  - Antos, A.\x0d
        AU  - Devroye, L.\x0d
        AU  - Gyorfi, L.\x0d
        Y1  - Jul 1999\x0d
        PY  - 1999\x0d
        KW  - Bayes methods\x0d
        KW  - convergence of numerical methods\x0d
        KW  - error analysis\x0d
        KW  - estimation theory\x0d
        KW  - pattern recognition\x0d
        KW  - statistical analysis\x0d
        KW  - Bayes error estimation\x0d
        KW  - convergence\x0d
        KW  - discrimination\x0d
        KW  - lower bounds\x0d
        KW  - nonparametric estimation\x0d
        KW  - statistical pattern recognition\x0d
        KW  - Convergence\x0d
        KW  - Error analysis\x0d
        KW  - Error probability\x0d
        KW  - Estimation error\x0d
        KW  - Pattern recognition\x0d
        KW  - Radiofrequency interference\x0d
        VL  - 21\x0d
        JA  - Pattern Analysis and Machine Intelligence, IEEE Transactions on\x0d
        DO  - 10.1109/34.777375\x0d
        ER  - \x0d\n\n\x0d\x0d"),
    'Antos, A., Devroye, L., & Gyorfi, L. (1999). Lower bounds for Bayes error estimation. <i>IEEE Transactions on Pattern Analysis and Machine Intelligence, 21</i>(7), 643–645. doi:10.1109/34.777375',
    'IEEE Transactions Pat Anal Machine Intel';

# JSTOR
# http://www.jstor.org/stable/3773639
is apa(
       "Provider: JSTOR http://www.jstor.org
        Database: JSTOR
        Content: text/plain; charset=\"us-ascii\"


        TY  - JOUR
        TI  - Is Rape a Cultural Universal? A Re-examination of the Ethnographic Data
        AU  - Palmer, Craig
        C1  - Full publication date: Jan., 1989
        DO  - 10.2307/3773639
        EP  - 16
        IS  - 1
        PB  - University of Pittsburgh- Of the Commonwealth System of Higher Education
        PY  - 1989
        SN  - 00141828
        SP  - 1
        T2  - Ethnology
        UR  - http://www.jstor.org/stable/3773639
        VL  - 28
        ER  - "),
    'Palmer, C. (1989). Is rape a cultural universal? A re-examination of the ethnographic data. <i>Ethnology, 28</i>(1), 1–16. doi:10.2307/3773639',
    'JSTOR: Ethnography';

# Cambridge
# http://journals.cambridge.org/action/displayAbstract?aid=6734712
is apa(
       "TY  - JOUR
        AU  - Buss,David M.
        PY  - 1989
        TI  - Sex differences in human mate preferences: Evolutionary hypotheses tested in 37 cultures
        JF  - Behavioral and Brain Sciences
        KW  - assortative mating, cultural differences, evolution, mate preferences, reproductive strategy, sex differences, sexual selection, sociobiology
        SP  - 1
        EP  - 14
        VL  - 12
        IS  - 01
        M3  - 10.1017/S0140525X00023992
        ER  - \n"),
    'Buss, D. M. (1989). Sex differences in human mate preferences: Evolutionary hypotheses tested in 37 cultures. <i>Behavioral and Brain Sciences, 12</i>(1), 1–14. doi:10.1017/S0140525X00023992',
    'Cambridge: BBS';

# Project Euclid
# http://projecteuclid.org/euclid.ss/1294167961
is apa(sub {s/Statist\. Sci\./Statistical Science/},
       "TY  - JOUR
        AB  - Statistical modeling is a powerful tool for developing and testing 
              theories by way of causal explanation, prediction, and description. In
              many disciplines there is near-exclusive use of statistical modeling 
              for causal explanation and the assumption that models with high 
              explanatory power are inherently of high predictive power. Conflation 
              between explanation and prediction is common, yet the distinction must
              be understood for progressing scientific knowledge. While this 
              distinction has been recognized in the philosophy of science, the 
              statistical literature lacks a thorough discussion of the many 
              differences that arise in the process of modeling for an explanatory 
              versus a predictive goal. The purpose of this article is to clarify 
              the distinction between explanatory and predictive modeling, to 
              discuss its sources, and to reveal the practical implications of the 
              distinction to each step in the modeling process. 
        AU  - Shmueli, Galit
        DA  - 2010/08
        DO  - 10.1214/10-STS330
        EP  - 310
        J2  - Statist. Sci.
        KW  - Explanatory modeling
        KW  - causality
        KW  - predictive modeling
        KW  - predictive power
        KW  - statistical strategy
        KW  - data mining
        KW  - scientific research
        LA  - en
        M1  - 3
        PB  - The Institute of Mathematical Statistics
        PY  - 2010
        SN  - 0883-4237
        SP  - 289
        TI  - To Explain or to Predict?
        UR  - http://projecteuclid.org/euclid.ss/1294167961
        VN  - 25
        ER  - \n\n"),
    'Shmueli, G. (2010). To explain or to predict? <i>Statistical Science, 25</i>(3), 289–310. doi:10.1214/10-STS330. Retrieved from http://projecteuclid.org/euclid.ss/1294167961',
    'Project Euclid: Statistical Science';


done_testing;
