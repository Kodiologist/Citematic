#!/usr/bin/perl
package Citematic::Get;

use utf8;
use warnings;
use strict;

use Citematic::RIS;

use Encode;
use List::Util 'first', 'min';
use HTTP::Request::Common;
use URI;
use URI::Escape;
use HTML::Entities 'decode_entities';
use LWP::Simple ();
use HTTP::Cookies::Mozilla;
use Business::ISBN;
use Text::Aspell;
use JSON qw(from_json to_json);
use File::Slurp qw(slurp write_file);
use XML::Simple 'XMLin';

use parent 'Exporter';
our @EXPORT_OK = qw(get digest_ris);

use constant CONFIG_PATH => "$ENV{HOME}/.citematic";

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

sub tail {@_[1..$#_]}

# ------------------------------------------------------------
# * Get configuration
# ------------------------------------------------------------

-e CONFIG_PATH or die 'No configuration file found at ', CONFIG_PATH;

our %config = %{from_json slurp CONFIG_PATH};

-e $config{storage_dir} or mkdir $config{storage_dir} or die "Couldn't create $config{storage_dir}: $!";
$config{storage_dir} =~ s!/\z!!;

my $cache_path = "$config{storage_dir}/cache.json";

my $orig_cache_text;
my $global_cache;
   {$orig_cache_text = -e $cache_path && slurp $cache_path;
    $global_cache = from_json($orig_cache_text || '{}', {utf8 => 1});
    END
       {write_cache();}}

sub write_cache
   {my $new_t = to_json $global_cache,
        {utf8 => 1, pretty => 1, canonical => 1};
    $orig_cache_text and $new_t eq $orig_cache_text or
        write_file $cache_path, $new_t;}

# ------------------------------------------------------------
# * General
# ------------------------------------------------------------

$LWP::Simple::ua->agent('Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:49.0)');
$LWP::Simple::ua->cookie_jar(HTTP::Cookies::Mozilla->new(
    file => $config{mozilla_cookies_path},
    autosave => 1));
push @{$LWP::Simple::ua->requests_redirectable}, 'POST';

our $verbose;
our $debug;

my $suffix_re = qr/(?:Jr\.?|Sr\.?|III\b|IV\b)/;
  # I don't try to capture Roman numerals of V or higher because
  # otherwise, an initial of V is likely to be mistaken for a suffix.

my $speller = new Text::Aspell;

sub note
   {$verbose and print STDERR @_, "\n";}

sub debug
   {$debug and print STDERR @_, "\n";}

sub progress
   {note @_, '…';}

sub warning
   {note 'WARNING: ', @_;}

sub err
   {note @_;
    return undef;}

sub α   ($) {defined $_[0] or return (); _testref($_[0], 'ARRAY');             @{ $_[0] }}
sub η   ($) {defined $_[0] or return (); _testref($_[0], 'HASH');              %{ $_[0] }}
sub _testref
   {ref($_[0]) eq $_[1] and return 1;
    die "$_[0] isn't a reference of type $_[1].\n";}
sub σ { ( [@_] ) } # σ for σquare brackets
sub χ { ( {@_} ) } # χ for χurlies

sub runsub (&)
   {return $_[0]->();}

sub matches
# Returns how many instances of $regex are in $string.
 {my $regex = shift;
  my $string = @_ ? shift : $_;
  my $n = 0;
  ++$n while $string =~ m/$regex/g;
  return $n;}

sub apply (&;$)
 {my $block = shift;
  local $_ = @_ ? shift : $_;
  $block->();
  return $_;}

sub _spaces_to_plus
   {my $s = $_[0];
    $s =~ s/%20/+/g;
    $s;}

sub query_url
   {my $prefix = shift;
    my @a;
    push @a, sprintf '%s=%s',
            _spaces_to_plus(URI::Escape::uri_escape_utf8(shift)),
            _spaces_to_plus(URI::Escape::uri_escape_utf8(shift))
        while @_;
    $prefix . '?' . join '&', @a;}

my %last_got;
sub sleep_if_necessary
   {my $url = shift;
    my $domain = URI->new($url)->host;
    my $to_wait = 3 + rand();
    if (time() - ($last_got{$domain} || 0) <= $to_wait)
      # Don't hit the same domain too rapidly.
       {progress 'Sleeping';
        sleep(time() - $last_got{$domain} + $to_wait);}
    $last_got{$domain} = time;}

sub lwp_get
   {my $url = shift;
    sleep_if_necessary($url);
    progress "Getting $url ";
    my $result = $url =~ m!scholar\.google\.com(?:/|\z)!
      ? do
            # LWP doesn't seem to choose the right cookies to send.
            # So we have to do it manually. (You can imagine how much
            # fun I had hunting down this bug.)
           {my $request = HTTP::Request::Common::GET($url);
            $LWP::Simple::ua->prepare_request($request);
            $request->header('Cookie', get_gscholar_cookie());
            $LWP::Simple::ua->send_request($request)->decoded_content}
      : LWP::Simple::get($url);
    defined $result
      ? $result
      : die "lwp_get failed: $url"}

sub lwp_post
   {my ($url, %args) = @_;
    sleep_if_necessary($url);
    progress "Posting to $url ";
    my $request = HTTP::Request::Common::POST($url, %args);
    $LWP::Simple::ua->prepare_request($request);
    # Override cookies.
    foreach ('Cookie', 'Cookie2')
       {exists $args{$_}
            and $request->header($_, $args{$_});}
    my $resp = $LWP::Simple::ua->send_request($request);
    $resp->is_success
        or die "lwp_post failed: $url";
    $resp->decoded_content;}

sub get_redir_target
   {my $url = shift;
    sleep_if_necessary($url);
    my $req = HTTP::Request::Common::HEAD($url,
        Accept => 'text/html');
    progress "Getting target of $url ";
    my $resp = $LWP::Simple::ua->request($req);
    $resp->is_success
        or die "get_redir_target failed: $url   " . $resp->status_line() . "\n\n\n" . $resp->decoded_content;
    '' . $resp->request->uri;}

sub fix_allcaps_word
   {my $all_low = lc shift;
    if ($speller->check($all_low))
       {$all_low;}
    else
       {my $sug = ($speller->suggest($all_low))[0];
        lc($sug) eq $all_low ? $sug : $all_low;}}

sub fix_allcaps_name
   {my $name = shift;
    my $prefix = '';
    $name =~ s/\AMc// and $prefix = 'Mc';
    $name =~ s/\AMac// and $prefix = 'Mac';
    $name = ucfirst lc $name;
    $name =~ s/-(\w)/-\U$1/g;
    $prefix . $name;}

sub format_suffix
   {my $str = shift;
    $str =~ s/\A([SJ]r)\.?/$1./;
    return
        $str eq '1st' ? 'I'
      : $str eq '2nd' ? 'II'
      : $str eq '3rd' ? 'III'
      : $str}

sub digest_author
   {my $str = shift;
    $str =~ s/\(.+?\)//g;
    if ($str =~ /,/)
      # We have something of the form "Smith, A. R." or "Smith,
      # A.R." or "Smith, Allen R." or "Smith, Allen Reginald" or
      # "Smith, A. Reginald".
       {$str =~ s/\.([[:upper:]])/. $1/g;
          # Fix initials crammed together without spaces.
        my @suffix;
        $str =~ s/,?\s+($suffix_re)//i
            and @suffix = (suffix => format_suffix $1);
        $str =~ / \A (.+?), \s* (.+?) (?: < | , | \z) /x or die;
        my ($surn, $rest) = ($1, $2);
        do {(my $surn_no_mc = $surn) =~ s/\Ama?c//i; $surn_no_mc =~ /[[:lower:]]/}
            or $surn = fix_allcaps_name $surn;
        # Add periods after initials, if necessary.
        $rest =~ s/\b([[:upper:]])( |\z)/$1.$2/g;
        χ family => $surn, given => $rest, @suffix;}
    elsif ($str =~ /[[:lower:]]\s+[[:upper:]]{1,4}(?:\s+$suffix_re)?\z/)
      # We have something of the form "Smith AR".
       {$str =~ s/\s+([[:upper:]]+)\s*($suffix_re?)\z//;
        my ($given, @suffix) = $1;
        $2 and @suffix = (suffix => format_suffix $2);
        χ family => $str,
            given => join(' ', map {"$_."} split //, $given),
            @suffix;}
    else
      # We have something of the form "Allen R. Smith".
       {$str =~ /[[:upper:]]{5}/
            and $str = join ' ',
                map {fix_allcaps_name $_}
                split /\s/, $str;
        my ($rest, $surn) = runsub
           {my @ws = split /\s+/, $str;
            # Try to split the name into a given name and surname
            # by ending the given name once the current word has
            # a period and the next doesn't.
            foreach my $i (0 .. $#ws - 1)
               {if ($ws[$i] =~ /\.\z/ and $ws[$i + 1] !~ /\.\z/)
                   {return [@ws[0 .. $i]], [@ws[$i + 1 .. $#ws]];}}
            # Otherwise, treat the last word as the surname and
            # the rest as given.
            return [@ws[0 .. $#ws - 1]], [$ws[$#ws]];};
        #$str =~ /\A (\S) \S+ ((?: \s \S\.)*) \s+ (\S+) \z/x;
        $_ = join ' ', @$_ foreach $surn, $rest;
        χ family => $surn, given => $rest;}}

sub digest_journal_title
   {my $j = shift;
    $j =~ s/\AThe //;
    $j =~ s/\s*\([^)]+\)\s*\z//;
    $j =~ s/ = .+//;

    $j =~ /Proceedings of the National Academy of Sciences of the United States of America/i
        and return 'Proceedings of the National Academy of Sciences';
    $j eq 'Proceedings. Biological Sciences'
        and return 'Proceedings of the Royal Society B';
    $j =~ /Philosophical Transactions of the Royal Society of London\. Series ([AB])/i
        and return "Philosophical Transactions of the Royal Society $1";
    $j =~ /Journals of Gerontology\W+Series B/i
        and return 'The Journals of Gerontology, Series B: Psychological Sciences and Social Sciences';
    $j =~ /IEEE Transactions on Systems/i
        and return 'IEEE Transactions on Systems, Man, and Cybernetics';
    $j =~ s/, IEEE Transactions on//
        and return "IEEE Transactions on $j";
    $j eq 'American Statistician'
        and return 'The American Statistician';
    $j =~ /ANNALS of the American Academy of Political and Social Science/i
       and return 'The ANNALS of the American Academy of Political and Social Science';
    $j =~ /\AJournal of Psychology(?:\z|:)/i
        and return 'The Journal of Psychology: Interdisciplinary and Applied';
    $j =~ /PLOS ONE/i
        and return 'PLOS ONE';

    if ($j =~ /Memory (?:and|&) Cognition/i
            or $j =~ /Psychology (?:and|&) Health/i)
       {$j =~ s/and/&/;}
    else
       {$j =~ s/&/and/;}
    $j =~ s/(\A| )(\w)/$1\u$2/g;
    $j =~ s/\b(An|And|As|At|But|By|Down|For|From|In|Into|Nor|Of|On|Onto|Or|Over|So|The|Till|To|Up|Via|With|Yet)\b/\l$1/g;
    if ($j =~ /\AJournal of Experimental Psychology/i or
        $j =~ /\AAmerican Economic Journal/i)
       {$j =~ s/\./:/;}
    else
       {$j =~ s!\s*[/:.].+!!;}
    $j;}

sub expand_last_page_number
   {my ($first, $last) = @_;
    $last and length $last < length $first
      ? # The last page number has fewer digits than the first,
        # so append the appropriate prefix.
        substr($first, 0, length($first) - length($last)) . $last
      : $last;}

sub digest_pages
   {my ($first, $last) = @_;
    $last ? "$first–$last" : $first;}

sub format_nonjournal_title
   {my $s = shift;
    # Change nonbreaking spaces to regular spaces.
    $s =~ s/\x{A0}/ /g;
    # Remove leading space.
    $s =~ s/\A\s+//;
    if ($s =~ / / and
        matches(qr/\b[[:upper:]]/, $s) /
        matches(qr/\b[[:alpha:]]/, $s) > 1/2)
       {warning 'The article title may be miscapitalized.';
        # But we'll try to fix it.
        if ($s =~ /[[:lower:]]/)
          # The Title Is Probably Capitalized Like This.
           {$s =~ s {[- ('‘"“]\K([[:upper:]])([^-. ()'‘’"“’]+)}
               {my $lower = lc($1) . $2;
                if ($speller->check($lower))
                   {$lower;}
                else
                   {my $sug = ($speller->suggest($lower))[0];
                    lc($sug) eq lc($lower) ? $sug : $lower;}}eg;
            # Make sure the first letter of the title is capitalized.
            $s =~ s{([[:alpha:]])} {uc $1}e;}
        else
          # THE TITLE IS IN ALL CAPS.
           {$s =~ s {([^- .?!]+)} {fix_allcaps_word $1}eg;
            $s = ucfirst $s;}
        # Capitalize Roman numerals.
        $s =~ s/\b(i{1,3}|iv|v|vi{1,3}|ix)\b/uc($1)/ige;}
    # Insert a space and capitalize after (but remove spaces
    # before) colons and question marks.
    $s =~ s/\s*([:?])\W+(\w)/$1 . ' ' . uc $2/ge;
    # Correct GNU-style single quotes that should be double quotes.
    $s =~ s/`([^`']+)'/"$1"/g;
    # Correct matched single quotes that should be double quotes.
    $s =~ s/(\W|\A)'([^`' ][^`']*[^`' ])'(\W|\z)/$1"$2"$3/g;
    # Correct fake ellipses.
    $s =~ s/\.\.\./…/g;
    # Space ellipses correctly.
    $s =~ s/(\w)\s*…/$1…/g;
    $s =~ s/…(\w)/… $1/g;
    # Remove any trailing periods.
    $s =~ s/\.+\z//;
    $s;}

sub format_publisher
   {my $s = shift;
    $s =~ s! \A [^/]+ / ([^/]+) \z!$1!x;
    $s =~ s/, Inc\.?\z//;
    $s =~ s/ Associates\z//;
    $s =~ s/ Co\.?\z//;
    $s =~ s/ Pub(?:lishing|lications|\.)?\z//;
    $s;}

sub format_place
   {my $s = shift;
    $s =~ s/\s*;.+//;
    $s =~ s/ \s* \[ ([^\]]+) \] \z/, $1/x;
    $s =~ s{ \b ( (?: [[:upper:]] \.){2,} ) }
        {join '', $1 =~ /[[:upper:]]/g}ex;
    $s =~ s/\A[^,]+,[^,]+\K,.+//;
    $s =~ s/\.//g;
    $s =~ s/Calif/CA/g;
    $s eq 'New York' ? 'New York, NY'
      : $s eq 'Boston' ? 'Boston, MA'
      : $s eq 'Minneapolis' ? 'Minneapolis, MN'
      : $s eq 'New Haven' ? 'New Haven, CT'
      : $s eq 'London' ? 'London, UK'
      : $s eq 'Berlin' ? 'Berlin, Germany'
      : $s eq 'Beijing' ? 'Beijing, PRC'
      : $s eq 'Oslo' ? 'Oslo, Norway'
      : $s}

sub format_isbn
   {my $s = shift;
    defined $s
      ? Business::ISBN->new($s)->as_isbn13->as_string
      : $s;}

sub citation
   {my %h = @_;
    foreach (keys %h)
       {if (defined $h{$_})
           {if (ref $h{$_})
              {}
            else
              {$h{$_} =~ tr/‘’“”/''""/;}}
        else
           {delete $h{$_};}}
    \%h;}

sub journal_article
   {my ($authors, $year, $article_title, $journal, $volume, $issue,
        $first_page, $last_page, $doi, $url) = @_;

    $article_title = format_nonjournal_title $article_title;
    if (defined $issue)
      {$issue =~ s/Suppl\.?(?:ement)?/Suppl./;
       $issue =~ /\A(\d+)-(\d+)\z/ and $2 == $1 + 1
           and $issue = "$1, $2";
       $issue =~ s/p\d.*//;}
    $journal =~ /\AThe Journals of Gerontology/
        and $volume =~ s/[A-Z]\z//;
    $journal eq 'PLOS ONE' || $journal =~ /\ACochrane Database/
      # We don't need all this stuff for a purely electronic journal.
        and do {undef $volume; undef $issue; undef $first_page; undef $last_page;};
    !$url and $journal eq 'Judgment and Decision Making'
        and $url = sjdm_url_from_title($article_title);

    citation
        type => 'article-journal',
        author => $authors,
        issued => {'date-parts' => [[$year]]},
        title => $article_title,
        'container-title' => $journal,
        volume => $volume,
        issue => $issue,
        page => digest_pages($first_page, $last_page),
        DOI => $doi,
        URL => $url;}

sub book_chapter
   {my ($authors, $year, $chapter_title, $editors, $book, $volume,
        $edition, $first_page, $last_page, $place, $publisher, $isbn) = @_;
    citation
        type => 'chapter',
        author => $authors,
        issued => {'date-parts' => [[$year]]},
        title => format_nonjournal_title($chapter_title),
        editor => $editors,
        'container-title' => format_nonjournal_title($book),
        volume => $volume,
        edition => $edition,
        page => digest_pages($first_page, $last_page),
        'publisher-place' => format_place($place),
        publisher => format_publisher($publisher),
        ISBN => format_isbn($isbn);}

sub whole_book
   {my ($authors, $year, $book, $editors, $volume,
        $edition, $place, $publisher, $doi, $isbn) = @_;
    citation
        type => 'book',
        author => $authors,
        issued => {'date-parts' => [[$year]]},
        title => format_nonjournal_title($book),
        editor => $editors,
        volume => $volume,
        edition => $edition,
        'publisher-place' => format_place($place),
        publisher => format_publisher($publisher),
        DOI => $doi,
        ISBN => format_isbn($isbn);}

sub manuscript
   {my ($authors, $year, $title, $url) = @_;
    citation
        type => 'manuscript',
        author => $authors,
        issued => {'date-parts' => [[$year]]},
        title => format_nonjournal_title($title),
        URL => $url;}

# ------------------------------------------------------------
# * CrossRef
# ------------------------------------------------------------

sub query_crossref
   {my %p = @_;
    $p{id}
        and $p{id} =~ s/^doi://;
    my $url = query_url 'http://www.crossref.org/openurl/',
        pid => $config{crossref_email},
        noredirect => 'true',
        map {$_ => lc($p{$_})} sort keys %p;
    progress 'Trying CrossRef';
    my $x = $global_cache->{crossref}{$url} ||= XMLin
        lwp_get($url),
        ForceArray => ['contributor', 'year'],
        GroupTags => {contributors => 'contributor'};
    $x = $x->{query_result}{body}{query};
    exists $x->{contributors}
        or return err 'No results.';
    $x = {%$x}; # Don't modify the thing we're caching.
    $x->{contributors} = σ
        grep {$_->{contributor_role} eq 'author' and
            $_->{surname} ne 'et al'}
        α $x->{contributors};
    $x->{year} =
        (first
            {ref and exists $_->{media_type} and $_->{media_type} eq 'print'}
            α $x->{year}) ||
        $x->{year}[0];
    ref $x->{year} and $x->{year} = $x->{year}{content};
    $x->{doi} = $x->{doi}{content};
    $x;}

sub from_doi
   {η query_crossref id => $_[0];}

sub get_doi_for_journal_article
   {my ($year, $journal, $article_title, $first_author_surname, $volume, $first_page) = @_;

    my %record = η
       (query_crossref
           (aulast => $first_author_surname,
              # CrossRef accepts only the first author, sadly.
            date => $year,
            title => $journal =~ /Canadian Journal of Experimental Psychology/i
              ? # CrossRef doesn't like the English title alone.
                'Canadian Journal of Experimental Psychology/Revue canadienne de psychologie expérimentale'
              : $journal,
            atitle => $article_title,
            ($volume ? (volume => $volume) : ()),
            ($first_page ? (spage => $first_page) : ()))
        || return undef);

    return $record{doi};}

sub get_doi_for_book
   {my ($year, $book_title, $first_surname) = @_;

    my %record = η
       (query_crossref
           (aulast => $first_surname,
            date => $year,
            title => $book_title)
        || return undef);

    return $record{doi};}

sub digest_crossref_contributors
   {σ
    map
       {# Add periods to initials.
        $_->{given_name} =~ s/ ([[:upper:]])\b(?!\.)/ $1./g;
        χ
            given => $_->{given_name},
            family => $_->{surname}}
    @{shift()}}

sub crossref_journal_article
   {my $doi = shift;
    my %d = from_doi($doi);
    journal_article
        digest_crossref_contributors($d{contributors}),
        $d{year}, $d{article_title}, digest_journal_title($d{journal_title}),
        $d{volume}, $d{issue}, $d{first_page}, $d{last_page},
        $doi, undef;}

# ------------------------------------------------------------
# * RIS
# ------------------------------------------------------------

sub digest_ris
   {my $ris = Citematic::RIS->new(shift);

    $ris->ris_type eq 'JOUR'
        or die sprintf q(Can't handle RIS type "%s"), $ris->ris_type;

    my $authors = σ map {digest_author $_}
        (ref $ris->authors ? α $ris->authors : $ris->authors);
    my ($year) = ($ris->Y1 || $ris->PY) =~ /(\d\d\d\d)/;
    my $title = $ris->TI || $ris->T1;
    my $journal = digest_journal_title(
        $ris->JO || $ris->JF || $ris->T2 || $ris->J2);
    my ($fpage, $lpage) =
        $ris->starting_page && $ris->starting_page =~ /[-–]/
      ? split /[-–]/, $ris->starting_page
      : ($ris->starting_page, $ris->ending_page);
    my $volume = $ris->volume || $ris->VN;
    my $issue = $ris->issue || $ris->M1;
    foreach ($volume, $issue, $fpage, $lpage)
       {defined or next;
        s/\s+\z//;
        s/\A0+([1-9][0-9]*)\z/$1/;}

    my $doi = $ris->doi;
    if (!$doi and $ris->M3
            and $ris->M3 =~ /\A10\./ || $ris->M3 =~ /\bdoi\b/)
       {$doi = $ris->M3;}
    $doi
        and ($doi) = $doi =~ /\b(10\.\S+)/;
    $doi ||= get_doi_for_journal_article(
        $year, $journal, $title,
        $authors->[0]{family},
        $volume, $fpage);

    my $url;
    if ($ris->UR and $ris->UR =~ m!\Ahttp://projecteuclid.org/!)
      # Keep Project Euclid URLs. Most of its journals are
      # open-access, so the URLs are convenient.
       {$url = $ris->UR;}
    elsif ($ris->UR and $ris->UR =~ m!\Ahttps?://www.ncbi.nlm.nih.gov/pmc/!)
      # PMC articles are always open-access.
       {$url = $ris->UR;}

    journal_article
        $authors, $year, $title, $journal,
        $volume, $issue,
        $fpage, $lpage,
        $doi, $url;}

# ------------------------------------------------------------
# * HTML meta tags
# ------------------------------------------------------------

sub get_html_meta_tags
   {my $url = shift;
    my $page = lwp_get($url);
    my %h = map {decode_entities $_}
        $page =~ m!<meta\s+(?:name|property)="([^"]+)"\s*content="(.+?)"\s*/?\s*>!g;
    $h{citation_title}
        or die 'Bad get_html_meta_tags page';
    foreach (keys %h)
       {$h{s/^og:/og_/r} = delete $h{$_};}
    $h{citation_author} = σ map {decode_entities $_}
        $page =~ /<meta\s+(?:name|property)="citation_authors?"\s*content="([^"]+)/g;
    \%h;}

sub digest_html_meta_tags
   {my %h = %{$_[0]};

    my $authors = σ
        map {digest_author $_}
        map {/\|/ ? split /\|/ : split qr/;\s+/}
        α $h{citation_author};
    ($h{citation_publication_date} || $h{citation_date}) =~ /(\d{4})/ or die;
    my $year = $1;

    if (!$h{og_type} or $h{og_type} eq 'Journal Article' or $h{og_type} eq 'Comment/Reply')
       {my ($volume, $issue, $first_page, $last_page) =
            @h{qw(citation_volume citation_issue citation_firstpage citation_lastpage)};
        if (!$volume or !$issue or !$first_page or !$last_page)
           {my @a = $h{'journal citation'} =~ /\A(\d+), (\d+), (\d+)(?:-(\d+))?,/;
            @a or die;
            $volume ||= $a[0];
            $issue ||= $a[1];
            $first_page ||= $a[2];
            $last_page ||= $a[3];}
        $last_page =~ s/;.+//;
        $last_page = expand_last_page_number $first_page, $last_page;
        my $journal_title = digest_journal_title(
            $h{citation_journal_title});
        my $doi = $h{citation_doi} || get_doi_for_journal_article
            $year, $journal_title, $h{citation_title},
            $authors->[0]{family},
            $volume, $first_page;
        return journal_article
            $authors, $year, $h{citation_title},
            $journal_title, $volume, $issue,
            $first_page, $last_page, $doi, undef;}

    else
       {die "Bad og:type $h{og_type}"}}

# ------------------------------------------------------------
# * Google Scholar
# ------------------------------------------------------------

sub get_gscholar_cookie
  {my ($nid, $gsp);
   $LWP::Simple::ua->cookie_jar->scan(sub
      {my ($version, $key, $val, $path, $domain, $port, $path_spec, $secure, $expires, $discard, $hash) = @_;
       if ($domain eq '.google.com' and $key eq 'NID')
          {$nid = $val;}
       elsif ($domain eq '.scholar.google.com' and $key eq 'GSP')
          {$gsp = $val;}});
   join '; ',
     (defined $nid ? ("NID=$nid") : ()),
     (defined $gsp ? ("GSP=$gsp") : ());}

sub show_hash;
sub show_hash
   {my $x = shift;
    ref $x
      ? sprintf '{%s}', join ', ',
            map {"$_: " . show_hash $x->{$_}}
            sort keys %$x
      : apply {s/"/'/g} $x}

sub gscholar
# Allowed %terms:
#   author (array ref)
#   year (scalar)
#   year_min (scalar)
#   year_max (scalar)
#   title (array ref)
#   doi (scalar) [not used for searching, but included in citation]
   {my %terms = @_;
    $terms{year} and
       $terms{year_min} = $terms{year_max} = $terms{year};

    progress 'Trying Google Scholar';

    my %search_fields = map {lc $_}
       (as_q => (!$terms{title} ? '' :
            join(' ', map {qq("$_")} α $terms{title})),
        !$terms{author} ? () :
            (as_sauthors => join(' ', map {qq("$_")} α $terms{author})),
        !defined $terms{year_min} ? () :
            (as_ylo => $terms{year_min}),
        !defined $terms{year_max} ? () :
            (as_yhi => $terms{year_max}));

    my $cache_key = show_hash \%search_fields;
    $cache_key =~ s/\A\{//;
    $cache_key =~ s/\}\z//;
    my $url = query_url 'https://scholar.google.com/scholar',
        %search_fields,
        as_occt => 'title',
        btnG => '';
    my $got = ($global_cache->{gscholar_first}{$cache_key} ||= runsub
       {my $page = lwp_get($url);
        unless ($page =~ m!<div class="gs_ri">(.+?)title="Fewer"!si)
           {if ($page =~ /id="gs_captcha_f"><h1>Please show/)
               {die "Hit Google Scholar CAPTCHA. Visit the page with Mozilla, solve the CAPTCHA, quit Mozilla, and try again.\n";}
            elsif ($page =~ /\bdid not match any articles\b/)
               {return [];}
            else
               {die 'Unknown weirdness';}}
        my $chunk = $1;
        $chunk =~ /<a\s+href="([^"]+)/ or die 2;
        my $result_url = decode_entities($1);
        $result_url =~ m!\A/citations?!
          # This just a citation Google Scholar scraped from
          # elsewhere, not a link to any bibliographic data.
            and $result_url = undef;
        my $cluster_id;
        $chunk =~ m!/scholar\?cluster=(\d+)!
            and $cluster_id = $1;
        [$cluster_id, $result_url]});

    @$got
        or return err 'No results.';
    my ($cluster_id, $result_url) = @$got;
    my $r = $result_url && get_from_url($result_url, $terms{doi});

    unless (defined $r)
       {my $urls = [];
        $cluster_id and $urls = ($global_cache->{gscholar_rest}{$cluster_id} ||= runsub
           {my $cluster_page = lwp_get(
                "https://scholar.google.com/scholar?cluster=$cluster_id");
            my @versions;
            for (;;)
               {push @versions,
                    grep {$_ ne '#'
                        and $_ !~ /\Ajavascript:/ and $_ !~ m!\A/citations?!}
                    map
                        {/<a\s+href="([^"]+)/ or die;
                            decode_entities($1)}
                    $cluster_page =~ m!<div class="gs_ri">(.+?)title="Fewer"!sig;
                $cluster_page =~ m!<a href="(/scholar?[^"]+)"><span class="gs_ico gs_ico_nav_next"!
                    or last;
                $cluster_page = lwp_get('https://scholar.google.com' . decode_entities($1));}
            \@versions});
        foreach (@$urls)
           {$r = get_from_url($_, $terms{doi});
            defined $r and last;}
        unless (defined $r)
           {return err "No good URL"}}

    $r;}

# ------------------------------------------------------------
# * get_from_url
# ------------------------------------------------------------

sub get_from_url
# Called primarily from gscholar, but uses a variety of websites,
# none of which are Google Scholar.
   {my ($url, $doi) = @_;
    my $domain = URI->new($url)->host;

# ** Cases that can use HTML meta tags

    if ($domain eq 'eric.ed.gov')
       {progress 'Using ERIC';
        return digest_html_meta_tags $global_cache->{eric}{$url} ||=
            get_html_meta_tags $url;}

# ** Cases that can use RIS

    elsif ($url =~ m!\Ahttps?://www\.ncbi\.nlm\.nih\.gov/pmc/articles/PMC(\d+)/?\z!i
            or $url =~ m!https?://europepmc\.org/articles/PMC(\d+)\z!i)
       {my $id = $1;
        progress 'Using PMC';
        $url = query_url 'http://www.ncbi.nlm.nih.gov/pmc/utils/ctxp',
            ids => "PMC$id", report => 'ris', format => 'ris';
        return digest_ris($global_cache->{pmc}{$id} ||=
            decode 'UTF-8', lwp_get $url);}

    elsif ($domain eq 'www.jstor.org')
       {progress 'Using JSTOR';
        my $path =
            $url =~ m!\Ahttps?://www\.jstor\.org/stable/(\d+)(?:\?|\z)!
          ? "10.2307/$1"
          : $url =~ m!\Ahttps?://www\.jstor\.org/stable/(10\.\d+/\d+)(?:\?|\z)!
          ? $1
          : die "Bad JSTOR URL: $url";
        $url = "http://www.jstor.org/citation/ris/$path";
        return digest_ris($global_cache->{jstor}{$path} ||=
           lwp_get($url));}

    elsif ($domain eq 'onlinelibrary.wiley.com')
       {progress 'Using Wiley';
        $url =~ m!/doi/(.+?)/(?:full|abstract|pdf)\b! or die "Bad Wiley URL: $url";
        $doi = $1;
        my $url = query_url
            "http://onlinelibrary.wiley.com/enhanced/getCitation/doi/$doi",
            'citation-type' => 'reference';
        return digest_ris($global_cache->{wiley}{$doi} ||=
            decode 'UTF-8', lwp_get $url);}

    elsif ($domain eq 'link.springer.com')
       {progress 'Using SpringerLink';
        $url =~ m!https?://link\.springer\.com/article/(10\.\d+/.+)! or die "Bad Springer URL: $url";
        my $doi = $1;
        $url = query_url
            'http://citation-needed.services.springer.com/v2/references/' .
               $doi,
            format => 'refman',
            flavour => 'citation';
        return digest_ris($global_cache->{springer}{$doi} ||= decode 'UTF-8', lwp_get($url));}

    elsif ($domain eq 'www.sciencedirect.com')
       {progress 'Using ScienceDirect';
        $url =~ m!https?://www\.sciencedirect\.com/science/article/pii/([^/]+)! or die "Bad ScienceDirect URL: $url";
        my $id = $1;
        $url = query_url 'http://www.sciencedirect.com/sdfe/arp/cite',
            pii => $id,
            format => 'application/x-research-info-systems',
            withabstract => 'false';
        return digest_ris($global_cache->{sciencedirect}{$id} ||=
            decode 'UTF-8', lwp_get($url));}

# ** PsycNET

    if ($domain eq 'psycnet.apa.org' || $domain eq 'doi.apa.org')
       {progress 'Trying PsycNET';

        $url =~ s/\.pdf\z//;
        $url =~ m!/(?:record|psycinfo|books)/([^/]+)!
            or $url =~ m!uid=([^/&=]+)!
            or ($global_cache->{psycnet}{uids}{$url} ||=
                    get_redir_target($url))
                =~ m!/record/([^/]+)\z!
            or die "Bad PsycNET URL: $url";
        my $uid = $1;

        my %h = %{$global_cache->{psycnet}{records}{$uid} ||=
            from_json(
                lwp_post('http://psycnet.apa.org/api/request/search.record',
                    # We blank out cookies because they may cause
                    # an error, possibly because we're not
                    # executing some sort of session-management
                    # JavaScript.
                    Cookie => '',
                    Cookie2 => '',
                    'Content-Type' => 'application/json',
                    Referer => "http://psycnet.apa.org/record/$uid",
                    Content => qq({"api": "search.record",
                       "params": {"metadata":{"uid": "$uid"},
                       "responseParameters": {"results": true}}})),
                {utf8 => 1})->{results}{result}{doc}[0]};

        my $authors = σ map {digest_author $_} α $h{AuthorName};
        my $title = $h{GivenDocumentTitle};
        my $year = $h{PublicationYear};
        my $journal = $h{PublicationName};
        my $volume = $h{PAVolume};
        my $issue = $h{PAIssueCode};
        my $first_page = $h{PAFirstPage};
        my $last_page;
        my $doi = $h{DOI};

        if ($h{SourceAPA} =~ m!
                <em> [^<]+? , \s* (?<volume> \d+) </em>
                \(
                    (?<issue> \d+ (?: [,-] \s* \d+)?)
                    [^)]* \), \s*
                (?<first_page> \d+) - (?<last_page> \d+)!x)
           {$volume //= $+{volume};
            $issue //= $+{issue};
            $first_page //= $+{first_page};
            $last_page = $+{last_page};
            return journal_article
                $authors, $year, $title,
                digest_journal_title($journal), $volume, $issue,
                $first_page, $last_page, $doi, undef;}
        elsif ($h{SourcePI} =~ m!
                \A (?<editors> .+?) \s+ \( \d{4} \) \.
                .+?
                \( pp\. \s+
                    (?<first_page> \d+) - (?<last_page> \d+) \) \. \s+
                (?<place> .+?) : \s+
                (?<publisher> [^,.]+) !x)
           {my %s = %+;
            $first_page //= $s{first_page};
            $last_page = $s{last_page};
            my $editors = σ map {digest_author $_}
                $s{editors} =~ /([[:alpha:]].+?)\s+\(Ed\)/g;
            my $place = $s{place};
            my $publisher = $s{publisher};
            my $edition;
            my $book = $journal;
            $book =~ s/, (\d+[a-z]{2}) ed\.//
                and $edition = $1;
            $book =~ s/, vol\. (\d+).+//i
                and $volume //= $1;
            my ($isbn) = $h{ISBN}[0] =~ /(\S+)/;
            return book_chapter
                $authors, $year, $title, $editors, $book, $volume,
                $edition, $first_page, $last_page, $place, $publisher,
                $isbn;}
        else
           {die "SourceAPA: $h{SourceAPA} // SourcePI: $h{SourcePI}";}}

# ** PubMed

    elsif ($url =~ m!\Ahttps?://www\.ncbi\.nlm\.nih\.gov/pubmed/(\d+)\z!
            or $url =~ m!https?://europepmc\.org/abstract/med/(\d+)\z!)
       {my $pmid = $1;
        progress 'Using PubMed';

        $url = query_url 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi',
            db => 'pubmed', id => $pmid, retmode => 'xml';
        my %h = %{$global_cache->{pubmed}{$pmid} ||= XMLin(
            lwp_get($url),
            KeyAttr => [],
            ForceArray => ['Author', 'ELocationID'])->{PubmedArticle}{MedlineCitation}{Article}};

        my $year = $h{Journal}{JournalIssue}{PubDate}{Year} || do
           {$h{Journal}{JournalIssue}{PubDate}{MedlineDate}
                =~ /(\d\d\d\d)/ or die;
            $1};
        my $authors = σ
            map {χ
                family => ($_->{LastName} =~ /[[:lower:]]/
                  ? $_->{LastName}
                  : fix_allcaps_name $_->{LastName}),
                given => (apply {s/\b([[:upper:]])( |\z)/$1.$2/g} $_->{ForeName}),
                ($_->{Suffix} ? (suffix => format_suffix $_->{Suffix}) : ())}
            α $h{AuthorList}{Author};
        my $journal_title = digest_journal_title $h{Journal}{Title};

        my ($first_page, $last_page);
        if ($h{Pagination}{MedlinePgn})
           {my $pages = $h{Pagination}{MedlinePgn};
            $pages =~ s/;.+//;
            ($first_page, $last_page) = $pages =~ /-/
              ? split(/-/, $pages)
              : ($pages, undef);}

        if ($h{ELocationID}) {foreach (α $h{ELocationID})
          {if ($_->{EIdType} eq 'doi')
              {$doi = $_->{content};
               last;}}}

        $doi ||= get_doi_for_journal_article
            $year, $journal_title, $h{ArticleTitle},
            $authors->[0]{family},
            $h{Journal}{JournalIssue}{Volume}, $first_page;

        return journal_article
            $authors, $year, $h{ArticleTitle},
            $journal_title,
            $h{Journal}{JournalIssue}{Volume}, $h{Journal}{JournalIssue}{Issue},
            $first_page, $last_page, $doi, undef;}

    elsif ($domain eq 'www.ncbi.nlm.nih.gov' or $domain eq 'europepmc.org')
      # We should've caught these earlier.
       {die "Unrecognized NCBI / Europe PMC: $url";}

# ** IDEAS

    elsif ($domain eq 'ideas.repec.org' and $url !~ m!/wpaper/!)
       {progress 'Using IDEAS';

        my %record = η($global_cache->{ideas}{$url} ||= do
           {my $page = lwp_get($url);
            my %meta =
                map {decode_entities $_}
                $page =~ /<META NAME="citation_([^"]+)" content="([^"]+)">/g;
            # Sometimes we can get middle initials in the
            # registered-authors list that aren't in the meta tags.
            if ($page =~ m{Registered</A> author\(s\): <UL[^>]+>(.+?)</UL>}s)
               {my $alist = $1;
                foreach my $a ($alist =~ m{<LI><A HREF=[^>]+>(.+?) </A>}g)
                  {$a =~ /\s\s/ and next;
                     # No middle initials to get for this author.
                   (my $without_initials = $a) =~ s/ .+ (\S+)\z/ $1/;
                   $meta{authors} =~ s/\Q$without_initials\E/$a/;}}
                     # $meta{authors} may not be in the form "John Smith",
                     # but I think that's the only case in which middle
                     # initials would be omitted.
            \%meta;});

        my $authors = σ
            map {digest_author $_}
            split /;\s+/, $record{authors};

        my $journal = digest_journal_title $record{journal_title};

        my ($fpage, $lpage) = ($record{firstpage}, $record{lastpage});
        $lpage = expand_last_page_number $fpage, $lpage;

        my $doi = get_doi_for_journal_article
            $record{year}, $record{journal_title}, $record{title},
            $authors->[0]{family},
            $record{volume}, $fpage;

        return journal_article
            $authors, $record{year}, $record{title},
            $journal, $record{volume}, $record{issue},
            $fpage, $lpage, $doi, undef;}

    else
       {return undef;}}

# ------------------------------------------------------------
# * Library of Congress
# ------------------------------------------------------------

sub congress
# Allowed %terms:
#   author (array ref)
#     [Actually matches editors, too, which is useful for edited
#     collections of papers.]
#   year (scalar)
#   title (array ref)
#   isbn (scalar)
   {my %terms = @_;
    progress 'Trying the Library of Congress';

    my $query = lc join ' and ',
        $terms{author} ? map {sprintf 'dc.author="%s"', s/"/\\"/rg} α $terms{author} : (),
        $terms{title} ? map {sprintf 'dc.title="%s"', s/"/\\"/rg} α $terms{title} : (),
        $terms{year} ? ("dc.date=$terms{year}") : (),
        $terms{isbn}
          ? ('bath.isbn='. Business::ISBN->new($terms{isbn})
                ->as_isbn13->as_string([]))
          : ();
    my $url = query_url 'http://lx2.loc.gov:210/lcdb',
        version => '1.1',
        operation => 'searchRetrieve',
        maximumRecords => '1',
        recordSchema => 'mods',
        query => $query;

    my %record = η($global_cache->{congress}{$query} ||= runsub
       {my %got;
        BLOCK:
           {%got = η XMLin(lwp_get($url),
                KeyAttr => {},
                ForceArray => [qw(name namePart dateIssued place publisher identifier note)]);
            if ($got{'zs:numberOfRecords'} == 0
                and $url =~ s/dc.date%3D(\d{4})/dc.date%3Dc$1/)
              # The year might need to be preceded by "c", for "circa",
              # so try again with the new URL.
               {redo BLOCK;}}
       # TODO?: Get multiple records and skip those without typeOfResource: text
       $got{'zs:numberOfRecords'}
         ? $got{'zs:records'}{'zs:record'}{'zs:recordData'}{mods}
         : {}});

    %record or return err 'No results.';

    my $byline = $record{note}[0]{content};
    my $is_edited =
        $byline =~ s/\Aedited // || $byline =~ s/, editors\.\z//;
    $byline =~ s/\Aby //;
    $byline =~ s/\.\z//;
    my ($authors, $editors);
    my @names1 = map {digest_author $_->{namePart}[0]} α $record{name};
    my @names2 = map {digest_author $_} split qr/,\s+(?:and\s+)?|\s+and\s+/, $byline;
    my $names =
        length(to_json(\@names2)) > length(to_json(\@names1))
      ? \@names2
      : \@names1;
    ($is_edited ? $editors : $authors) = $names;
    my ($year) = min $record{originInfo}{dateIssued}[0] =~ /(\d{4})/g;
    my $book = $record{titleInfo}{title};
    $record{titleInfo}{nonSort}
        and $book = $record{titleInfo}{nonSort} . lcfirst $book;
    $record{titleInfo}{subTitle}
        and $book .= ': ' . ucfirst $record{titleInfo}{subTitle};
    my $volume;
    my $edition = $record{originInfo}{edition};
    $edition and $edition =~ s/ ed\.?\z//;
    my $place = (first {$_->{placeTerm}{type} eq 'text'} α $record{originInfo}{place})->{placeTerm}{content};
    my $publisher = $record{originInfo}{publisher}[0];
    my $isbn = first {$_->{type} eq 'isbn'} α $record{identifier};
    $isbn and $isbn = $isbn->{content};
    my $doi = get_doi_for_book $year, $book, $names->[0]{family};

    return whole_book
        $authors, $year, $book, $editors, $volume,
        $edition, $place, $publisher, $doi, $isbn;}

# ------------------------------------------------------------
# * arXiv
# ------------------------------------------------------------

sub arxiv_from_id
   {my $id = shift;
    progress 'Trying the arXiv';

    my $url = "http://arxiv.org/abs/$id";

    my %record = η($global_cache->{arxiv}{$id} ||=
        get_html_meta_tags $url);

    my $authors = σ map {digest_author $_} α $record{author};
    $record{date} =~ m!(\d\d\d\d)/\d\d/\d\d! or die 'y';
    my $year = $1;

    manuscript $authors, $year, $record{title}, $url;}

# ------------------------------------------------------------
# * Society for Judgment and Decision-Making
# ------------------------------------------------------------

sub sjdm_url_from_title
   {my $title = shift;
    progress 'Trying SJDM';
    my $v = $global_cache->{sjdm}{lc($title)} ||= do
       {my $page = lwp_get(query_url
            'http://www.sjdm.org/cgi-bin/namazu.cgi',
            max => 10, result => 'normal', sort => 'score',
            idxname => 'journal',
            query => "{$title}");
          # In Namazu, curly braces signify an exact match.
          # http://www.namazu.org/doc/manual.html#query-phrase
        $page =~ m!<dt>1. <strong><a href="([^"]+)!
          ? $1
          : undef};
   defined $v ? $v : err 'No results.';}

# ------------------------------------------------------------
# * Public interface
# ------------------------------------------------------------

sub get
# Allowed %terms:
#   book (boolean)
#   author (array ref)
#   year (scalar)
#   year_min (scalar)
#   year_max (scalar)
#   title (array ref)
#   url (scalar)
#   isbn (scalar)
#   doi (scalar)
#   arxiv_id (scalar)
# Returns a hashref of CSL input data or undef.
   {my %terms = @_;
    first {$_ and !ref || (ref eq 'ARRAY' and @$_) || (ref eq 'HASH' and %$_)} values %terms
        or return err 'No search terms.';
    $terms{author} ||= [];
    $terms{title} ||= [];

    $terms{arxiv_id}
        and return arxiv_from_id($terms{arxiv_id});

    if ($terms{url})
      {return (get_from_url($terms{url}, $terms{doi})
          or die "URL not recognized: $terms{url}");}

    if ($terms{doi})
      # When we're starting with a DOI, we use CrossRef only to
      # get information to plug into other databases (and not to
      # generate citations directly) because CrossRef tends to be
      # less complete than other databases.
       {my %d = from_doi $terms{doi};
        $terms{author} = σ map {$_->{surname}} α $d{contributors};
        splice @{$terms{author}}, 5;
          # Google Scholar may get confused by lots of authors.
        $terms{year} = $d{year};
        my $title = $d{article_title} || $d{volume_title};
        $title and $terms{title} = σ format_nonjournal_title($title);
        $terms{doi} = $d{doi};}

    $terms{book}
      ? congress(%terms)
      : gscholar(%terms)}

1;
