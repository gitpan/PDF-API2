package PDF::API2::PDF::FileAPI;

use strict;
no strict "refs";
use vars qw($cr %types $VERSION @ISA);
no warnings qw(uninitialized);

use IO::File;

use PDF::API2::PDF::Utils;
use PDF::API2::PDF::Array;
use PDF::API2::PDF::Bool;
use PDF::API2::PDF::Dict;
use PDF::API2::PDF::Name;
use PDF::API2::PDF::Number;
use PDF::API2::PDF::Objind;
use PDF::API2::PDF::String;
use PDF::API2::PDF::File 0.19;
use Font::TTF::Font 0.28;

@ISA=qw( PDF::API2::PDF::File );

( $VERSION ) = '$Revisioning: 0.3a15 $' =~ /\$Revisioning:\s+([^\s]+)/;

BEGIN
{
    my ($t, $type);
    
    $cr = '\s*(?:\015|\012|(?:\015\012))';
    %types = (
            'Page' => 'PDF::API2::PDF::Page',
            'Pages' => 'PDF::API2::PDF::Pages'
    );
    
    foreach $type (keys %types)
    {
        $t = $types{$type};
        $t =~ s|::|/|og;
        require "$t.pm";
    }
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
    my ($self,$explicitDestruct) = @_;

    my @tofree = values %{$self};
    map { $self->{$_}=undef; delete $self->{$_}; } keys %{$self};
    while (my $item = shift @tofree)
    {
        if (UNIVERSAL::can($item,'release'))
        {
            $item->release(1);
        }
        elsif (ref($item) eq 'ARRAY')
        {
            push( @tofree, @{$item} );
        }
        elsif (ref($item) eq 'HASH')
        {
            push( @tofree, values %{$item} );
            map { $item->{$_}=undef; delete $item->{$_}; } keys %{$item};
        }
        else
        {
        	$item=undef;
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
    $self->out_trailer($tdict,$self->{' update'});
    close($self->{' OUTFILE'});
}

1;
