package main;

use File::Find;
use Archive::Tar;

sub mytar
{
  my @files;
  my $arc= shift @ARGV;
  find( sub { push @files, $File::Find::name;
                print $File::Find::name.$/ if $verbose }, @ARGV );

    Archive::Tar->create_archive( $arc, 0, grep { !-d $_ } @files );
}

1;