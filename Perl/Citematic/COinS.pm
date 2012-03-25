package Citematic::COinS;

use utf8;
use warnings;
use strict;
use URI::Escape ();
use HTML::Entities 'encode_entities';

sub kv
   {my @a;
    while (@_)
       {my ($k, $v) = splice @_, 0, 2;
        defined $v or next;
        $k =~ /\Actx_|\Arft_/ or $k = "rft.$k";
        push @a, sprintf '%s=%s',
            URI::Escape::uri_escape_utf8($k),
            URI::Escape::uri_escape_utf8($v);}
    join '&', @a;}

sub coins_data
   {my %csl = %{shift()};
    my $article = $csl{type} =~ /article/;
    no warnings 'uninitialized';
    kv
        ctx_ver => 'Z39.88-2004',
        rft_val_fmt => $article
          ? 'info:ofi/fmt:kev:mtx:journal'
          : 'info:ofi/fmt:kev:mtx:book',
        genre =>
            $csl{genre} eq 'Advance online publication' ? 'preprint' :
            $article                ? 'article'  :
            $csl{type} eq 'chapter' ? 'bookitem' :
            $csl{type} eq 'book'    ? 'book'     :
            $csl{type} eq 'report'  ? 'report'   :
                                      'document',
        rft_id => $csl{DOI} ? "info:doi/$csl{DOI}" : $csl{URL},
        (map {+'au', "$_->{family}, $_->{given}"} @{$csl{author}}),
        atitle => $csl{title},
        ($article ? 'jtitle' : 'btitle') => $csl{'container-title'},
        date => $csl{issued}{'date-parts'}[0][0],
        volume => $csl{volume},
        issue => $csl{issue},
        artnum => $csl{number},
        pages => $csl{pages},
        place => $csl{'publisher-place'},
        pub => $csl{publisher},
        isbn => $csl{ISBN};}

sub coins
   {sprintf '<span class="Z3988" title="%s"></span>',
        encode_entities coins_data shift}

1;
