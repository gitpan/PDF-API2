package Font::TTF::Fmtx;

=head1 NAME

Font::TTF::Fmtx - Font Metrics table

=head1 DESCRIPTION

This is a simple table with just standards specified instance variables

=head1 INSTANCE VARIABLES

    version
    glyphIndex
    horizontalBefore
    horizontalAfter
    horizontalCaretHead
    horizontalCaretBase
    verticalBefore
    verticalAfter
    verticalCaretHead
    verticalCaretBase

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
    while (<Font::TTF::Fmtx::DATA>)
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
    init unless defined $fields{'glyphIndex'};
    $self->{' INFILE'}->read($dat, 16);

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

    $fh->print(TTF_Out_Fields($self, \%fields, 16));
    $self;
}


1;


=head1 BUGS

None known

=head1 AUTHOR

Jonathan Kew L<Jonathan_Kew@sil.org>. See L<Font::TTF::Font> for copyright and
licensing.

=cut


__DATA__
version, f
glyphIndex, L
horizontalBefore, c
horizontalAfter, c
horizontalCaretHead, c
horizontalCaretBase, c
verticalBefore, c
verticalAfter, c
verticalCaretHead, c
verticalCaretBase, c

