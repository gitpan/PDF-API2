package Font::TTF::Hhea;

=head1 NAME

TTF:Hhea - Horizontal Header table

=head1 DESCRIPTION

This is a simplte table with just standards specified instance variables

=head1 INSTANCE VARIABLES

    version
    Ascender
    Descender
    LineGap
    advanceWidthMax
    minLeftSideBearing
    minRightSideBearing
    xMaxExtent
    caretSlopeRise
    caretSlopeRun
    metricDataFormat
    numberOfHMetrics


=head1 METHODS

=cut

use strict;
use vars qw(@ISA %fields);

require Font::TTF::Table;
use Font::TTF::Utils;

@ISA = qw(Font::TTF::Table);

sub init
{
    my ($k, $v, $c);
    while (<Font::TTF::Hhea::DATA>)
    {
        ($k, $v, $c) = TTF_Init_Fields($_, $c);
        next unless defined $k && $k ne "";
        $fields{$k} = $v;
    }
}


=head2 $t->read

Reads the table into memory as instance variables

=cut

sub read
{
    my ($self) = @_;
    my ($dat);

    $self->SUPER::read or return $self;
    init unless defined $fields{'Ascender'};
    $self->{' INFILE'}->read($dat, 36);

    TTF_Read_Fields($self, $dat, \%fields);
    $self;
}


=head2 $t->out($fh)

Writes the table to a file either from memory or by copying.

=cut

sub out
{
    my ($self, $fh) = @_;

    return $self->SUPER::out($fh) unless $self->{' read'};

    $self->{'numberOfHMetrics'} = $self->{' PARENT'}{'hmtx'}->numMetrics || $self->{'numberOfHMetrics'};
    $fh->print(TTF_Out_Fields($self, \%fields, 36));
    $self;
}


=head2 $t->update

Updates various parameters in the hhea table from the hmtx table, assuming
the C<hmtx> table is dirty.

=cut

sub update
{
    my ($self) = @_;
    my ($hmtx) = $self->{' PARENT'}{'hmtx'};
    my ($glyphs);
    my ($num);
    my ($i, $maw, $mlsb, $mrsb, $mext, $aw, $lsb, $ext);

    return undef unless (defined $hmtx && defined $self->{' PARENT'}{'loca'});
    $hmtx->read->update;
    $self->{' PARENT'}{'loca'}->read->update;
    $glyphs = $self->{' PARENT'}{'loca'}{'glyphs'};
    $num = $self->{' PARENT'}{'maxp'}{'numGlyphs'};

    return undef unless ($hmtx->{' isDirty'} || $self->{' PARENT'}{'loca'}{' isDirty'});
    
    for ($i = 0; $i < $num; $i++)
    {
        $aw = $hmtx->{'advance'}[$i];
        $lsb = $hmtx->{'lsb'}[$i];
        if (defined $glyphs->[$i])
        { $ext = $lsb + $glyphs->[$i]->read->{'xMax'} - $glyphs->[$i]{'xMin'}; }
        else
        { $ext = $aw; }
        $maw = $aw if ($aw > $maw);
        $mlsb = $lsb if ($lsb < $mlsb or $i == 0);
        $mrsb = $aw - $ext if ($aw - $ext < $mrsb or $i == 0);
        $mext = $ext if ($ext > $mext);
    }
    $self->{'advanceWidthMax'} = $maw;
    $self->{'minLeftSideBearing'} = $mlsb;
    $self->{'minRightSideBearing'} = $mrsb;
    $self->{'xMaxExtent'} = $mext;
    $self->{'numberOfHMetrics'} = $hmtx->numMetrics;

    $self->{' isdirty'} = 1;
    $self;
}


1;


=head1 BUGS

None known

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut


__DATA__
version, f
Ascender, s
Descender, s
LineGap, s
advanceWidthMax, S
minLeftSideBearing, s
minRightSideBearing, s
xMaxExtent, s
caretSlopeRise, s
caretSlopeRun, s
metricDataFormat, +10s
numberOfHMetrics, S

