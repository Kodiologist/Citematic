#!/usr/bin/perl
package Citematic::Get;

use utf8;
use warnings;
use strict;

use Citematic::RIS;

use Encode;
use List::Util 'first';
use LWP::Simple ();
use WWW::Mechanize;
use HTTP::Cookies;
use URI::Escape;
use HTML::Entities 'decode_entities';
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

our %config =
    tail split /(?:\A|\n{2,})\[(.+?)\]\n/, slurp CONFIG_PATH;

-e $config{storage_dir} or mkdir $config{storage_dir} or die "Couldn't create $config{storage_dir}: $!";
$config{storage_dir} =~ s!/\z!!;

my $ebsco_cookie_jar_path = "$config{storage_dir}/ebsco-cookies";
my $cache_path = "$config{storage_dir}/cache.json";

my $global_cache;
   {my $t = -e $cache_path && slurp $cache_path;
    $global_cache = from_json($t || '{}', {utf8 => 1});
    END
       {my $new_t = to_json $global_cache,
            {utf8 => 1, pretty => 1, canonical => 1};
        $t and $new_t eq $t or
           write_file $cache_path, $new_t;}}

my $ebsco_login = eval sprintf
    'sub { $_ = $_[0]; %s %s }', $config{ebsco_login}, "\n";
$@ and die "Error evaluating ebsco_login: $@";

# ------------------------------------------------------------
# * General
# ------------------------------------------------------------

our $verbose;
our $debug;
our $bypass_ebsco_cache;

my $ms_re = qr/(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|Spring|Summer|Fall|Autumn|Winter)/;
  # A month or season
my $suffix_re = qr/(?:Jr\.?|Sr\.?|III\b|IV\b|VI{0,3}\b(?!\.)|I?X\b(?!\.))/;

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

sub query_url
   {my $prefix = shift;
    my @a;
    push @a, sprintf '%s=%s',
            URI::Escape::uri_escape_utf8(shift),
            URI::Escape::uri_escape_utf8(shift)
        while @_;
    $prefix . '?' . join '&', @a;}

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
    $str}

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
        $str =~ / \A (.+?), \s+ (.+?) (?: < | , | \z) /x;
        my ($surn, $rest) = ($1, $2);
        $surn =~ /[[:lower:]]/
            or $surn = fix_allcaps_name $surn;
        # Add periods after initials, if necessary.
        $rest =~ /\A[[:upper:]](?: [[:upper:]])*\z/
            and $rest =~ s/\w\K/./g;
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
            foreach my $i (0 .. $#ws - 1)
               {if ($ws[$i] =~ /\.\z/ and $ws[$i + 1] !~ /\.\z/)
                   {return [@ws[0 .. $i]], [@ws[$i + 1 .. $#ws]];}}
            return [$ws[0]], [@ws[1 .. $#ws]];};
        #$str =~ /\A (\S) \S+ ((?: \s \S\.)*) \s+ (\S+) \z/x;
        $_ = join ' ', @$_ foreach $surn, $rest;
        χ family => $surn, given => $rest;}}

sub digest_journal_title
   {my $j = shift;
    $j =~ s/\AThe //;

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
    $j =~ /\AJournal of Psychology:/i
        and return 'The Journal of Psychology: Interdisciplinary and Applied';
    $j =~ /PLOS ONE/i
        and return 'PLOS ONE';

    if ($j =~ /Memory (?:and|&) Cognition/i
            or $j =~ /Psychology (?:and|&) Health/i)
       {$j =~ s/and/&/;}
    else
       {$j =~ s/&/and/;}
    $j =~ s/\b(An|And|As|At|But|By|Down|For|From|In|Into|Nor|Of|On|Onto|Or|Over|So|The|Till|To|Up|Via|With|Yet)\b/\l$1/g;
    if ($j =~ /\AJournal of Experimental Psychology/i or
        $j =~ /\AAmerican Economic Journal/i)
       {$j =~ s/\./:/}
    else
       {$j =~ s![/:.].+!!}
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
                    lc($sug) eq lc($lower) ? $sug : $lower;}}eg;}
        else
          # THE TITLE IS IN ALL CAPS.
           {$s =~ s {([^- .?!]+)} {fix_allcaps_word $1}eg;
            $s = ucfirst $s;}}
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
    $s eq 'New York' ? 'New York, NY'
      : $s eq 'Boston' ? 'Boston, MA'
      : $s eq 'Minneapolis' ? 'Minneapolis, MN'
      : $s eq 'London' ? 'London, UK'
      : $s eq 'Berlin' ? 'Berlin, Germany'
      : $s eq 'Beijing' ? 'Beijing, PRC'
      : $s}

sub format_isbn
   {my $s = shift;
    defined $s
      ? Business::ISBN->new($s)->as_isbn13->as_string
      : $s;}

sub citation
   {my %h = @_;
    defined $h{$_} or delete $h{$_}
        foreach keys %h;
    \%h;}

sub journal_article
   {my ($authors, $year, $article_title, $journal, $volume, $issue,
        $first_page, $last_page, $doi, $url) = @_;
    citation
        type => 'article-journal',
        author => $authors,
        issued => {'date-parts' => [[$year]]},
        title => format_nonjournal_title($article_title),
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
        'container-title' => $book,
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

# ------------------------------------------------------------
# * CrossRef
# ------------------------------------------------------------

sub query_crossref
   {my %p = @_;
    my $url = query_url 'http://www.crossref.org/openurl/',
        pid => $config{crossref_email},
        noredirect => 'true',
        map {$_ => $p{$_}} sort keys %p;
    progress 'Trying CrossRef';
    my $x = $global_cache->{crossref}{$url} ||= XMLin
        LWP::Simple::get($url),
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

sub get_doi
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

sub digest_crossref_contributors
   {σ
    map
       {# Add periods to initials.
        $_->{given_name} =~ s/ ([[:upper:]])\b(?!\.)/ $1./g;
        χ
            given => $_->{given_name},
            family => $_->{surname}}
    @{shift()}}

# ------------------------------------------------------------
# * EBSCOhost
# ------------------------------------------------------------

sub show_hash;
sub show_hash
   {my $x = shift;
    ref $x
      ? sprintf '{%s}', join ', ',
            map {"$_: " . show_hash $x->{$_}}
            sort keys %$x
      : apply {s/"/'/g} $x}

sub ebsco
# Allowed %terms:
#   author (array ref)
#   year (scalar)
#   title (array ref)
#   isbn (scalar)
#   doi (scalar) [not used for searching, but included in citation]
#   ebsco_record (hash ref with keys "db" and "AN")
   {my %terms = @_;

    progress 'Trying EBSCOhost';

    my %search_fields =
       (SearchTerm => join(' AND ',
            $terms{author} ? map {qq(AU "$_")} sort(@{$terms{author}}) : (),
            $terms{title} ? map {my $t = $_; $t =~ s/[?"“”]//g; qq(TI "$t")} sort(@{$terms{title}}) : (),
              # We remove question marks because they seem to
              # have special meaning but I can't figure out how
              # to escape them properly.
            $terms{isbn}
              ? sprintf('IB %s NOT PZ Chapter',
                    Business::ISBN->new($terms{isbn})->as_isbn10->as_string([]))
              : ()),
        $terms{year}
          ? ('common_DT1_FromYear' => $terms{year}, 'common_DT1_ToYear' => $terms{year})
          : (),
        $terms{ebsco_record} && %{$terms{ebsco_record}}
          ? (RECORD => $terms{ebsco_record})
          : ());

    my $cache_key = show_hash \%search_fields;
    $cache_key =~ s/\A\{//;
    $cache_key =~ s/\}\z//;
    $bypass_ebsco_cache
        and delete $global_cache->{ebsco}{$cache_key};
    my %record = η($global_cache->{ebsco}{$cache_key} ||= runsub
       {my $agent = new WWW::Mechanize
           (agent => 'Mozilla/5.0 (Windows NT 5.1; U; rv:5.0) Gecko/20100101 Firefox/5.0',
            cookie_jar => new HTTP::Cookies
               (file => $ebsco_cookie_jar_path,
                autosave => 1,
                ignore_discard => 1));

        # Get a session ID from the cookie jar, if it has one.
        my ($sid, $ebsco_domain, @ebsco_cookie);
        $agent->cookie_jar->scan(sub
           {defined $sid and return;
            my ($domain, $key, $val) = @_[4, 1, 2];
            $domain =~ m!\.ebscohost\.com\b! and $key eq 'EHost2'
                or return;
            $val =~ /(?:&|\A)sid=([^&]+)/ or die;
            $sid = uri_unescape $1;
            $ebsco_domain = $domain;
            @ebsco_cookie = @_;});

        my $query = sub
           {my ($base_url, $sid) = @_;
            if (exists $search_fields{RECORD})
               {$base_url =~ s/[a-z.]+(\.ebscohost\.)/search$1/ or die;
                $agent->get(query_url "$base_url/login.aspx",
                    direct => 'true',
                    db => $search_fields{RECORD}{db},
                    AN => $search_fields{RECORD}{AN});}
            else
               {$agent->get(query_url "$base_url/ehost/Search/PerformSearch",
                    sid => $sid,
                    PerformSearchSettingValue => 3,
                      # This seems to be necessary for EBSCO to
                      # pay attention to fields like the year.
                    %search_fields);}};
        if ($sid)
          # Try to just query.
           {$query->("http://$ebsco_domain", $sid);
            if ($agent->title !~ /: EBSCOhost\z/)
              # Rats, didn't work. Delete the cookie we used; it's
              # no good.
               {$sid = '';
                $ebsco_cookie[8] = 0;
                $agent->cookie_jar->set_cookie(@ebsco_cookie);}}
        if (!$sid)
          # We'll need to log in first.
           {progress 'Logging in';
            $ebsco_login->($agent);
            progress 'Querying';
            $query->("http://" . $agent->uri->host,
                $agent->current_form->value('__sid'));}

        my $page = $agent->content;
        ($sid) = $page =~ /"sid":"([^"]+)"/;
        $page =~ /class="smart-text-ran-warning"><span>Note: Your initial search query did not yield any results/
            || $page =~ /<span class="std-warning-text">No results were found/
            || $agent->title eq 'EBSCOhost'
            # No results.
            and return {};

        RESULTS: {if ($agent->title =~ /\AResult List: /)
           # We're looking at search results. Choose a record.
           {$page = $agent->content;
            my $results_uri = $agent->uri;
            my ($vid) = $page =~ /"vid":(\d+)/;
            $page =~ /Result_1/ or die;

            my %dbs =
                map {my $j = from_json decode_entities $_;
                     $j->{sourceCode} => $j}
                $page =~ /\bdata-eisSourceAgrs=\s*"([^"]+)"/g;

            for (my $i = 1 ; $page =~ /Result_$i/ ; ++$i)
               {# Avoid corrections. (I would just use "NOT PZ
                # Erratum/Correction" in the search string, but then
                # records with no "Document Type" field at all,
                # including some journal articles, would also be
                # excluded.)
                $page =~ m!Result_$i.+\[Erratum/Correction\]!
                    and next;
                # If the record we're looking at now is from
                # MEDLINE or SocINDEX, and there are PsycINFO
                # records available, switch to only PsycINFO.
                # (PsycINFO records are generally better.)
                my $db = do
                   {$page =~ /\bdata-hoverPreviewJson="([^"]+)" id="hoverPreview$i"/ or die;
                    from_json(decode_entities $1)->{db}};
                if ($db eq 'mnh' || $db eq 'sih' and
                        $dbs{psyh} and $dbs{psyh}{resultsRetrieved})
                   {progress 'Asking for PsycINFO records only';
                    # How EBSCO handles database-switching is a
                    # little kooky. We have to send a POST to say
                    # we want to change databases, then refresh
                    # the page to get the new results. We're faking
                    # Ajax.
                    $agent->post(
                        query_url(
                            sprintf('http://%s/ehost/IntegratedSearch/Update',
                                  $agent->uri->host),
                            sid => $sid,
                            vid => $vid),
                        'Content-Type' => 'application/json; charset=utf-8',
                        Content => '[{"hdnSourceCode":"psyh","chkbSelectSource":"psyh","hdnSourceSelected":true,"hdnHasBeenSearched":true}]');
                    $agent->content eq '{"redirectCommand":"results"}'
                        or die 'Bad reply from /IntegratedSearch/Update';
                    progress 'Getting new results page';
                    $agent->get($results_uri);
                    redo RESULTS;}
                # Okay, use this article.
                progress 'Fetching record';
                $agent->follow_link(name => "Result_$i");
                $page = $agent->content;
                last RESULTS;}

            die "all results are errata?";}}

        # Now we should be on a single record's page.
        $page =~ m!<a name="citation"><span>(.+?)\s*</span></a></dd>.*?<dt>(.+?)</div>!s
            or die;
        my ($title, $rows) = (decode_entities($1), $2);

        # Before returning the results, print full-text URLs
        # to STDERR.
        if ($page =~ /HTML Full Text/)
           {note 'Full text (HTML): ', $agent->uri;}
        if ($page =~ /PDF Full Text.+?__doPostBack\(&#39;(.+?)&#39;/)
           {my $a = $agent->clone;
            $a->submit_form(fields => {'__EVENTTARGET' => $1});
            note 'Full text (PDF): ', $a->uri;}
        if ($page =~ m!OpenIlsLink\?.+?su=http%3A(.+?)%26sid%3D!)
           {note 'OpenURL: http:', uri_escape
                uri_unescape($1),
                ':<>';}
        if ($page =~ /Linked Full Text.+?__doPostBack\(&#39;(.+?)&#39;/)
           {my $a = $agent->clone;
            $a->submit_form(fields => {'__EVENTTARGET' => $1});
            note 'Linked full text: ', $a->uri;}

        $page =~ /var ep = (\{.+?\})\n/ or die;
        my %clientdata = η from_json($1)->{clientData};
        return χ
            '-title' => $title,
            '-record' => $clientdata{plink},
            ($page =~ m!<p>~~~~~~~~</p><p[^>]*>By (.+?)\s*</p>!
              ? ('-by' => decode_entities($1))
              : ()),
            map {decode_entities $_}
                map {s/:\s*\z//; s/\s+\z//; $_}
                split /(?:<\/?d[tdl]>)+/, $rows;});

    %record or return err 'No results.';
    debug "EBSCO record: $record{'-record'}";

    # Parse the record.

    my $title = apply {s/\.\z//} $record{'-title'};

    my $authors = σ
        map {digest_author $_}
        $record{'-by'} && $record{Abstract} !~ /\bPsycINFO\b/ &&
              $record{'-by'} !~ /addressed to/ &&
              $record{'Source'} !~ /\AJournal of Sex Research/i
          ? $record{'-by'} =~ /[[:upper:]]{6}/
            ? split qr[(?:,|;| and| &) ],
                  apply {s/,\s+\S*[[:lower:]]{3}.+//}
                  $record{'-by'}
            : $record{'-by'} =~ / and .+?,.+?,/
              ? map {/(.+?),/; $1} split / and /, $record{'-by'}
              : split qr[(?:,|;| and| &) ], $record{'-by'}
          : map {apply {s/;.+//g}} split qr!<br />!, $record{Authors};

    my $rdoi;
    defined $record{'Digital Object Identifier'}
        and $record{'Digital Object Identifier'} =~ m!\b(10\.\d+[^<"]+)!
        and $rdoi = decode_entities $1;

    if (!$record{'Document Type'} and
        $record{'Publication Type'} =~ /\ABook;/)
       {$record{Source} =~ /\A \s*
                (?<place> [^:]+) : \s
                (?<publisher> [^0-9]+) ; \s
                (?<year> \d\d\d\d) \.
                /x
            or die "Book source: $record{Source}";
        my ($year, $place, $publisher) = @+{qw(year place publisher)};
        my $editors;
        if ($record{'Publication Type'} =~ /\bEdited Book\b/)
           {$editors = $authors;
            undef $authors;}
        my $isbn;
        exists $record{ISBN} and ($isbn) =
            $record{ISBN} =~ /([-0-9Xx]+)/;
        whole_book
            $authors, $year, $title, $editors, undef,
            undef, $place, $publisher,
            $terms{doi} || $rdoi,
              # We don't try hard to obtain a DOI, since most
              # books don't have DOIs, anyway.
            $isbn;}

    elsif (!$record{'Document Type'} or
        $record{'Document Type'} eq 'Article' or
        $record{'Document Type'} eq 'Journal Article' or
        $record{'Document Type'} eq 'Comment/Reply' or
        $record{'Document Type'} eq 'Editorial')

       {if ($record{Source} =~ /\A[^0-9,;]+,(?: \w\w\w)? \d+, \d\d\d\d\.(?: pp?\. (\d+)-?(\d*)\.)?\z/
            || $record{Authors} =~ /\bet al\./i
               and $rdoi)
           # This record is impoverished. Let's try CrossRef.
           {my %d = (first_page => $1, last_page => $2, from_doi $rdoi);
            return journal_article
                +($record{Authors} =~ /\bet al\./i
                  ? digest_crossref_contributors($d{contributors})
                  : $authors),
                $d{year}, $title, $d{journal_title},
                $d{volume}, $d{issue}, $d{first_page}, $d{last_page},
                $rdoi, undef;}
        my $year;
        if ($record{Source} =~ s{,?\s+\d{1,2}/\d{1,2}/(\d{4})}{})
           {$year = $1;}
        elsif ($record{Source} =~ s/,?\s+$ms_re(?:-$ms_re)?(\d\d(\d\d)?)//)
           {$year = $2 ? $1 : "19$1";}
        $record{Source} =~ s{
                \s+
                (?: Vol \.? \s (?<volume> \d+) [A-Z]* |
                  (?<volume> \d+) [A-Z]* (?= \( ) )
                \s*
                (?: \(?
                       (?<issue_type> Issue | Suppl | Pt | Whole \s No\.)
                        \s
                        (?<issue> \d+ (?: / \d+)?)
                        \)? |
                    \( (?<issue> [-,. 0-9A-Za-z]+ ) \) )?
                [.,] \s+
                } {✠}x
            or die "Source: $record{Source}";

        my $volume = $+{volume};
        my $issue = $+{issue};
        if (defined $issue)
           {defined $+{issue_type} and $+{issue_type} eq 'Suppl'
                and $issue = "Suppl. $issue";
            $issue =~ /No\.\s*(.+)/ and $issue = $1;
            $issue =~ s/\.(\S)/. $1/;
            $issue =~ s! (\d+) [-/] (\d+) !$1, $2!x;}
              # Dunno if *that's* right, but it seems the most
              # reasonable alternative.
        my ($journal, $fpage, $lpage);
        if ($record{Source} =~ s! \[? (PL[oO]S \s \w+) !!x)
           {$journal = digest_journal_title $1;
            $volume = undef;
            $issue = undef;}
        else
           {$record{Source} =~ s! \A (.+?) \s* (?: \[ | \( | ; | / | \.?,✠ ) !!x or die 's2';
            $journal = digest_journal_title $1;
            ($fpage, $lpage) =
                $record{Source} =~ s!p(?:p\. )?([A-Z]?\d+)-([A-Z]?\d+)!!
              ? ($1, $2)
              : $record{Source} =~ s!p(?:p\. )?([A-Z]?)(\d+).+?(\d+)p\b!!
              ? ("$1$2", $1 . ($2 + $3 - 1))
              : $record{Source} =~ s!p(?:p\. )?([A-Z]?\d+)!!
              ? ($1, undef)
              : die 'p';
            $lpage = expand_last_page_number $fpage, $lpage;}
        $year ||=
            $record{Source} =~ /(?<!: )((?:1[6789]|20)\d\d)/
          ? $1
          : die 'y';
        my $doi;
        $doi ||= $rdoi || $terms{doi} || get_doi
            $year, $journal, $title,
            $authors->[0]{family}, $volume,
            $fpage ||
                ($record{Source} =~ /\bpp\. (e\d+)\./ ? $1 : undef);
              # In this last case, we aren't providing a real
              # page number, but CrossRef benefits from it,
              # anyway.
        my $url;
        lc($journal) eq 'judgment and decision making'
          # This is an open-access journal, but it doesn't have
          # DOIs, so get a URL.
            and $url = sjdm_url_from_title($title);
        lc($journal) eq 'evolutionary psychology'
          # Same deal.
            and $url = evpsych_url_from_title($title);

        return journal_article $authors, $year, $title,
            $journal, $volume, $issue, $fpage, $lpage, $doi, $url;}

    elsif ($record{'Document Type'} eq 'Chapter')

       {$record{Source} =~ m{
            \A (?<book> [^.(]+?)
            (?: \s \( (?<edition> [^)]+) \) )?
            (?: \. | , \s vol\. ) \s
            (?: (?<volume> \d+)
                (?: \. | : \s [^.]+ \.)
            \s)?
            (?<editors> .+?) \s \(Ed\) ; \s
            (?<place> [^,:]+, \s [^,:]+), \s [^,:]+ : \s
            (?<publisher> [^;]+) ; \s
            (?<year> \d\d\d\d) \.
            \s (?<fpage> \d+) - (?<lpage> \d+) }x or die 'chapter';
        my %src = %+;

        if (exists $record{'Parent Book Series'}
                and $record{'Parent Book Series'} =~ /\A(Annals of The New York Academy of Sciences), Vol\. (\d+)/i)
          # Annals of the NYAS is actually a journal.
           {my ($journal, $volume) = ($1, $2);
            my $doi = $rdoi || $terms{doi} || get_doi
                $src{year}, $journal, $title,
                $authors->[0]{family}, $volume, $src{fpage};
            return journal_article $authors, $src{year}, $title,
                'Annals of the New York Academy of Sciences',
                $volume, undef, $src{fpage}, $src{lpage}, $doi, undef;}

        (my $book = $src{book}) =~ s/:  /: /;
        $src{volume} and $book =~ s/, Vol\z//;
        my $editors = σ
           map {digest_author $_}
           split qr/ \(Ed\); /, $src{editors};

        my $isbn;
        exists $record{ISBN} and ($isbn) =
            $record{ISBN} =~ /([-0-9Xx]+)/;

        return book_chapter $authors, $src{year}, $title,
            $editors, $book, $src{volume}, $src{edition},
            $src{fpage}, $src{lpage},
            $src{place}, $src{publisher}, $isbn;}

    else
       {die qq(Can't handle document type "$record{'Document Type'}");}}

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

    my $url = query_url 'http://catalog.loc.gov/vwebv/search',
        do
           {my ($i, @a) = 0;
            my $add = sub
               {my ($field, $s) = @_;
                ++$i;
                $s = lc $s;
                $s =~ tr/"?%//;
                push @a,
                    "searchArg$i" => $s,
                    "searchCode$i" => $field,
                    "argType$i" => 'phrase',
                    "combine$i" => 'and';};
            if ($terms{author})
               {$add->('KPNC', $_) foreach sort @{$terms{author}};}
            if ($terms{title})
               {$add->('KTIL', $_) foreach sort @{$terms{title}};}
            if ($terms{isbn})
               {$add->('KNUM', Business::ISBN->new($terms{isbn})
                    ->as_isbn13->as_string([]));}
            @a},
        $terms{year}
          ? (yearOption => 'range',
                fromYear => $terms{year}, toYear => $terms{year})
          : (),
        type => 'a?', # Textual items only (to exclude, e.g., movies)
        searchType => 2;

    my %record = η($global_cache->{congress}{$url} ||= runsub
       {my $agent = new WWW::Mechanize;
        $agent->get($url);

        $agent->content =~ m!<strong>Your search found no results.</strong>!
            and return {};

        if ($agent->title eq 'LC Online Catalog - Titles List')
           {progress 'Fetching record';
            $agent->follow_link(url_regex => qr/\AholdingsInfo\?/);}

        my $page = $agent->content;
        $page =~ s!<table \s class="briefRecord"> (.+?) </table>!!xs or die;
        my $table = $1;
        my %f = map {decode_entities $_}
           ($table =~ m!<th[^>]*>([^<]+)</th>.+?="subfieldData">\s*([^<]+[^< ])!sg,
            $page =~ m!<h2>([^<]+)</h2>.+?="subfieldData">\s*([^<]+[^< ])!sg);
        $f{'Related names'} = $page =~ m!<h2>Related names</h2>\s*<ul>(.+?)</ul>!s
          ? [map {decode_entities $_} $1 =~ /="subfieldData">\s*([^<]+)/g]
          : [];

        \%f;});

    %record or return err 'No results.';

    my ($authors, $editors);
    ($record{'Main title'} =~ / editors?\.\z/ ||
              $record{'Main title'} =~ m!/ edited by !
          ? $editors : $authors) = σ
        map {digest_author $_}
        grep {! /\. Convention/}
        grep {defined}
        $record{'Personal name'}, α $record{'Related names'};
    $record{'Published/Created'} =~ /\A([^:]+) : ([^,]+), (?:\d\d\d\d, )?c?(\d\d\d\d)(?:\.|-\S+)\z/
        or $record{'Published/Created'} =~ /\A([^,]+), ([^\[]+) \[(\d\d\d\d)\]\z/
        or die 'pc';
    my ($place, $publisher, $year) = ($1, $2, $3);
    $record{'Main title'} =~ m!\A([^/]+) /! or
        $record{'Main title'} =~ m!\A(.+?), by! or
        die 'mt';
    my $book = $1;
    my $volume; # TODO: I need some examples of multi-volume works.
    my $edition = $record{Edition};
    $edition and $edition =~ s/\s*\bed\.?//i;
    my $isbn;
    if (exists $record{ISBN})
       {$record{ISBN} =~ /\A([-0-9X]+)/ or die 'isbn';
        $isbn = $1;}

    return whole_book
        $authors, $year, $book, $editors, $volume,
        $edition, $place, $publisher, undef, $isbn;}

# ------------------------------------------------------------
# * IDEAS
# ------------------------------------------------------------

my %ideas_categories =
   (articles => 'a',
    chapters => 'h',
    books => 'b');

sub ideas
# Allowed %terms:
#   keywords (array ref)
#   year (scalar)
#   doi (scalar) [not used for searching, but included in citation]
   {my %terms = @_;

    progress 'Trying IDEAS';

    # Query.

    my $url = query_url 'http://ideas.repec.org/cgi-bin/htsearch',
        'q' => join(' ', sort @{$terms{keywords}}),
        ul => "%/$ideas_categories{articles}/%",
        ul => "%/$ideas_categories{chapters}/%",
        ul => "%/$ideas_categories{books}/%",
        !$terms{year} ? () :
           (dt => 'range',
            db => "01/01/$terms{year}",
            de => "31/12/$terms{year}");

    my %record = η($global_cache->{ideas}{$url} ||= do
     {my $results = LWP::Simple::get($url);
        if ($results =~ /Sorry, your search for/)
          # No results.
           {χ;}
        else
          # Use the first result.
           {$results =~ /<DT>1\.\s+<a href="(.+?)"/ or die;
            progress 'Fetching record';
            my $page = LWP::Simple::get($1);
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
                     # but I think that's the only case in which a middle
                     # initials would be omitted.
            \%meta;}});

    keys %record or return err 'No results.';

    # Parse the record.

    my $authors = σ
        map {digest_author $_}
        split /;\s+/, $record{authors};

    my $journal = digest_journal_title $record{journal_title};

    my ($fpage, $lpage) = ($record{firstpage}, $record{lastpage});
    $lpage = expand_last_page_number $fpage, $lpage;

    my $doi = $terms{doi} || get_doi
        $record{year}, $record{journal_title}, $record{title},
        $authors->[0]{family},
        $record{volume}, $fpage;

    return journal_article
        $authors, $record{year}, $record{title},
        $journal, $record{volume}, $record{issue},
        $fpage, $lpage, $doi, undef;}

# ------------------------------------------------------------
# * Society for Judgment and Decision-Making
# ------------------------------------------------------------

sub sjdm_url_from_title
   {my $title = shift;
    progress 'Trying SJDM';
    my $v = $global_cache->{sjdm}{lc($title)} ||= do
       {my $page = LWP::Simple::get(query_url
            'http://www.sjdm.org/cgi-bin/namazu.cgi',
            max => 10, result => 'normal', sort => 'score',
            idxname => 'journal',
            query => "{$title}");
          # In Namazu, curly braces signify an exact match.
          # http://www.namazu.org/doc/manual.html#query-phrase
        $page =~ m!<dd><a href="/home/baron/public_html/journal/(.+?)">!
          ? $1
          : undef};
    defined $v
      ? "http://journal.sjdm.org/$v"
      : err 'No results.';}

# ------------------------------------------------------------
# * Evolutionary Psychology
# ------------------------------------------------------------

sub evpsych_url_from_title
   {my $title = shift;
    $title =~ s/'/’/;
    'http://www.epjournal.net/articles/' .
        URI::Escape::uri_escape_utf8(lc join '-', $title =~ /((?:’|\w)+)/g);}

# ------------------------------------------------------------
# * Public interface
# ------------------------------------------------------------

sub get
# Allowed %terms:
#   author (array ref)
#   year (scalar)
#   title (array ref)
#   isbn (scalar)
#   doi (scalar)
#   ebsco_record (hash ref with keys "db" and "AN")
# Returns a hashref of CSL input data or undef.
   {my %terms = @_;
    first {$_ and !ref || (ref eq 'ARRAY' and @$_) || (ref eq 'HASH' and %$_)} values %terms
        or return err 'No search terms.';
    $terms{author} ||= [];
    $terms{title} ||= [];

    if ($terms{doi})
      # When we're starting with a DOI, we use CrossRef only to
      # get information to plug into other databases (and not to
      # generate citations directly) because CrossRef tends to be
      # less complete than, e.g., PsycINFO.
       {my %d = from_doi $terms{doi};
        $terms{author} = σ map {$_->{surname}} α $d{contributors};
        $terms{year} = $d{year};
        my $title = $d{article_title} || $d{volume_title};
        $title and $terms{title} = σ $title;
        $terms{doi} = $d{doi};}
    ebsco %terms or congress %terms or ideas
        keywords => [@{$terms{author}}, @{$terms{title}}],
        year => $terms{year},
        doi => $terms{doi};}

sub digest_ris
   {my $ris = Citematic::RIS->new(shift);

    $ris->ris_type eq 'JOUR'
        or die sprintf q(Can't handle RIS type "%s"), $ris->ris_type;

    my $authors = σ map {digest_author $_}
        (ref $ris->authors ? α $ris->authors : $ris->authors);
    my ($year) = ($ris->PY || $ris->Y1) =~ /\A(\d+)/;
    my $title = $ris->TI || $ris->T1;
    my $journal = digest_journal_title($ris->JO || $ris->JF || $ris->T2);
    my ($fpage, $lpage) =
        $ris->starting_page =~ /[-–]/
      ? split /[-–]/, $ris->starting_page
      : ($ris->starting_page, $ris->ending_page);
    my $volume = $ris->volume;
    my $issue = $ris->issue;
    defined and s/\s+\z//
        foreach $volume, $issue, $fpage, $lpage;

    my $doi = $ris->doi;
    if (!$doi and $ris->M3
            and $ris->M3 =~ /\A10\./ || $ris->M3 =~ /\bdoi\b/)
       {$doi = $ris->M3;}
    $doi
        and ($doi) = $doi =~ /\b(10\.\S+)/;
    my $url;
    if ($doi and $doi =~ m!\A10\.2307!)
      # This is a JSTOR record, which may have a fake DOI.
      # https://forums.zotero.org/discussion/6812/jstor-and-false-doi-numbers/
       {undef $doi;
        $url = $ris->UR;}

    journal_article
        $authors, $year, $title, $journal,
        $volume, $issue,
        $fpage, $lpage,
        $doi, $url;}

1;
