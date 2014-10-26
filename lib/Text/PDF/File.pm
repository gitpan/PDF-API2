package Text::PDF::File;

=head1 NAME

Text::PDF::File - Holds the trailers and cross-reference tables for a PDF file

=head1 SYNOPSIS

 $p = Text::PDF::File->open("filename.pdf", 1);
 $p->new_obj($obj_ref);
 $p->free_obj($obj_ref);
 $p->append_file;
 $p->close;
 $p->release;       # IMPORTANT!

=head1 DESCRIPTION

This class keeps track of the directory aspects of a PDF file. There are two
parts to the directory: the main directory object which is the parent to all
other objects and a chain of cross-reference tables and corresponding trailer
dictionaries starting with the main directory object.

=head1 INSTANCE VARIABLES

Within this class hierarchy, rather than making everything visible via methods,
which would be a lot of work, there are various instance variables which are
accessible via associative array referencing. To distinguish instance variables
from content variables (which may come from the PDF content itself), each such
variable will start with a space.

Variables which do not start with a space directly reflect elements in a PDF
dictionary. In the case of a Text::PDF::File, the elements reflect those in the
trailer dictionary.

Since some variables are not designed for class users to access, variables are
marked in the documentation with (R) to indicate that such an entry should only
be used as read-only information. (P) indicates that the information is private
and not designed for user use at all, but is included in the documentation for
completeness and to ensure that nobody else tries to use it.

=over

=item newroot

This variable allows the user to create a new root entry to occur in the trailer
dictionary which is output when the file is written or appended. If you wish to
over-ride the root element in the dictionary you have, use this entry to indicate
that without losing the current Root entry. Notice that newroot should point to
a PDF level object and not just to a dictionary which does not have object status.

=item INFILE (R)

Contains the filehandle used to read this information into this PDF directory. Is
an IO object.

=item fname (R)

This is the filename which is reflected by INFILE, or the original IO object passed
in.

=item update (R)

This indicates that the read file has been opened for update and that at some
point, $p->appendfile() can be called to update the file with the changes that
have been made to the memory representation.

=item maxobj (R)

Contains the first useable object number above any that have already appeared
in the file so far.

=item outlist (P)

This is a list of Objind which are to be output when the next appendfile or outfile
occurs.

=item firstfree (P)

Contains the first free object in the free object list. Free objects are removed
from the front of the list and added to the end.

=item lastfree (P)

Contains the last free object in the free list. It may be the same as the firstfree
if there is only one free object.

=item objcache (P)

All objects are held in the cache to ensure that a system only has one occurrence of
each object. In effect, the objind class acts as a container type class to hold the
PDF object structure and it would be unfortunate if there were two identical
place-holders floating around a system.

=item epos (P)

The end location of the read-file.

=back

Each trailer dictionary contains a number of private instance variables which
hold the chain together.

=over

=item loc (P)

Contains the location of the start of the cross-reference table preceding the
trailer.

=item xref (P)

Contains an anonymous array of each cross-reference table entry.

=item prev (P)

A reference to the previous table. Note this differs from the Prev entry which
is in PDF which contains the location of the previous cross-reference table.

=back

=head1 METHODS

=cut

use strict;
no strict "refs";
use vars qw($cr %types $VERSION);
no warnings qw(uninitialized);

use IO::File;

# Now for the basic PDF types
use Text::PDF::Utils;

use Text::PDF::Array;
use Text::PDF::Bool;
use Text::PDF::Dict;
use Text::PDF::Name;
use Text::PDF::Number;
use Text::PDF::Objind;
use Text::PDF::String;

$VERSION = "0.18";      # MJPH   1-DEC-2001     add encryption hooks
#$VERSION = "0.17";      # GST   18-JUL-2001     Handle \) in strings and tidy up endobj handling, no uninitialized warnings
#$VERSION = "0.16";      # GST   18-JUL-2001     Major performance tweaks
#$VERSION = "0.15";      # GST   30-MAY-2001     Memory leaks fixed
#$VERSION = "0.14";      # MJPH   2-MAY-2001     More little bug fixes, added read_objnum
#$VERSION = "0.13";      # MJPH  23-MAR-2001     General bug fix release
#$VERSION = "0.12";      # MJPH  29-JUL-2000     Add font subsetting, random page insertion
#$VERSION = "0.11";      # MJPH  18-JUL-2000     Add pdfstamp.plx and more debugging
#$VERSION = "0.10";	     # MJPH	 27-JUN-2000     Tidy up some bugs - names
#$VERSION = "0.09";	     # MJPH	 31-MAR-2000     Copy trailer dictionary properly
#$VERSION = "0.08";      # MJPH  07-FEB-2000     Add null element
#$VERSION = "0.07";      # MJPH  01-DEC-1999     Debug for pdfbklt
#$VERSION = "0.06";      # MJPH  11-SEP-1999     Sort out unixisms
#$VERSION = "0.05";      # MJPH   9-SEP-1999     Add ship_out
#$VERSION = "0.04";      # MJPH  14-JUL-1999     Correct paths for tarball release
#$VERSION = "0.03";      # MJPH  14-JUL-1999     Correct paths for tarball release
#$VERSION = "0.02";      # MJPH  30-JUN-1999     Transfer from old library

BEGIN
{
    my ($t, $type);
    
    $cr = '\s*(?:\015|\012|(?:\015\012))';
    %types = (
            'Page' => 'Text::PDF::Page',
            'Pages' => 'Text::PDF::Pages'
    );
    
    foreach $type (keys %types)
    {
        $t = $types{$type};
        $t =~ s|::|/|og;
        require "$t.pm";
    }
}
            

=head2 Text::PDF::File->new

Creates a new, empty file object which can act as the host to other PDF objects.
Since there is no file associated with this object, it is assumed that the
object is created in readiness for creating a new PDF file.

=cut

sub new
{
    my ($class) = @_;
    my ($self) = $class->_new;
    my ($root);

    $root = PDFDict();
    $root->{'Type'} = PDFName("Catalog");
    $self->new_obj($root);
    $self->{'Root'} = $root;
    $self;
}


=head2 $p = Text::PDF::File->open($filename, $update)

Opens the file and reads all the trailers and cross reference tables to build
a complete directory of objects.

$update specifies whether this file is being opened for updating and editing,
or simply to be read.

$filename may be an IO object

=cut

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

=head2 $p->release()

Releases ALL of the memory used by the PDF document and all of its component
objects.  After calling this method, do B<NOT> expect to have anything left in
the C<Text::PDF::File> object (so if you need to save, be sure to do it before
calling this method).  

B<NOTE>, that it is important that you call this method on any
C<Text::PDF::File> object when you wish to destruct it and free up its memory.
Internally, PDF files have an enormous number of cross-references and this
causes circular references within the internal data structures.  Calling
'C<release()>' forces a brute-force cleanup of the data structures, freeing up
all of the memory.  Once you've called this method, though, don't expect to be
able to do anything else with the C<Text::PDF::File> object; it'll have B<no>
internal state whatsoever.

B<Developer note:> As part of the brute-force cleanup done here, this method
will throw a warning message whenever unexpected key values are found within
the C<Text::PDF::File> object.  This is done to help ensure that any unexpected
and unfreed values are brought to your attention so that you can bug us to keep
the module updated properly; otherwise the potential for memory leaks due to
dangling circular references will exist.  

=cut

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
        my $ref = ref($item);
        if ($ref =~ /^Text::PDF::/o)
        {
            $item->release();
        }
        elsif ($ref eq 'ARRAY')
        {
            push( @tofree, @{$item} );
        }
        elsif ($ref eq 'HASH')
        {
            push( @tofree, values %{$item} );
            map { delete $item->{$_} } keys %{$item};
        }
    }
}

=head2 $p->append_file()

Appends the objects for output to the read file and then appends the appropriate tale.

=cut

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

# added v0.09
    foreach $t (grep ($_ !~ m/^\s/o, keys %$self))
    { $tdict->{$t} = $self->{$t} unless defined $tdict->{$t}; }

    $fh->seek($self->{' epos'}, 0);
    $self->out_trailer($tdict);
    close($self->{' OUTFILE'});
}

=head2 $p->out_file($fname)

Writes a PDF file to a file of the given filename based on the current list of
objects to be output. It creates the trailer dictionary based on information
in $self.

$fname may be an IO object;

=cut

sub out_file
{
    my ($self, $fname) = @_;

    $self->create_file($fname);
    $self->close_file;
    $self;
}


=head2 $p->create_file($fname)

Creates a new output file (no check is made of an existing open file) of
the given filename or IO object. Note, make sure that $p->{' version'} is set
correctly before calling this function.

=cut

sub create_file
{
    my ($self, $fname) = @_;
    my ($fh);

    $self->{' fname'} = $fname;
    if (ref $fname)
    { $fh = $fname; }
    else
    {
        $fh = IO::File->new(">$fname") || die "Unable to open $fname for writing";
        binmode $fh;
    }

    $self->{' OUTFILE'} = $fh;
    $fh->print('%PDF-1.' . ($self->{' version'} || '2') . "\n");
    $fh->print("%�쏢\n");              # and some binary stuff in a comment
    $self;
}


=head2 $p->close_file

Closes up the open file for output by outputting the trailer etc.

=cut

sub close_file
{
    my ($self) = @_;
    my ($fh, $tdict, $t);
    
    $tdict = PDFDict();
    $tdict->{'Info'} = $self->{'Info'} if defined $self->{'Info'};
#   $tdict->{'ID'} = $self->{'ID'} if defined $self->{'ID'};
    $tdict->{'Root'} = $self->{' newroot'} ne "" ? $self->{' newroot'} : $self->{'Root'};

# remove all freed objects from the outlist, AND the outlist_cache
    unless ($self->{' update'})
    {
        my @newoutlist;
        foreach my $item (@{$self->{' outlist'}})
        {
            if ($item->{' isfree'})
            {
                delete $self->{' outlist_cache'}{$item};
            }
            else
            {
                push( @newoutlist, $item );
            }
        }
        $self->{' outlist'} = \@newoutlist;
    }



    $tdict->{'Size'} = $self->{'Size'} || PDFNum(1);
    $tdict->{'Prev'} = PDFNum($self->{' loc'}) if ($self->{' loc'});
    if ($self->{' update'})
    {
        foreach $t (grep ($_ !~ m/^[\s\-]/o, keys %$self))
        { $tdict->{$t} = $self->{$t} unless defined $tdict->{$t}; }

        $fh = $self->{' INFILE'};
        $fh->seek($self->{' epos'}, 0);
    }

    $self->out_trailer($tdict);
    close($self->{' OUTFILE'});
    MacPerl::SetFileInfo("CARO", "TEXT", $self->{' fname'})
            if ($^O eq "MacOS" && !ref($self->{' fname'}));
    $self;
}

=head2 ($value, $str) = $p->readval($str, %opts)

Reads a PDF value from the current position in the file. If $str is too short
then read some more from the current location in the file until the whole object
is read. This is a recursive call which may slurp in a whole big stream (unprocessed).

Returns the recursive data structure read and also the current $str that has been
read from the file.

=cut

sub readval
{
    my ($self, $str, %opts) = @_;
    my ($fh) = $self->{' INFILE'};
    my ($res, $key, $value, $k);

    $str = update($fh, $str);
    if ($str =~ m/^\<\<\s*$cr?(.*?)$/so)
    {
        $str = $1;
        $str = update($fh, $str);
        $res = PDFDict();
        while ($str !~ m/^\>\>$cr?/o)
        {
            if ($str =~ m|^/([a-zA-Z0-9+\-!\"\$\&\'\*\,\.\:\;\=\?\@\\\^\_\`\|\~]+)$cr?(.*?)$|so)
            {
                $k = $1;
                $str = $2;
#                $key = PDFName($k);
                ($value, $str) = $self->readval($str, %opts);
                $res->{$k} = $value;
            } elsif ($str =~ m/^$cr(.*?)$/so)
            {
                $str = $1;
            }
        $str = update($fh, $str);                           # thanks gareth.jones@stud.man.ac.uk
        }
        $str =~ s/^\>\>$cr?//o;
        $str = update($fh, $str);
        if (($str =~ m/^stream$cr(.*?)$/soi) && ($res->{'Length'}->val != 0))           # stream
        {
            $str = $1;
            $k = $res->{'Length'}->val;
            $res->{' streamsrc'} = $fh;
            $res->{' streamloc'} = $fh->tell - length($str);
            unless ($opts{'nostreams'})
            {
                if ($k > length($str))
                {
                    $value = $str;
                    $k -= length($str);
                    read ($fh, $str, $k + 11);          # slurp the whole stream!
                } else
                { $value = ''; }
                $value .= substr($str, 0, $k);
                $res->{' stream'} = $value;
                $res->{' nofilt'} = 1;
                $str = update($fh, $str);
                $str =~ s/^endstream$cr//oi;
            }
        }

        bless $res, $types{$res->{'Type'}->val}
                if (defined $res->{'Type'} && defined $types{$res->{'Type'}->val});
    } elsif ($str =~ m/^([0-9]+)\s+([0-9]+)\s+R$cr?(.*?)$/so)                  # objind
    {
        $k = $1;
        $value = $2;
        $str = $3;
        unless ($res = $self->test_obj($k, $value))
        {
            $res = Text::PDF::Objind->new();
            $res->{' objnum'} = $k;
            $res->{' objgen'} = $value;
            $self->add_obj($res, $k, $value);
        }
        $res->{' parent'} = $self;
        $res->{' realised'} = 0;
    } elsif ($str =~ m/^([0-9]+)\s+([0-9]+)\s+obj$cr?(.*?)$/soi)               # object data
    {
        my ($obj);
        
        $k = $1;
        $value = $2;
        $str = $3;
        ($obj, $str) = $self->readval($str, %opts, 'objnum' => $k, 'objgen' => $value);
        if ($res = $self->test_obj($k, $value))
        { $res->merge($obj); }
        else
        {
            $res = $obj;
            $self->add_obj($res, $k, $value);
            $res->{' realised'} = 1;
        }
        $str = update($fh, $str);       # thanks to kundrat@kundrat.sk
        $str =~ s/^endobj$cr//o;
    } elsif ($str =~ m{^/([a-zA-Z0-9+\-!\"\$\&\'\*\,\.\:\;\=\?\@\\\^\_\`\|\~]+)$cr?(.*?)$}so)        # name
    {
        # " <- Fix colourization
        $value = $1;
        $str = $2;
        $res = Text::PDF::Name->from_pdf($value);
    } elsif (0 == index( $str, '(' ))
    {
        $str =~ s/^\(//o;
        $fh->read($str, 255, length($str)) while ($str !~ m/(?:[^\\]\)|^\))/o);     # thanks to kundrat@kundrat.sk
        ($value, $str) = ($str =~ /^((?:\\.|[^)])*)\)\s*$cr?(.*?)$/so);
        $res = Text::PDF::String->from_pdf($value);
    } elsif (0 == index( $str, '<' ))                                          # hex-string
    {
        $str =~ s/^<//o;
        $fh->read($str, 255, length($str)) while (0 > index( $str, '>' ));
        ($value, $str) = ($str =~ /^(.*?)\>\s*$cr?(.*?)$/so);
        $res = Text::PDF::String->from_pdf("<" . $value . ">");
    } elsif ($str =~ m/^\[$cr?/o)                                      # array
    {
        $str =~ s/^\[$cr?//o;
        $res = PDFArray();
        while ($str !~ m/^\]$cr?/o)
        {
            ($value, $str) = $self->readval($str, %opts);
            $res->add_elements($value);
        }
        $str =~ s/^\]$cr?//oi;
    } elsif ($str =~ m/^(true|false)$cr?/oi)                        # boolean
    {
        $value = $1;
        $str =~ s/^(?:true|false)$cr?//o;
        $res = Text::PDF::Bool->from_pdf($value);
    } elsif ($str =~ m/^([+-.0-9]+)\s*$cr?/o)                             # number
    {
        $value = $1;
        $str =~ s/^([+-.0-9]+)\s*$cr?//o;
        $res = Text::PDF::Number->from_pdf($value);
    } elsif ($str =~ m/^null$cr?/oi)
    {
        $str =~ s/^null$cr?//oi;
        $res = undef;
    }
    return ($res, $str);
}


=head2 $ref = $p->read_obj($objind)

Given an indirect object reference, locate it and read the object returning
the read in object.

=cut

sub read_obj
{
    my ($self, $objind, %opts) = @_;
    my ($loc, $res, $str, $oldloc);

#    return ($objind) if $self->{' objects'}{$objind->uid};
    $res = $self->read_objnum($objind->{' objnum'}, $objind->{' objgen'}, %opts) || return undef;
    $objind->merge($res) unless ($objind eq $res);
    return $objind;
}


=head2 $ref = $p->read_objnum($num, $gen, %opts)

Returns a fully read object of given number and generation in this file

=cut

sub read_objnum
{
    my ($self, $num, $gen, %opts) = @_;
    my ($res, $loc, $str, $oldloc);

    $loc = $self->locate_obj($num, $gen) || return undef;
    $oldloc = $self->{' INFILE'}->tell;
    $self->{' INFILE'}->seek($loc, 0);
    ($res, $str) = $self->readval('', %opts, 'objnum' => $num, 'objgen' => $gen);
    $self->{' INFILE'}->seek($oldloc, 0);
    $res;
}


=head2 $objind = $p->new_obj($obj)

Creates a new, free object reference based on free space in the cross reference chain.
If nothing free then thinks up a new number. If $obj then turns that object into this
new object rather than returning a new object.

=cut

sub new_obj
{
    my ($self, $base) = @_;
    my ($res);
    my ($tdict, $i, $ni, $ng);

    if (scalar @{$self->{' free'}} > 0)
    {
        $res = shift(@{$self->{' free'}});
        if (defined $base)
        {
            my ($num, $gen) = @{$self->{' objects'}{$res->uid}};
            $self->remove_obj($res);
            $self->add_obj($base, $num, $gen);
            return $self->out_obj($base);
        }
        else
        {
            $self->{' objects'}{$res->uid}[2] = 0;
            return $res;
        }
    }

    $tdict = $self;
    while (defined $tdict)
    {
        $i = $tdict->{' xref'}{$i}[0];
        while ($i != 0)
        {
            ($ni, $ng) = @{$tdict->{' xref'}{$i}};
            if (!defined $self->locate_obj($i, $ng))
            {
                if (defined $base)
                {
                    $self->add_obj($base, $i, $ng);
                    return $base;
                }
                else
                {
                    $res = $self->test_obj($i, $ng)
                            || $self->add_obj(Text::PDF::Objind->new(), $i, $ng);
                    $tdict->{' xref'}{$i}[0] = $tdict->{' xref'}{$i}[0];
                    $self->out_obj($res);
                    return $res;
                }
            }
            $i = $ni;
        }
        $tdict = $tdict->{' prev'}
    }

    $i = $self->{' maxobj'}++;
    if (defined $base)
    {
        $self->add_obj($base, $i, 0);
        $self->out_obj($base);
        return $base;
    }
    else
    {
        $res = $self->add_obj(Text::PDF::Objind->new(), $i, 0);
        $self->out_obj($res);
        return $res;
    }
}


=head2 $p->out_obj($objind)

Indicates that the given object reference should appear in the output xref
table whether with data or freed.

=cut

sub out_obj
{
    my ($self, $obj) = @_;

    # This is why we've been keeping the outlist CACHE around; to speed
    # up this method by orders of magnitude (it saves up from having to
    # grep the full outlist each time through as we'll just do a lookup
    # in the hash) (which is super-fast).
    if (!exists $self->{' outlist_cache'}{$obj})
    {
        push( @{$self->{' outlist'}}, $obj );
        $self->{' outlist_cache'}{$obj}++;
    }
    $obj;
}


=head2 $p->free_obj($objind)

Marks an object reference for output as being freed.

=cut

sub free_obj
{
    my ($self, $obj) = @_;

    push(@{$self->{' free'}}, $obj);
    $self->{' objects'}{$obj->uid}[2] = 1;
    $self->out_obj($obj);
}


=head2 $p->remove_obj($objind)

Removes the object from all places where we might remember it

=cut

sub remove_obj
{
    my ($self, $objind) = @_;

# who says it has to be fast
    delete $self->{' objects'}{$objind->uid};
    delete $self->{' outlist_cache'}{$objind};
    delete $self->{' printed_cache'}{$objind};
    @{$self->{' outlist'}} = grep($_ ne $objind, @{$self->{' outlist'}});
    @{$self->{' printed'}} = grep($_ ne $objind, @{$self->{' printed'}});
    $self->{' objcache'}{$objind->{' objnum'}, $objind->{' objgen'}} = undef
            if ($self->{' objcache'}{$objind->{' objnum'}, $objind->{' objgen'}} eq $objind);
    $self;
}


=head2 $p->ship_out(@objects)

Ships the given objects (or all objects for output if @objects is empty) to
the currently open output file (assuming there is one). Freed objects are not
shipped, and once an object is shipped it is switched such that this file
becomes its source and it will not be shipped again unless out_obj is called
again. Notice that a shipped out object can be re-output or even freed, but
that it will not cause the data already output to be changed.

=cut

sub ship_out
{
    my ($self, @objs) = @_;
    my ($n, $fh, $objind, $i, $j);
    my ($objnum, $objgen);

    return unless defined($fh = $self->{' OUTFILE'});
    seek($fh, 0, 2);            # go to the end of the file

    @objs = @{$self->{' outlist'}} unless (scalar @objs > 0);
    foreach $objind (@objs)
    {
        next unless $objind->is_obj($self);
        $j = -1;
        for ($i = 0; $i < scalar @{$self->{' outlist'}}; $i++)
        {
            if ($self->{' outlist'}[$i] eq $objind)
            {
                $j = $i;
                last;
            }
        }
        next if ($j < 0);
        splice(@{$self->{' outlist'}}, $j, 1);
        delete $self->{' outlist_cache'}{$objind};
        next if grep {$_ eq $objind} @{$self->{' free'}};

        $self->{' locs'}{$objind->uid} = $fh->tell;
        ($objnum, $objgen) = @{$self->{' objects'}{$objind->uid}}[0..1];
        $fh->printf("%d %d obj\n", $objnum, $objgen);
        $objind->outobjdeep($fh, $self, 'objnum' => $objnum, 'objgen' => $objgen);
        $fh->print("\nendobj\n");

        # Note that we've output this obj, not forgetting to update the cache
        # of whats printed.
        unless (exists $self->{' printed_cache'}{$objind})
        {
            push( @{$self->{' printed'}}, $objind );
            $self->{' printed_cache'}{$objind}++;
        }
    }
    $self;
}


=head1 PRIVATE METHODS & FUNCTIONS

The following methods and functions are considered private to this class. This
does not mean you cannot use them if you have a need, just that they aren't really
designed for users of this class.

=head2 $offset = $p->locate_obj($num, $gen)

Returns a file offset to the object asked for by following the chain of cross
reference tables until it finds the one you want.

=cut

sub locate_obj
{
    my ($self, $num, $gen) = @_;
    my ($tdict, $ref);

    $tdict = $self;
    while (defined $tdict)
    {
        if (ref $tdict->{' xref'}{$num})
        {
            $ref = $tdict->{' xref'}{$num};
            if ($ref->[1] == $gen)
            {
                return $ref->[0] if ($ref->[2] eq "n");
                return undef;       # if $ref->[2] eq "f"
            }
        }
        $tdict = $tdict->{' prev'}
    }
    return undef;
}


=head2 update($fh, $str)

Keeps reading $fh for more data to ensure that $str has at least a line full
for C<readval> to work on. At this point we also take the opportunity to ignore
comments.

=cut

sub update
{
    my ($fh, $str) = @_;

    $fh->read($str, 255, length($str)) while ($str !~ m/$cr/o);
    while ($str =~ /^\s*\%(.*?)$cr(.*?)$/so)
    {
        $str = $2;              # thanks to kundrat@kundrat.sk 
        $fh->read($str, 255, length($str)) while ($str !~ m/$cr/o);
    }
    $str;
}


=head2 $objind = $p->test_obj($num, $gen)

Tests the cache to see whether an object reference (which may or may not have
been getobj()ed) has been cached. Returns it if it has.

=cut

sub test_obj
{ $_[0]->{' objcache'}{$_[1], $_[2]}; }


=head2 $p->add_obj($objind)

Adds the given object to the internal object cache.

=cut

sub add_obj
{
    my ($self, $obj, $num, $gen) = @_;

    $self->{' objcache'}{$num, $gen} = $obj;
    $self->{' objects'}{$obj->uid} = [$num, $gen];
    return $obj;
}


=head2 $tdict = $p->readxrtr($xpos)

Recursive function which reads each of the cross-reference and trailer tables
in turn until there are no more.

Returns a dictionary corresponding to the trailer chain. Each trailer also
includes the corresponding cross-reference table.

The structure of the xref private element in a trailer dictionary is of an
anonymous hash of cross reference elements by object number. Each element
consists of an array of 3 elements corresponding to the three elements read
in [location, generation number, free or used]. See the PDF Specification
for details.

=cut

sub readxrtr
{
    my ($self, $xpos) = @_;
    my ($tdict, $xlist, $buf, $xmin, $xnum, $fh, $xdiff);

    $fh = $self->{' INFILE'};
    $fh->seek($xpos, 0);
    $fh->read($buf, 22);
    if ($buf !~ m/^xref$cr/oi)
    { die "Malformed xref in PDF file $self->{' fname'}"; }
    $buf =~ s/^xref$cr//oi;

    $xlist = {};
    while ($buf =~ m/^([0-9]+)\s+([0-9]+)$cr(.*?)$/so)
    {
        $xmin = $1;
        $xnum = $2;
        $buf = $3;
        $xdiff = length($buf);
        
        $fh->read($buf, 20 * $xnum - $xdiff + 15, $xdiff);
        while ($xnum-- > 0 && $buf =~ s/^0*([0-9]*)\s+0*([0-9]+)\s+(\S)$cr//o)
        { $xlist->{$xmin++} = [$1, $2, $3]; }
    }

    if ($buf !~ /^trailer$cr/oi)
    { die "Malformed trailer in PDF file $self->{' fname'} at " . ($fh->tell - length($buf)); }

    $buf =~ s/^trailer$cr//oi;

    ($tdict, $buf) = $self->readval($buf);
    $tdict->{' loc'} = $xpos;
    $tdict->{' xref'} = $xlist;
    $self->{' maxobj'} = $xmin if $xmin > $self->{' maxobj'};
    $tdict->{' prev'} = $self->readxrtr($tdict->{'Prev'}->val)
                if (defined $tdict->{'Prev'} && $tdict->{'Prev'}->val != 0);
    return $tdict;
}


=head2 $p->out_trailer($tdict)

Outputs the body and trailer for a PDF file by outputting all the objects in
the ' outlist' and then outputting a xref table for those objects and any
freed ones. It then outputs the trailing dictionary and the trailer code.

=cut

sub out_trailer
{
    my ($self, $tdict) = @_;
    my ($objind, $j, $i, $iend, @xreflist, $first, $k, $xref, $tloc, @freelist);
    my (%locs, $size);
    my ($fh) = $self->{' OUTFILE'};

    while (@{$self->{' outlist'}})
    { $self->ship_out; }
    
#    foreach $objind (@{$self->{' outlist'}})
#    {
#        next if ($self->{' objects'}{$objind->uid}[2]);
#        $locs{$objind->uid} = $fh->tell;
#        $fh->printf("%d %d obj\n", @{$self->{' objects'}{$objind->uid}}[0..1]);
#        $objind->outobjdeep($fh, $self);
#        $fh->print("\nendobj\n");
#    }
    $size = @{$self->{' printed'}} + @{$self->{' free'}};
    $tdict->{'Size'} = PDFNum($tdict->{'Size'}->val + $size);

    $tloc = $fh->tell;
    $fh->print("xref\n");

    @xreflist = sort {$self->{' objects'}{$a->uid}[0] <=>
                $self->{' objects'}{$b->uid}[0]}
                        (@{$self->{' printed'}}, @{$self->{' free'}});
    @freelist = sort {$self->{' objects'}{$a->uid}[0] <=>
                $self->{' objects'}{$b->uid}[0]} @{$self->{' free'}};

    $j = 0; $first = -1; $k = 0;
    for ($i = 0; $i <= $#xreflist + 1; $i++)
    {
#        if ($i == 0)
#        {
#            $first = $i; $j = $xreflist[0]->{' objnum'};
#            $fh->printf("0 1\n%010d 65535 f \n", $ff);
#        }
        if ($i > $#xreflist || $self->{' objects'}{$xreflist[$i]->uid}[0] != $j + 1)
        {
            $fh->print(($first == -1 ? "0 " : "$self->{' objects'}{$xreflist[$first]->uid}[0] ") . ($i - $first) . "\n");
            if ($first == -1)
            {
                $fh->printf("%010d 65535 f \n", defined $freelist[$k] ? $self->{' objects'}{$freelist[$k]->uid}[0] : 0);
                $first = 0;
            }
            for ($j = $first; $j < $i; $j++)
            {
                $xref = $xreflist[$j];
                if ("$freelist[$k]" eq "$xref")
                {
                    $k++;
                    $fh->print(pack("A10AA5A4",
                            sprintf("%010d", (defined $freelist[$k] ?
                                    $self->{' objects'}{$freelist[$k]->uid}[0] : 0)), " ",
                            sprintf("%05d", $self->{' objects'}{$xref->uid}[1] + 1),
                            " f \n"));
                } else
                {
                    $fh->print(pack("A10AA5A4", sprintf("%010d", $self->{' locs'}{$xref->uid}), " ",
                            sprintf("%05d", $self->{' objects'}{$xref->uid}[1]),
                            " n \n"));
                }
            }
            $first = $i;
            $j = $self->{' objects'}{$xreflist[$i]->uid}[0] if ($i < scalar @xreflist);
        } else
        { $j++; }
    }
    $fh->print("trailer\n");
    $tdict->outobjdeep($fh, $self);
    $fh->print("\nstartxref\n$tloc\n" . '%%EOF' . "\n");
}


=head2 Text::PDF::File->_new

Creates a very empty PDF file object (used by new and open)

=cut

sub _new
{
    my ($class) = @_;
    my ($self) = {};

    bless $self, $class;
    $self->{' outlist'} = [];
    $self->{' outlist_cache'} = {};     # A cache of whats in the 'outlist'
    $self->{' maxobj'} = 1;
    $self->{' objcache'} = {};
    $self->{' objects'} = {};
    $self;
}

1;

=head1 AUTHOR

Martin Hosken Martin_Hosken@sil.org

Copyright Martin Hosken 1999 and onwards

No warranty or expression of effectiveness, least of all regarding anyone's
safety, is implied in this software or documentation.

=head2 Licensing

This Perl Text::PDF module is licensed under the Perl Artistic License.

