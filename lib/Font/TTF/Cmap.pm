package Font::TTF::Cmap;

=head1 NAME

Font::TTF::Cmap - Character map table

=head1 DESCRIPTION

Looks after the character map. The primary structure used for handling a cmap
is the L<Font::TTF::Segarr> which handles the segmented arrays of format 4 tables,
and in a simpler form for format 0 tables.

Due to the complexity of working with segmented arrays, most of the handling of
such arrays is via methods rather than via instance variables.

One important feature of a format 4 table is that it always contains a segment
with a final address of 0xFFFF. If you are creating a table from scratch this is
important (although L<Font::TTF::Segarr> can work quite happily without it).


=head1 INSTANCE VARIABLES

The instance variables listed here are not preceeded by a space due to their
emulating structural information in the font.

=over 4

=item Num

Number of subtables in this table

=item Tables

An array of subtables ([0..Num-1])

=back

Each subtables also has its own instance variables which are, again, not
preceeded by a space.

=over 4

=item Platform

The platform number for this subtable

=item Encoding

The encoding number for this subtable

=item Format

Gives the stored format of this subtable

=item Ver

Gives the version (or language) information for this subtable

=item val

A hash keyed by the codepoint value (not a string) storing the glyph id

=back

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);
use Font::TTF::Table;
use Font::TTF::Utils;

@ISA = qw(Font::TTF::Table);


=head2 $t->read

Reads the cmap into memory. Format 4 subtables read the whole subtable and
fill in the segmented array accordingly.

Format 2 subtables are not read at all.

=cut

sub read
{
    my ($self) = @_;
    my ($dat, $i, $j, $k, $id, @ids, $s);
    my ($start, $end, $range, $delta, $form, $len, $num, $ver);
    my ($fh) = $self->{' INFILE'};

    $self->SUPER::read or return $self;
    $fh->read($dat, 4);
    $self->{'Num'} = unpack("x2n", $dat);
    $self->{'Tables'} = [];
    for ($i = 0; $i < $self->{'Num'}; $i++)
    {
        $s = {};
        $fh->read($dat, 8);
        ($s->{'Platform'}, $s->{'Encoding'}, $s->{'LOC'}) = (unpack("nnN", $dat));
        $s->{'LOC'} += $self->{' OFFSET'};
        push(@{$self->{'Tables'}}, $s);
    }
    for ($i = 0; $i < $self->{'Num'}; $i++)
    {
        $s = $self->{'Tables'}[$i];
        $fh->seek($s->{'LOC'}, 0);
        $fh->read($dat, 6);
        ($form, $len, $ver) = (unpack("n3", $dat));

        $s->{'Format'} = $form;
        $s->{'Ver'} = $ver;
        if ($form == 0)
        {
            my ($j) = 0;
            $fh->read($dat, 256);
            $s->{'val'} = {map {$j++; ($_ ? ($j - 1, $_) : ())} unpack("C*", $dat)};
        } elsif ($form == 6)
        {
            my ($start, $ecount);
            
            $fh->read($dat, 4);
            ($start, $ecount) = unpack("n2", $dat);
            $fh->read($dat, $ecount << 1);
            $s->{'val'} = {map {$start++; ($_ ? ($start - 1, $_) : ())} unpack("n*", $dat)};
        } elsif ($form == 2)
        {
# no idea what to do here yet
        } elsif ($form == 4)
        {
            $fh->read($dat, 8);
            $num = unpack("n", $dat);
            $num >>= 1;
            $fh->read($dat, $len - 14);
            for ($j = 0; $j < $num; $j++)
            {
                $end = unpack("n", substr($dat, $j << 1, 2));
                $start = unpack("n", substr($dat, ($j << 1) + ($num << 1) + 2, 2));
                $delta = unpack("n", substr($dat, ($j << 1) + ($num << 2) + 2, 2));
                $delta -= 65536 if $delta > 32767;
                $range = unpack("n", substr($dat, ($j << 1) + $num * 6 + 2, 2));
                for ($k = $start; $k <= $end; $k++)
                {
                    if ($range == 0)
                    { $id = $k + $delta; }
                    else
                    { $id = unpack("n", substr($dat, ($j << 1) + $num * 6 +
                                        2 + ($k - $start) * 2 + $range, 2)) + $delta; }
		            $id -= 65536 if $id >= 65536;
                    $s->{'val'}{$k} = $id if ($id);
                }
            }
        } elsif ($form == 8 || $form == 12)
        {
            if ($form == 8)
            {
                $fh->read($dat, 8196);
                $num = unpack("N", substr($dat, 8192, 4)); # don't need the map
            } else
            {
                $fh->read($dat, 4);
                $num = unpack("N", $dat);
            }
            $fh->read($dat, 12 * $num);
            for ($j = 0; $j < $num; $j++)
            {
                ($start, $end, $s) = unpack("N3", substr($dat, $j * 12, 12));
                for ($k = $start; $k <= $end; $k++)
                { $s->{'val'}{$k} = $s++; }
            }
        } elsif ($form == 10)
        {
            $fh->read($dat, 8);
            ($start, $num) = unpack("N2", $dat);
            $fh->read($dat, $num << 1);
            for ($j = 0; $j < $num; $j++)
            { $s->{'val'}{$start + $j} = unpack("n", substr($dat, $j << 1, 2)); }
        }
    }
    $self;
}


=head2 $t->ms_lookup($uni)

Given a Unicode value in the MS table (Platform 3, Encoding 1) locates that
table and looks up the appropriate glyph number from it.

=cut

sub ms_lookup
{
    my ($self, $uni) = @_;

    $self->find_ms || return undef unless (defined $self->{' mstable'});
    return $self->{' mstable'}{'val'}{$uni};
}


=head2 $t->find_ms

Finds the Microsoft Unicode table and sets the C<mstable> instance variable
to it if found. Returns the table it finds.

=cut
sub find_ms
{
    my ($self) = @_;
    my ($i, $s, $alt);

    return $self->{' mstable'} if defined $self->{' mstable'};
    $self->read;
    for ($i = 0; $i < $self->{'Num'}; $i++)
    {
        $s = $self->{'Tables'}[$i];
        if ($s->{'Platform'} == 3)
        {
            $self->{' mstable'} = $s;
            last if ($s->{'Encoding'} == 1);
        } elsif ($s->{'Platform'} == 0 || ($s->{'Platform'} == 2 && $s->{'Encoding'} == 1))
        { $self->{' mstable'} = $s; }
    }
    $self->{' mstable'};
}


=head2 $t->out($fh)

Writes out a cmap table to a filehandle. If it has not been read, then
just copies from input file to output

=cut

sub out
{
    my ($self, $fh) = @_;
    my ($loc, $s, $i, $base_loc, $j, @keys);

    return $self->SUPER::out($fh) unless $self->{' read'};

    $base_loc = $fh->tell();
    $fh->print(pack("n2", 0, $self->{'Num'}));

    for ($i = 0; $i < $self->{'Num'}; $i++)
    { $fh->print(pack("nnN", $self->{'Tables'}[$i]{'Platform'}, $self->{'Tables'}[$i]{'Encoding'}, 0)); }

    for ($i = 0; $i < $self->{'Num'}; $i++)
    {
        $s = $self->{'Tables'}[$i];
        @keys = sort {$a <=> $b} keys %{$s->{'val'}};
        $s->{' outloc'} = $fh->tell();
        if ($s->{'Format'} < 8)
        { $fh->print(pack("n3", $s->{'Format'}, 0, $s->{'Ver'})); }       # come back for length
        else
        { $fh->print(pack("n2N2", $s->{'Format'}, 0, 0, $s->{'Ver'})); }
            
        if ($s->{'Format'} == 0)
        {
            $fh->print(pack("C256", @{$s->{'val'}}{0 .. 255}));
        } elsif ($s->{'Format'} == 6)
        {
            $fh->print(pack("n2", $keys[0], $keys[-1] - $keys[0] + 1));
            $fh->print(pack("n*", @{$s->{'val'}}{$keys[0] .. $keys[-1]}));
        } elsif ($s->{'Format'} == 2)
        {
        } elsif ($s->{'Format'} == 4)
        {
            my ($num, $sRange, $eSel, $eShift, @starts, @ends, $doff);
            my (@deltas, $delta, @range, $flat, $k, $segs, $count, $newseg, $v);

            push(@keys, 0xFFFF) unless ($keys[-1] == 0xFFFF);
            $newseg = 1; $num = 0;
            for ($j = 0; $j <= $#keys && $keys[$j] <= 0xFFFF; $j++)
            {
                $v = $s->{'val'}{$keys[$j]};
                if ($newseg)
                {
                    $delta = $v;
                    $doff = $j;
                    $flat = 1;
                    push(@starts, $keys[$j]);
                    $newseg = 0;
                }
                $delta = 0 if ($delta + $j - $doff != $v);
                $flat = 0 if ($v == 0);
                if ($j == $#keys || $keys[$j] + 1 != $keys[$j+1])
                {
                    push (@ends, $keys[$j]);
                    push (@deltas, $delta ? $delta - $keys[$doff] : 0);
                    push (@range, $flat);
                    $num++;
                    $newseg = 1;
                }
            }

            ($num, $sRange, $eSel, $eShift) = Font::TTF::Utils::TTF_bininfo($num, 2);
            $fh->print(pack("n4", $num * 2, $sRange, $eSel, $eShift));
            $fh->print(pack("n*", @ends));
            $fh->print(pack("n", 0));
            $fh->print(pack("n*", @starts));
            $fh->print(pack("n*", @deltas));

            $count = 0;
            for ($j = 0; $j < $num; $j++)
            {
                $delta = $deltas[$j];
                if ($delta != 0 && $range[$j] == 1)
                { $range[$j] = 0; }
                else
                {
                    $range[$j] = ($count + $num - $j) << 1;
                    $count += $ends[$j] - $starts[$j] + 1;
                }
            }

            $fh->print(pack("n*", @range));

            for ($j = 0; $j < $num; $j++)
            {
                next if ($range[$j] == 0);
                $fh->print(pack("n*", @{$s->{'val'}}{$starts[$j] .. $ends[$j]}));
            }
        } elsif ($s->{'Format'} == 8 || $s->{'Format'} == 12)
        {
            my (@jobs, $start, $current, $curr_glyf, $map);
            
            $map = "\000" x 8192;
            foreach $j (@keys)
            {
                if ($j > 0xFFFF)
                {
                    if (defined $s->{'val'}{$j >> 16})
                    { $s->{'Format'} = 12; }
                    vec($map, $j >> 16, 1) = 1;
                }
                if ($j != $current + 1 || $s->{'val'}{$j} != $curr_glyf + 1)
                {
                    push (@jobs, [$start, $current, $curr_glyf]) if (defined $start);
                    $start = $j; $current = $j; $curr_glyf = $s->{'val'}{$j};
                }
            }
            $fh->print($map) if ($s->{'Format'} == 8);
            $fh->print(pack('N', $#jobs + 1));
            foreach $j (@jobs)
            { $fh->print(pack('N3', @{$j})); }
        } elsif ($s->{'Format'} == 10)
        {
            $fh->print(pack('N2', $keys[0], $keys[-1] - $keys[0] + 1));
            $fh->print(pack('n*', $s->{'val'}{$keys[0] .. $keys[-1]}));
        }

        $loc = $fh->tell();
        if ($s->{'Format'} < 8)
        {
            $fh->seek($s->{' outloc'} + 2, 0);
            $fh->print(pack("n", $loc - $s->{' outloc'}));
        } else
        {
            $fh->seek($s->{' outloc'} + 4, 0);
            $fh->print(pack("N", $loc - $s->{' outloc'}));
        }
        $fh->seek($base_loc + 8 + ($i << 3), 0);
        $fh->print(pack("N", $s->{' outloc'} - $base_loc));
        $fh->seek($loc, 0);
    }
    $self;
}


=head2 $t->XML_element($context, $depth, $name, $val)

Outputs the elements of the cmap in XML. We only need to process val here

=cut

sub XML_element
{
    my ($self, $context, $depth, $k, $val) = @_;
    my ($fh) = $context->{'fh'};
    my ($i);

    return $self if ($k eq 'LOC');
    return $self->SUPER::XML_element($context, $depth, $k, $val) unless ($k eq 'val');

    $fh->print("$depth<mappings>\n");
    foreach $i (sort {$a <=> $b} keys %{$val})
    { $fh->printf("%s<map code='%04X' glyph='%s'/>\n", $depth . $context->{'indent'}, $i, $val->{$i}); }
    $fh->print("$depth</mappings>\n");
    $self;
}

=head2 @map = $t->reverse([$num])

Returns a reverse map of the table of given number or the Microsoft
cmap. I.e. given a glyph gives the Unicode value for it.

=cut

sub reverse
{
    my ($self, $tnum) = @_;
    my ($table) = defined $tnum ? $self->{'Tables'}[$tnum] : $self->find_ms;
    my (@res, $code, $gid);

    while (($code, $gid) = each(%{$table->{'val'}}))
    { $res[$gid] = $code unless (($res[$gid] || 0) > 0 && ($res[$gid] || 0) < $code); }
    @res;
}


=head2 is_unicode($index)

Returns whether the table of a given index is known to be a unicode table
(as specified in the specifications)

=cut

sub is_unicode
{
    my ($self, $index) = @_;
    my ($pid, $eid) = ($self->{'Tables'}[$index]{'Platform'}, $self->{'Tables'}[$index]{'Encoding'});

    return ($pid == 3 || $pid == 0 || ($pid == 2 && $eid == 1));
}

1;

=head1 BUGS

=over 4

=item *

No support for format 2 tables (MBCS)

=back

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org. See L<Font::TTF::Font> for copyright and
licensing.

=cut

