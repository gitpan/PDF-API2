package Text::PDF::FileAPI;

use strict;
no strict "refs";
use vars qw($cr %types $VERSION @ISA);
no warnings qw(uninitialized);

use IO::File;

use Text::PDF::Utils;
use Text::PDF::Array;
use Text::PDF::Bool;
use Text::PDF::Dict;
use Text::PDF::Name;
use Text::PDF::Number;
use Text::PDF::Objind;
use Text::PDF::String;
use Text::PDF::File 0.19;
use Font::TTF::Font 0.28;

@ISA=qw( Text::PDF::File );

BEGIN {
	$cr = $Text::PDF::File::cr;
}

sub open
{
    my ($class, $fname, $update) = @_;
    my ($self, $buf, $xpos, $end, $tdict, $k);
    my ($fh);

    $self = $class->_new;
    if (ref $fname)
    { 
        $self->{' INFILE'} = $fname; 
        if ($update)
        {
            $self->{' update'} = 1;
            $self->{' OUTFILE'} = $fname;
        }
        $fh = $fname; 
    }
    else
    {
        $fh = IO::File->new(($update ? "+" : "") . "<$fname") || return undef;
        $self->{' INFILE'} = $fh;
        binmode $fh;
        if ($update)
        {
            $self->{' update'} = 1;
            $self->{' OUTFILE'} = $fh;
            $self->{' fname'} = $fname;
        }
    }
    $fh->seek(0, 0);            # go to start of file
    $fh->read($buf, 255);
    if ($buf !~ m/^\%PDF\-1\.\d+\s*$cr/mo)
    { die "$fname not a PDF file version 1.x"; }

    $fh->seek(0, 2);            # go to end of file
    $end = $fh->tell();
    $self->{' epos'} = $end;
    $fh->seek($end - 1024, 0);
    $fh->read($buf, 1024);
    if ($buf !~ m/startxref$cr([0-9]+)$cr\%\%eof.*?$/oi)
    { die "Malformed PDF file $fname"; }
    $xpos = $1;
    
    $tdict = $self->readxrtr($xpos, $self);
    foreach $k (keys %{$tdict})
    { $self->{$k} = $tdict->{$k}; }
    return $self;
}


sub release
{
    my ($self) = @_;

    ###########################################################################
    # Go through our list of keys/values and clean things up as needed.  We'll
    # forcefully free up all of the memory for all of the values in our
    # anonymous hash, and then recursively process all sub-data-structures to
    # make sure that all of those get cleaned up properly as well:
    # - Scalar values get explicitly deleted (as part of the mass cleanup).
    # - Hash/List refs get their values added in to the list of things to
    #   cleanup so we can process the structures recursively.
    # - 'Text::PDF::*' elements get explicitly destructed to free up their
    #   memory and break any potential circular references.
    # - 'IO::File' elements get cleaned up as part of the mass cleanup, and
    #   aren't explicitly listed below (although there are some in our
    #   structure).
    ###########################################################################
    # NOTE: The checks below have been ordered such that the most commonly
    #       occurring items get checked for and cleaned out first.
    ###########################################################################
    # FURTHER NOTE: Reducing the checks below to the least amount of checks
    #               possible did not create any noticable performance
    #               improvement.
    ###########################################################################
    my @tofree = values %{$self};
    map { delete $self->{$_} } keys %{$self};
    while (my $item = shift @tofree)
    {
        if (UNIVERSAL::can($item,'release'))
        {
            $item->release();
        }
        elsif (ref($item) eq 'ARRAY')
        {
            push( @tofree, @{$item} );
        }
        elsif (ref($item) eq 'HASH')
        {
            push( @tofree, values %{$item} );
            map { delete $item->{$_} } keys %{$item};
        }
    }
}

sub append_file
{
    my ($self) = @_;
    my ($tdict, $fh, $t, $buf, $ver);
    
    return undef unless ($self->{' update'});

    $fh = $self->{' INFILE'};
    
    # hack to upgrade pdf-version number to support
    # requested features in higher versions that
    # the pdf was originally created.
    $fh->seek(7,0);
    $fh->read($buf, 3);
    $buf=~s/[^\d]+$//g;
    $ver=$self->{' version'} || 2;
    if($buf < $ver) {
    ##	print STDERR "files version was 1.$buf upgraded to 1.$ver.\n";
	    $fh->seek(0,0);
	    $fh->print("%PDF-1.$ver\n");
    }
    
    $tdict = PDFDict();
    $tdict->{'Prev'} = PDFNum($self->{' loc'});
    $tdict->{'Info'} = $self->{'Info'};
    if (defined $self->{' newroot'})
    { $tdict->{'Root'} = $self->{' newroot'}; }
    else
    { $tdict->{'Root'} = $self->{'Root'}; }
    $tdict->{'Size'} = $self->{'Size'};

    foreach $t (grep ($_ !~ m/^\s/o, keys %$self))
    { $tdict->{$t} = $self->{$t} unless defined $tdict->{$t}; }

    $fh->seek($self->{' epos'}, 0);
    $self->out_trailer($tdict);
    close($self->{' OUTFILE'});
}

1;
