#!/usr/bin/perl

use utf8;
use warnings;
use strict;
use Citematic::Get 'digest_ris';
use Citematic::QuickBib;
use Test::More;

my $qb = new Citematic::QuickBib;

sub apa ($_)
   {(my $ris = $_[0]) =~ s/^ +//mg;
    my $x = digest_ris($ris);
    defined $x or return undef;
    $qb->bib1($x,
        style_path => $ENV{APA_CSL_PATH} ||
            die('The environment variable APA_CSL_PATH is not set'),
        apa_tweaks => 1,
        always_include_issue => 1, include_isbn => 1)}

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
        Content: text/plain



        TY  - JOUR
        JO  - Ethnology
        TI  - Is Rape a Cultural Universal? A Re-examination of the Ethnographic Data
        VL  - 28
        IS  - 1
        PB  - University of Pittsburgh- Of the Commonwealth System of Higher Education
        SN  - 00141828
        UR  - http://www.jstor.org/stable/3773639
        AU  - Palmer, Craig
        DO  - 10.2307/3773639
        T3  - \x10
        Y1  - 1989/01/01
        SP  - 1
        EP  - 16
        CR  - Copyright &#169; 1989 University of Pittsburgh- Of the Commonwealth System of Higher Education
        M1  - ArticleType: research-article / Full publication date: Jan., 1989 / Copyright © 1989 University of Pittsburgh- Of the Commonwealth System of Higher Education
        ER  - \n\n\n"),
    'Palmer, C. (1989). Is rape a cultural universal? A re-examination of the ethnographic data. <i>Ethnology, 28</i>(1), 1–16. Retrieved from http://www.jstor.org/stable/3773639',
    'JSTOR: Ethnography';

done_testing;
