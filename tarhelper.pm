use File::Find;
use Archive::Tar;

package Archive::Tar::File;

sub _new_from_file {
    my $class       = shift;
    my $path        = shift;        
    return unless defined $path;
    my $type        = __PACKAGE__->_filetype($path);
    my $data        = '';
   READ: { 
        unless ($type == DIR ) {
            my $fh = IO::File->new;
            unless( $fh->open($path) ) {
                last READ if $type == SYMLINK;
                return;
            }
            binmode $fh;
            $data = do { local $/; <$fh> };
            close $fh;
        }
    }
    my @items       = qw[mode uid gid size mtime];
    my %hash        = map { shift(@items), $_ } (lstat $path)[2,4,5,7,9];
    $hash{size}     = 0 if ($type == DIR or $type == SYMLINK);
    $hash{mtime}    -= TIME_OFFSET;
    $hash{mode}     = 0640;
    my $obj = {
        %hash,
        name        => '',
        chksum      => CHECK_SUM,
        type        => $type,
        linkname    => ($type == SYMLINK and CAN_READLINK)
                            ? readlink $path
                            : '',
        magic       => MAGIC,
        version     => TAR_VERSION,
        uname       => UNAME->( $hash{uid} ),
        gname       => GNAME->( $hash{gid} ),
        devmajor    => 0,   # not handled
        devminor    => 0,   # not handled
        prefix      => '',
        data        => $data,
    };
    bless $obj, $class;
    my($prefix,$file) = $obj->_prefix_and_file( $path );
    $obj->prefix( $prefix );
    $obj->name( $file );
    return $obj;
}

package main;

sub mytar
{
  my @files;
  my $arc= shift @ARGV;
  find( sub { push @files, $File::Find::name;
                print $File::Find::name.$/ if $verbose }, @ARGV );

    Archive::Tar->create_archive( $arc, 0, grep { !-d $_ } @files );
}

1;