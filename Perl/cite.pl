#!/usr/bin/perl

use utf8;
use warnings;
use strict;
use Citematic::Get;
use Citematic::QuickBib;
use URI::Escape;
use Encode 'decode';
use JSON qw(to_json);
use File::Slurp 'read_file', 'write_file';
use Getopt::Long::Descriptive;

sub runsub (&) {return $_[0]->();}
sub normalize {my $s = $_[0]; $s =~ s/\s+/ /g; $s =~ s/\A //; $s =~ s/ \z//; $s}

@ARGV = map { decode 'UTF-8', $_ } @ARGV;
my ($opt, $usage) = Getopt::Long::Descriptive::describe_options
   ('%c %o [<search-term> ...]',
    ['title|t=s@' => 'a title keyword'],
    ['input|i=s' => 'a RIS file to parse'],
    ['bypass-ebsco-cache|b' => "don't read from the cache for EBSCOhost (useful for getting fresh full-text URLs)"],
    ['more|m' => 'include more information in the citation (breaks APA style)'],
    ['doi-url-fmt=s', 'printf format for making a URL out of a DOI',
        {default => 'http://doi.dx.org/%s'}],
    ['json=s' => 'where to save the CSL variables'],
    ['quiet|q', ''],
    ['debug|d', ''],
    ['help', '']);

if ($opt->help)
   {print $usage->text;
    exit;}

local $Citematic::Get::verbose = not $opt->quiet;
local $Citematic::Get::debug = $opt->debug;
local $Citematic::Get::bypass_ebsco_cache = $opt->bypass_ebsco_cache;

my $a = $opt->input

  ? Citematic::Get::digest_ris(scalar($opt->input eq '-'
      ? do {local $/; binmode STDIN, ':utf8'; <STDIN>}
      : read_file $opt->input, {binmode => ':utf8'}))

  : do
       {my @title_words = map {normalize $_} @{$opt->title || []};

        # Interpret arguments that look like years, ISBNs, DOIs, EBSCO
        # URLs, arXiv IDs, or formatted citations appropriately.
        # Interpret the remainder as author keywords.

        my ($year, $year_min, $year_max, $isbn, $doi, %ebsco_record, $arxiv_id, @author_words);

        push @author_words, map {normalize $_} grep {runsub
           {if (/\A(\.\. *)?(\d{4})\z/)
               {($1 ? $year_max : $year) = $2;}
            elsif (/\A(\d{4}) *\.\.( *(\d{4}))?\z/)
               {$year_min = $1;
                $year_max = $3;}
            elsif (/\bebscohost\.com\b/ and
                    m![#&]db=([a-zA-Z0-9]{3,6}).+?\bAN=([^=&#/]+)!)
               {%ebsco_record = (db => $1, AN => uri_unescape($2));}
            elsif (m!\barxiv(?:\.org/\w+/|:)([-/.\w]+)!)
               {$arxiv_id = $1;}
            elsif (m!\A[-0-9xX]+\z!)
               {$isbn = $_;}
            elsif (m!\A(?:doi:)?\d+\.\d+/!)
               {$doi = $_;}
            elsif (/,/)
               {!$year and s/\(?(\d+)\)?//
                    and $year = $1;
                push @author_words, /(\w{2,})/g;}
            else
               {return 1;}
            0;}}
          @ARGV;

        Citematic::Get::get
           (author => \@author_words,
            year => $year,
            year_min => $year_min,
            year_max => $year_max,
            title => \@title_words,
            isbn => $isbn,
            doi => $doi,
            ebsco_record => \%ebsco_record,
            arxiv_id => $arxiv_id);};

if ($a)
   {!$opt->quiet and $a->{DOI}
        and print STDERR 'DOI URL: ',
            sprintf($opt->doi_url_fmt,
                uri_escape($a->{DOI}, '^A-Za-z0-9\-\._~/')),
            "\n";
    my %apa_opts =
       (style_path => $ENV{APA_CSL_PATH}
            || die('The environment variable APA_CSL_PATH is not set'),
        apa_tweaks => 1);
    $opt->more and %apa_opts = (%apa_opts,
        abbreviate_given_names => 0,
        always_include_issue => 1,
        include_isbn => 1);
    print Citematic::QuickBib->new->bib1($a, %apa_opts), "\n";
    $opt->json and write_file $opt->json, to_json $a,
        {utf8 => 1, pretty => 1, canonical => 1};}
