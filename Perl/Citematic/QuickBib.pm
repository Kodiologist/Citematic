package Citematic::QuickBib;

use utf8;
use warnings;
use strict;
use JSON qw(from_json to_json);
use IPC::Run 'start';

sub new
   {my $invocant = shift;
    my %h =
       (python3_path => $ENV{CITEMATIC_PYTHON3_PATH} || 'python3',
        @_);
    my $o = bless \%h, ref($invocant) || $invocant;
    $o->_init;
    return $o;}

sub _init
   {my $self = shift;
    $self->{in} = '';
    $self->{out} = '';
    $self->{handle} = start
        [$self->{python3_path}, '-m', 'quickbib'],
        \($self->{in}), \($self->{out})
      or die $?;
    return 1;}

sub DESTROY
   {$_[0]->{handle}->signal("TERM");}

sub python
   {my ($self, $command, %args) = @_;
    $self->{in} = to_json({command => $command, args => \%args})
        . "\n";
    $self->{out} = '';
    $self->{handle}->pump
        until length($self->{in}) == 0 and $self->{out} =~ /\n\z/;
    my $reply = from_json($self->{out}, {utf8 => 1});
    exists $reply->{error} and die "Error from child: $reply->{error}";
    return $reply;}

sub bib1
   {my ($self, $object, %o) = @_;
    return $self->python('bib1', d => $object, %o)->{value};}

sub bib
   {my ($self, $os, %o) = @_;
    return $self->python('bib', ds => $os, %o)->{value};}

1;
