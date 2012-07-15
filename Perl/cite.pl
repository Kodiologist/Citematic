#!/usr/bin/perl

use utf8;
use warnings;
use strict;
use Citematic::Get;
use Citematic::QuickBib;
use Encode 'decode';
use JSON qw(to_json);
use File::Slurp 'write_file';
use Getopt::Long::Descriptive;

sub runsub (&) {return $_[0]->();}

@ARGV = map { decode 'UTF-8', $_ } @ARGV;
my ($opt, $usage) = Getopt::Long::Descriptive::describe_options
   ('%c %o [<search-term> ...]',
    ['title|t=s@' => 'a title keyword'],
    ['bypass-ebsco-cache|b' => "don't read from the cache for EBSCOhost (useful for getting fresh full-text URLs)"],
    ['more|m' => 'include more information in the citation (breaks APA style)'],
    ['json=s' => 'where to save the CSL variables'],
    ['quiet|q', ''],
    ['debug|d', ''],
    ['help', '']);

if ($opt->help)
   {print $usage->text;
    exit;}

my @title_words = @{$opt->title || []};
local $Citematic::Get::verbose = not $opt->quiet;
local $Citematic::Get::debug = $opt->debug;
local $Citematic::Get::bypass_ebsco_cache = $opt->bypass_ebsco_cache;

# Interpret arguments that look like years, DOIs, or
# formatted citations appropriately. Interpret the remainder
# as author keywords.

my ($year, $doi, @author_words);

push @author_words, grep {runsub
   {if (/\A\d{4}\z/)
       {$year = $_;}
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

my $a = Citematic::Get::get
   (author => \@author_words,
    year => $year,
    title => \@title_words,
    doi => $doi);

if ($a)
   {my %apa_opts =
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
