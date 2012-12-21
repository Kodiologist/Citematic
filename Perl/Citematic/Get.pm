#!/usr/bin/perl
package Citematic::Get;

use utf8;
use warnings;
use strict;

use Encode;
use List::Util 'first';
use LWP::Simple ();
use WWW::Mechanize;
use HTTP::Cookies;
use URI::Escape;
use HTML::Entities 'decode_entities';
use Text::Aspell;
use JSON qw(from_json to_json);
use File::Slurp qw(slurp write_file);
use XML::Simple 'XMLin';

use parent 'Exporter';
our @EXPORT_OK = 'get';

use constant CONFIG_PATH => "$ENV{HOME}/.citematic";

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

sub tail {@_[1..$#_]}

# ------------------------------------------------------------
# Get configuration
# ------------------------------------------------------------

-e CONFIG_PATH or die 'No configuration file found at ', CONFIG_PATH;

our %config =
    tail split /(?:\A|\n{2,})\[(.+?)\]\n/, slurp CONFIG_PATH;

-e $config{storage_dir} or mkdir $config{storage_dir} or die "Couldn't create $config{storage_dir}: $!";
$config{storage_dir} =~ s!/\z!!;

my $ebsco_post_path = "$config{storage_dir}/ebscopost";
my $ebsco_cookie_jar_path = "$config{storage_dir}/ebsco-cookies";
my $cache_path = "$config{storage_dir}/cache";

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
# General
# ------------------------------------------------------------

our $verbose;
our $debug;
our $bypass_ebsco_cache;

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
        $str =~ s/,?\s+(Jr\.|Sr\.|III\b|IV\b|VI{0,3}\b|I?X\b)(?!\.)//i
            and @suffix = (suffix => $1);
        $str =~ / \A (.+?), \s+ (.+?) (?: < | , | \z) /x;
        my ($surn, $rest) = ($1, $2);
        $surn =~ /[[:lower:]]/ or $surn = fix_allcaps_name $surn;
        χ family => $surn, given => $rest, @suffix;}
    elsif ($str =~ /[[:lower:]]\s+[[:upper:]]{1,4}\z/)
      # We have something of the form "Smith AR".
       {$str =~ s/\s+([[:upper:]]+)\z//;
        χ family => $str, given => join(' ', map {"$_."} split //, $1);}
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
    $j eq 'American Statistician'
        and return 'The American Statistician';
    $j =~ /\AJournal of Psychology:/i
        and return 'The Journal of Psychology: Interdisciplinary and Applied';
    $j =~ /PLoS ONE/i
        and return 'PLoS ONE';

    if ($j =~ /Memory (?:and|&) Cognition/i
            or $j =~ /Psychology (?:and|&) Health/i)
       {$j =~ s/and/&/;}
    else
       {$j =~ s/&/and/;}
    $j =~ s/\b(An|And|As|At|But|By|Down|For|From|In|Into|Nor|Of|On|Onto|Or|Over|So|The|Till|To|Up|Via|With|Yet)\b/\l$1/g;
    $j =~ s!(?:/|:).+!!
        unless $j =~ /\AJournal of Experimental Psychology/i;
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
    if (matches(qr/\b[[:upper:]]/, $s) /
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
    # Insert a space and capitalize after colons.
    $s =~ s/([:?])\W+(\w)/$1 . ' ' . uc $2/ge;
    # Correct GNU-style single quotes that should be double quotes.
    $s =~ s/`([^`']+)'/"$1"/g;
    # Correct matched single quotes that should be double quotes.
    $s =~ s/(\W|\A)'([^`' ][^`']*[^`' ])'(\W|\z)/$1"$2"$3/g;
    # Correct fake ellipses.
    $s =~ s/\.\.\./…/g;
    $s;}

sub format_publisher
   {my $s = shift;
    $s =~ s/ Publishing Co\z| Associates\z//;
    $s;}

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
        'publisher-place' => $place,
        publisher => format_publisher($publisher),
        ISBN => $isbn;}

# ------------------------------------------------------------
# CrossRef
# ------------------------------------------------------------

sub query_crossref
   {my $url = query_url 'http://www.crossref.org/openurl/',
        pid => $config{crossref_email},
        noredirect => 'true',
        @_;
    progress 'Trying CrossRef';
    my $x = $global_cache->{crossref}{$url} ||= XMLin
        LWP::Simple::get($url),
        ForceArray => ['contributor', 'year'],
        GroupTags => {contributors => 'contributor'};
    $x = $x->{query_result}{body}{query};
    exists $x->{contributors}
        or return err 'No results.';
    $x = {%$x}; # Don't modify the thing we're caching.
    $x->{contributors} = σ grep {$_->{surname} ne 'et al'} α $x->{contributors};
    $x->{year} =
        (first {ref and $_->{media_type} eq 'print'} α $x->{year}) ||
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
            title => $journal,
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
    grep {$_->{contributor_role} eq 'author'}
    @{shift()}}

# ------------------------------------------------------------
# EBSCOhost
# ------------------------------------------------------------

sub ctl
   {'ctl00$ctl00$MainContentArea$MainContentArea$' . join '$', @_;}

sub ebsco
# Allowed %terms:
#   author (array ref)
#   year (scalar)
#   title (array ref)
#   doi (scalar) [not used for searching, but included in citation]
   {my %terms = @_;

    progress 'Trying EBSCOhost';

    my %search_fields =
       (ctl('findField', 'SearchTerm1') => join(' AND ',
            $terms{author} ? map {qq(AU "$_")} α $terms{author} : (),
            $terms{title} ? map {my $t = $_; $t =~ s/[?"“”]//g; qq(TI "$t")} α $terms{title} : ()),
              # We remove question marks because they seem to
              # have special meaning but I can't figure out how
              # to escape them properly.
        $terms{year}
          ? ('common_DT1_FromYear' => $terms{year}, 'common_DT1_ToYear' => $terms{year})
          : ());

    my $cache_key = to_json
        \%search_fields, {utf8 => 1, canonical => 1};
    $bypass_ebsco_cache
        and delete $global_cache->{ebsco}{$cache_key};
    my %record = η($global_cache->{ebsco}{$cache_key} ||= runsub
       {my $agent = new WWW::Mechanize
           (agent => 'Mozilla/5.0 (Windows NT 5.1; U; rv:5.0) Gecko/20100101 Firefox/5.0',
            cookie_jar => new HTTP::Cookies
               (file => $ebsco_cookie_jar_path,
                autosave => 1,
                ignore_discard => 1));

        if (-e $ebsco_post_path)
          # Try to just query.
           {my ($action_url, $saved_fields) =
                α from_json slurp($ebsco_post_path), {utf8 => 1};
            $agent->post($action_url, {@$saved_fields, %search_fields});}
        if (!(-e $ebsco_post_path)
            || $agent->title !~ /\AEBSCOhost: (?:Basic Search|Result List)/)
          # We'll need to log in first.
           {progress 'Logging in';
            $ebsco_login->($agent);

            # Now we're at the search screen. Save the form details
            # for quicker querying in the future.
            write_file $ebsco_post_path, to_json
                σ
                   ($agent->current_form->action . '',
                    σ
                        ctl('findField', 'SearchButton') =>
                            $agent->current_form->value(ctl 'findField', 'SearchButton'),
                        $agent->current_form->form),
                {utf8 => 1};
            progress 'Querying';
            $agent->submit_form
               (button => ctl('findField', 'SearchButton'),
                fields => \%search_fields);}

        my $page = $agent->content;
        $page =~ /class="smart-text-ran-warning"><span>Note: Your initial search query did not yield any results/
            || $page =~ /<span class="std-warning-text">No results were found/
            # No results.
            and return {};
        $page =~ /Result_1/ or die;
        # Use the first result that isn't just a correction. I
        # would just use "NOT PZ Erratum/Correction" in the
        # search string, but then records with no "Document Type"
        # field at all, including some journal articles, would
        # also be excluded.
        for (my $i = 1 ; $page =~ /Result_$i/ ; ++$i)
           {$page =~ m!Result_$i.+\[Erratum/Correction\]! and next;
            progress 'Fetching record';
            $agent->follow_link(name => "Result_$i");
            $page = $agent->content;
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
            if ($page =~ m!OpenIlsLink\(.+?su=http%3A(.+?)'!)
               {note 'OpenURL: http:', uri_escape
                    uri_unescape($1),
                    ':<>';}
            if ($page =~ /Linked Full Text.+?__doPostBack\(&#39;(.+?)&#39;/)
               {my $a = $agent->clone;
                $a->submit_form(fields => {'__EVENTTARGET' => $1});
                note 'Linked full text: ', $a->uri;}
            return χ
                '-title' => $title,
                '-record' => $page =~ /"plink":"(.+?)"/,
                ($page =~ m!<p>~~~~~~~~</p><p[^>]*>By (.+?)\s*</p>!
                  ? ('-by' => decode_entities($1))
                  : ()),
                map {decode_entities $_}
                    map {s/:\s*\z//; s/\s+\z//; $_}
                    split /(?:<\/?d[tdl]>)+/, $rows;}
        # No results.
        {};});

    %record or return err 'No results.';
    debug "EBSCO record: $record{'-record'}";

    # Parse the record.

    my $title = apply {s/\.\z//} $record{'-title'};

    my $authors = σ
        map {digest_author $_}
        $record{'-by'} && $record{Database} ne 'PsycINFO' &&
              $record{'-by'} !~ /addressed to/ &&
              $record{'Source'} !~ /\AJournal of Sex Research/i
          ? $record{'-by'} =~ /[[:upper:]]{6}/
            ? split qr[(?:,|;| and| &) ],
                  apply {s/,\s+\S*[[:lower:]]{3}.+//}
                  $record{'-by'}
            : $record{'-by'} =~ / and .+?,.+?,/
              ? map {/(.+?),/; $1} split / and /, $record{'-by'}
              : split qr[(?:,|;| and| &) ], $record{'-by'}
          : split qr[\s*;\s*|<br />], $record{Authors};

    defined $record{'Digital Object Identifier'}
        and $record{'Digital Object Identifier'} =~ s/(?:\x{0d}|\x{0a}|<br).*//s;

    if (!$record{'Document Type'} or
        $record{'Document Type'} eq 'Article' or
        $record{'Document Type'} eq 'Journal Article' or
        $record{'Document Type'} eq 'Comment/Reply' or
        $record{'Document Type'} eq 'Editorial')

       {if ($record{Source} =~ /\A[^0-9,;]+,(?: \w\w\w)? \d+, \d\d\d\d\.(?: pp?\. (\d+)-?(\d*)\.)?\z/
            || $record{Authors} =~ /\bet al\./i
               and $record{'Digital Object Identifier'})
           # This record is impoverished. Let's try CrossRef.
           {my %d = from_doi $record{'Digital Object Identifier'};
            return journal_article
                +($record{Authors} =~ /\bet al\./i
                  ? digest_crossref_contributors($d{contributors})
                  : $authors),
                $d{year}, $title, $d{journal_title},
                $d{volume}, $d{issue}, $d{first_page} || $1, $d{last_page} || $2,
                $record{'Digital Object Identifier'}, undef;}
        my $year;
        if ($record{Source} =~ s{,?\s+\d{1,2}/\d{1,2}/(\d{4})}{})
           {$year = $1;}
        elsif ($record{Source} =~ s/,?\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)(\d\d(\d\d)?)//)
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
                , \s+
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
        if ($record{Source} =~ s! \[ (PLoS [^\]]+?) \] !!x)
           {$journal = digest_journal_title $1;
            $volume = undef;
            $issue = undef;}
        else
           {$record{Source} =~ s! \A (.+?) \s* (?: \[ | \( | ; | / | ,✠ ) !!x or die 's2';
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
            $record{Source} =~ /(?<!:.)((?:1[6789]|20)\d\d)/
          ? $1
          : die 'y';
        my $doi = $record{'Digital Object Identifier'} ||
            $terms{doi} ||
            get_doi
                $year, $journal, $title,
                $authors->[0]{family}, $volume, $fpage;
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
            (?<editors> .+?) \s \(Ed\.\); \s
            pp\. \s (?<fpage> \d+) - (?<lpage> \d+) \. \s
            (?<place> [^,:]+, \s [^,:]+), \s [^,:]+: \s
            (?<publisher> [^,]+) , \s
            (?: [^,]+ , \s)?
            (?<year> \d\d\d\d) \.}x or die 'chapter';
        my %src = %+;

        if (exists $record{'Parent Book Series'}
                and $record{'Parent Book Series'} =~ /\A(Annals of The New York Academy of Sciences), Vol\. (\d+)/i)
          # Annals of the NYAS is actually a journal.
           {my ($journal, $volume) = ($1, $2);
            my $doi =
                $record{'Digital Object Identifier'} ||
                $terms{doi} ||
                get_doi
                    $src{year}, $journal, $title,
                    $authors->[0]{family}, $volume, $src{fpage};
            return journal_article $authors, $src{year}, $title,
                'Annals of the New York Academy of Sciences',
                $volume, undef, $src{fpage}, $src{lpage}, $doi, undef;}

        (my $book = $src{book}) =~ s/:  /: /;
        $src{volume} and $book =~ s/, Vol\z//;
        my $editors = σ
           map {digest_author $_}
           split / \(Ed\.\); /, $src{editors}; # /

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
# IDEAS
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
        'q' => join(' ', α $terms{keywords}),
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
# Society for Judgment and Decision-Making
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
        write_file '/tmp/bond.html', $page;
        $page =~ m!<dd><a href="/home/baron/public_html/journal/(.+?)">!
          ? $1
          : undef};
    defined $v
      ? "http://journal.sjdm.org/$v"
      : err 'No results.';}

# ------------------------------------------------------------
# Evolutionary Psychology
# ------------------------------------------------------------

sub evpsych_url_from_title
   {my $title = shift;
    $title =~ s/'/’/;
    'http://www.epjournal.net/articles/' .
        URI::Escape::uri_escape_utf8(lc join '-', $title =~ /((?:’|\w)+)/g);}

# ------------------------------------------------------------
# Public interface
# ------------------------------------------------------------

sub get
# Allowed %terms:
#   author (array ref)
#   year (scalar)
#   title (array ref)
#   doi (scalar)
# Returns a hashref of CSL input data or undef.
   {my %terms = @_;
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
        $terms{title} = σ $d{article_title};
        $terms{doi} = $d{doi};}
    ebsco %terms or ideas
        keywords => [@{$terms{author}}, @{$terms{title}}],
        year => $terms{year},
        doi => $terms{doi};}

1;
