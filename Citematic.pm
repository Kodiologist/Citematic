#!/usr/bin/perl
package Citematic;

use feature qw(say state);
use utf8;
use Kodi qw(:symbolic apply matches runsub);
use warnings;
use strict;

use Encode;
use LWP::Simple;
use WWW::Mechanize;
use HTTP::Cookies;
use URI::Escape;
use HTML::Entities 'decode_entities';
use Lingua::EN::Titlecase;
use Text::Aspell;
use JSON qw(from_json to_json);
use File::Slurp qw(slurp write_file);
use XML::Simple 'XMLin';

use parent 'Exporter';
our @EXPORT = 'apa';

my $crossref_email = join '@', reverse 'example.com', 'somebody';
my $ebsco_login_url = 'http://search.ebscohost.com.libproxy.cc.stonybrook.edu/login.aspx?authtype=ip,uid&profile=ehost&defaultdb=' .
    join ',',
    # EBSCO databases to search
    'psyh',  # PsycINFO
    'pdh',   # PsycARTICLES
    'mnh';   # MEDLINE
my $sbu_login_url = 'https://libproxy.cc.stonybrook.edu/login';
my $sbu_netid = 'karfer';
my $sbu_password = 'hunter2';
my $ebsco_post_path = '/home/hippo/Data/citematic-ebscopost';
my $ebsco_cookie_jar_path = '/home/hippo/Data/citematic-ebsco-cookies';
our $cache_path = '/home/hippo/Data/citematic-cache';

# ------------------------------------------------------------
# General
# ------------------------------------------------------------

# UTF-8 nonsense
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

my $global_cache;
   {my $t = -e $cache_path && slurp $cache_path;
    $global_cache = from_json($t || '{}', {utf8 => 1});
    END
       {my $new_t = to_json $global_cache,
            {utf8 => 1, pretty => 1, canonical => 1};
        $t and $new_t eq $t or
           write_file $cache_path, $new_t;}}

my $speller = new Text::Aspell;

our $verbose;

sub progress
   {$verbose and say STDERR @_, '…';}

sub err
   {$verbose and say STDERR @_;
    return undef;}

sub warning
   {$verbose and say STDERR 'WARNING: ', @_;}

sub query_url
   {my $prefix = shift;
    my @a;
    push @a, uri_escape_utf8(shift) . '=' . uri_escape_utf8(shift) while @_;
    $prefix . '?' . join '&', @a;}

sub fix_allcaps
   {my $all_low = lc shift;
    if ($speller->check($all_low))
       {$all_low;}
    else
       {my $sug = ($speller->suggest($all_low))[0];
        lc($sug) eq $all_low ? $sug : $all_low;}}

sub digest_author
   {my $str = shift;
    if ($str =~ /,/)
      # We have something of the form "Smith, A. R." or "Smith,
      # Allen R." or "Smith, Allen Reginald" or even "Smith, A.
      # Reginald".
       {my $suffix = $str =~ s/,?\s+(Jr\.|Sr\.)//i ? $1 : '';
        $str =~ / \A (.+?), \s+ (.+?) (?: < | , | \z) /x;
        my ($surn, $rest) = ($1, $2);
        $rest =~ s/\w\K.+?( |\z)/.$1/g;
        $surn =~ /[[:lower:]]/ or $surn = ucfirst fix_allcaps $surn;
        [$surn, $rest, $suffix];}
    elsif ($str =~ /[[:upper:]]\z/)
      # We have something of the form "Smith AR".
       {$str =~ s/ \A (.+?) \s+ ([[:upper:]]) /$2/x;
        [$1, join(' ', map {"$_."} split //, $str), ''];}
    else
      # We have something of the form "Allen R. Smith".
       {$str =~ /\A (\S) \S+ ((?: \s \S\.)*) \s+ (\S+) \z/x;
        [$3, "$1.$2", ''];}}

sub digest_journal_title
   {my $j = shift;
    $j =~ /Proceedings of the National Academy of Sciences of the United States of America/i
        and return 'Proceedings of the National Academy of Sciences';
    $j =~ /IEEE Transactions on Systems/i
        and return 'IEEE Transactions on Systems, Man, and Cybernetics';
    if ($j =~ /Memory (?:and|&) Cognition/i
            or $j =~ /Psychology (?:and|&) Health/i)
       {$j =~ s/and/&/;}
    else
       {$j =~ s/&/and/;}
    $j =~ /\AJournal of Experimental Psychology/i
        or $j =~ s!(?:/|:).+!!;
    $j;}

sub expand_last_page_number
   {my ($first, $last) = @_;
    $last and length $last < length $first
      ? # The last page number has fewer digits than the first,
        # so append the appropriate prefix.
        substr($first, 0, length($first) - length($last)) . $last
      : $last;}

sub format_nonjournal_title
   {my $s = shift;
    if (matches(qr/\b[[:upper:]]/, $s) /
        matches(qr/\b\S/, $s) > 1/2)
       {warning 'The article title may be miscapitalized.';
        # But we'll try to fix it.
        if ($s =~ /[[:lower:]]/)
          # The Title Is Probably Capitalized Like This.
           {$s =~ s {[- ]\K([[:upper:]])([^- ]+)}
               {my $lower = lc($1) . $2;
                if ($speller->check($lower))
                   {$lower;}
                else
                   {my $sug = ($speller->suggest($lower))[0];
                    lc($sug) eq lc($lower) ? $sug : $lower;}}eg;}
        else
          # THE TITLE IS IN ALL CAPS.
           {$s =~ s {([^- .?!]+)} {fix_allcaps $1}eg;
            $s = ucfirst $s;}}
    $s =~ s/(:\W+)(\w)/': ' . uc $2/ge;
    $s;}

sub end_sentence
   {$_[0] =~ /[?!.]\z/ ? $_[0] : "$_[0]."}

sub format_publisher
   {my $s = shift;
    $s =~ s/ Publishing Co\z| Associates\z//;
    $s;}

sub format_authors
   {my @authors = map
        {"$_->[0], $_->[1]" . ($_->[2] ? ", $_->[2]" : '')}
        α shift;
    @authors == 1
      ? $authors[0]
      : join ', ',
          @authors[0 .. $#authors - 1],
          '& ' . $authors[-1];}

sub apa_journal_article
   {my ($authors, $year, $article_title, $journal, $volume,
        $first_page, $last_page, $doi) = @_;
    sprintf '%s (%s). %s |%s, %s|, %d%s.%s',
        format_authors($authors),
        $year,
        end_sentence(format_nonjournal_title($article_title)),
        Lingua::EN::Titlecase
            ->new($journal)
            ->title,
        $volume,
        $first_page,
        ($last_page ? "–$last_page" : ''),
        $doi ? " `doi:$doi`" : '';}

sub apa_book_chapter
   {my ($authors, $year, $chapter_title, $editors, $book, $volume,
        $first_page, $last_page, $place, $publisher) = @_;
    my @editors = map
        {"$_->[1] $_->[0]" . ($_->[2] ? " $_->[2]" : '')}
        @$editors;
    sprintf '%s (%s). %s In %s (Ed%s.), |%s| (%spp. %d–%d). %s: %s.',
        format_authors($authors),
        $year,
        end_sentence(format_nonjournal_title($chapter_title)),
        (@editors <= 2
          ? join ' & ', @editors
          : join ', ',
              @editors[0 .. $#editors - 1],
              '& ' . $editors[-1]),
        @editors == 1 ? '' : 's',
        format_nonjournal_title($book),
        $volume ? "Vol. $volume, " : '',
        $first_page, $last_page, $place,
        format_publisher($publisher);}

# ------------------------------------------------------------
# CrossRef
# ------------------------------------------------------------

sub query_crossref
   {my $url = query_url 'http://www.crossref.org/openurl/',
        pid => $crossref_email,
        noredirect => 'true',
        @_;
    progress 'Trying CrossRef';
    my $x = $global_cache->{crossref}{$url} ||= XMLin get($url),
        ForceArray => ['contributor'],
        GroupTags => {contributors => 'contributor'},
        NoAttr => 1;
    $x = $x->{query_result}{body}{query};
    exists $x->{contributors}
        or return err 'No results.';
    $x;}

sub get_doi
   {my ($year, $journal, $first_author_surname, $volume, $first_page) = @_;

    my %record = η
       (query_crossref
           (aulast => $first_author_surname,
              # CrossRef accepts only the first author, sadly.
            date => $year,
            title => $journal,
            ($volume ? (volume => $volume) : ()),
            ($first_page ? (spage => $first_page) : ()))
        || return undef);

    return $record{doi};}

# ------------------------------------------------------------
# EBSCOhost
# ------------------------------------------------------------

sub ctl
   {'ctl00$ctl00$MainContentArea$MainContentArea$' . join '$', @_;}
sub database ($);

sub ebsco
# Allowed %terms: year (scalar), author (array ref), title (array ref)
   {my %terms = @_;

    progress 'Trying EBSCOhost';

    my %search_fields =
       (ctl('findField', 'SearchTerm1') => join(' AND ',
            $terms{author} ? map {"AU \"$_\""} α $terms{author} : (),
            $terms{title} ? map {"TI \"$_\""} α $terms{title} : ()),
        $terms{year}
          ? ('common_DT1_FromYear' => $terms{year}, 'common_DT1_ToYear' => $terms{year})
          : ());

    my $record = $global_cache
            ->{ebsco}{to_json \%search_fields, {utf8 => 1, canonical => 1}}
            ||= runsub
       {my $agent = new WWW::Mechanize
           (agent => 'Cite-O-Matic',
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
            || $agent->content =~ /<strong>A System Problem has Occurred\./
            || $agent->content =~ /Authorization Required/)
          # We'll need to log in and choose databases first.
           {progress 'Logging in';
            $agent->post($sbu_login_url, χ
                user => $sbu_netid,
                pass => $sbu_password,
                url => $ebsco_login_url);

            # Now we're at the search screen. Save the form details
            # for quicker querying in the future.
            write_file $ebsco_post_path, to_json
                β
                   ($agent->current_form->action . '',
                    β
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
            and return [];
        # Use the first result that isn't just a correction. I
        # would just use "NOT PZ Erratum/Correction" in the
        # search string, but then records with no "Document Type"
        # field at all, including some journal articles, would
        # also be excluded.
        for (my $i = 1 ; $page =~ /Result_$i/ ; ++$i)
           {$page =~ m!Result_$i.+\[Erratum/Correction\]! and next;
            progress 'Fetching record';
            $agent->follow_link(name => "Result_$i");
            $agent->content =~ m!<a name="citation"><span>(.+?)</span></a></dd>.*?<dt>(.+?)</div>!s
                or die;
            return [$1, $2];}
        # No results.
        [];};

    @$record or return err 'No results.';

    # Parse the record.

    my ($title, $rows) = @$record;
    my %record =
        map {decode_entities $_}
        map {apply {s/:\s*\z//; s/\s+\z//;} $_}
        split /(?:<\/?d[tdl]>)+/, $rows;

    my $authors = β
        map {digest_author $_}
        split /;\s*|<br \/>/, $record{Authors};

    if (!$record{'Document Type'} or
        $record{'Document Type'} eq 'Article' or
        $record{'Document Type'} eq 'Journal Article' or
        $record{'Document Type'} eq 'Comment/Reply')

       {$record{Source} =~ s{
                \s+
                Vol \.? \s
                (\d+) \s?
                (?: Issue \s \d+ |
                    \( (?: \s | \w | - | , | \.)+ \) )
                , \s+
                } {✠}x
          # We don't actually want the issue number, but we remove it
          # from $record{Source} to avoid mistaking it for a year
          # later.
            or $record{Source} =~ s!\s+(\d+)(?:\(\d+\))?,\s+!✠!
            or die "Source: $record{Source}";
        my $volume = $1;
        $record{Source} =~ s! \A (.+?) \s* (?: \[ | \( | ; | / | ,✠ ) !!x or die;
        my $journal = digest_journal_title $1;
        my ($fpage, $lpage) =
            $record{Source} =~ s!p(?:p\. )?(\d+)-(\d+)!!
          ? ($1, $2)
          : $record{Source} =~ s!p(?:p\. )?(\d+).+?(\d+)p\b!!
          ? ($1, $2 + $1 - 1)
          : $record{Source} =~ s!p(?:p\. )?(\d+)!!
          ? ($1, undef)
          : die;
        $lpage = expand_last_page_number $fpage, $lpage;
        my $year;
        $year = $terms{year} or
           ($year) = $record{Source} =~ /((?:1[6789]|20)\d\d)/ or
            $record{Source} =~ /(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)(\d\d)/
          ? ($year = $1 < 25 ? "20$1" : "19$1")
          : die;
        my $doi = $record{'Digital Object Identifier'} || get_doi
            $year, $journal, $authors->[0][0], $volume, $fpage;

        return apa_journal_article $authors, $year, $title,
            $journal, $volume, $fpage, $lpage, $doi;}

    elsif ($record{'Document Type'} eq 'Chapter')

       {$record{Source} =~ m{
            \A (?<book> [^.]+?) \. \s
            (?: (?<volume> \d+) \. \s)?
            (?<editors> .+?) \s \(Ed\.\); \s
            pp\. \s (?<fpage> \d+) - (?<lpage> \d+) \. \s
            (?<place> [^,:]+, \s [^,:]+), \s [^,:]+: \s
            (?<publisher> [^,]+) , \s
            (?: [^,]+ , \s)?
            (?<year> \d\d\d\d) \.}x or die;
        my %src = %+;

        (my $book = $src{book}) =~ s/:  /: /;
        $src{volume} and $book =~ s/, Vol\z//;
        my $editors = β
           map {digest_author $_}
           split / \(Ed\.\); /, $src{editors}; #/;

        return apa_book_chapter $authors, $src{year}, $title,
            $editors, $book, $src{volume}, $src{fpage}, $src{lpage},
            $src{place}, $src{publisher};}

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
# Allowed %terms: year (scalar), keywords (array ref)
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
       {my $results = get $url;
        if ($results =~ /Sorry, your search for/)
          # No results.
           {χ;}
        else
          # Use the first result.
           {$results =~ /<DT>1\.\s+<a href="(.+?)"/ or die;
            progress 'Fetching record';
            χ get($1) =~ /<META NAME="citation_([^"]+)" content="([^"]+)">/g;}});

    keys %record or return err 'No results.';

    # Parse the record.

    my $authors = β
           map {digest_author $_}
           split /;\s+/, $record{authors};

    my ($fpage, $lpage) = ($record{firstpage}, $record{lastpage});
    $lpage = expand_last_page_number $fpage, $lpage;

    my $doi = get_doi
        $record{year}, $record{journal_title}, $authors->[0][0],
        $record{volume}, $fpage;

    return apa_journal_article
        $authors, $record{year}, $record{title},
        $record{journal_title}, $record{volume},
        $fpage, $lpage, $doi;}

# ------------------------------------------------------------
# Public interface
# ------------------------------------------------------------

sub apa
# Allowed %terms: year (scalar), author (array ref), title (array ref)
   {my %terms = @_;
    ebsco %terms or ideas
        year => $terms{year},
        keywords => β @{$terms{author}}, @{$terms{title}};}

if (not caller)
  # This file was invoked from the command line.
   {require Getopt::Long;
    @ARGV = map { decode 'UTF-8', $_ } @ARGV;
    my @title_words;
    die unless Getopt::Long::GetOptions
       ('t|title=s' => \@title_words);
    # Interpret any remaining argument that looks like a year
    # as a year.
    my $year;
    foreach my $i (0 .. $#ARGV)
       {$ARGV[$i] =~ /\A\d{4}\z/ or next;
        $year = splice @ARGV, $i, 1;
        last;}
    # Interpret the rest of @ARGV as author keywords.
    $verbose = 1;
    my $a = apa
       (year => $year,
        author => \@ARGV,
        title => \@title_words);
    $a and say $a;}

1;
