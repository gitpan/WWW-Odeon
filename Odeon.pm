package WWW::Odeon;

use warnings;
use strict;

use LWP::Simple qw( get );

use vars '$VERSION';

our @ISA = qw( Exporter );
our @EXPORT = qw( get_regions get_cinemas get_details );

$VERSION = '1.03';


use constant REGIONS => 'http://www.odeon.co.uk/pls/odeon/Display.page?page=menu_items.js';
use constant CINEMAS => 'http://www.odeon.co.uk/pls/Odeon/display.page?Page=regionx.js&Parameters=REGION~';
use constant THEATRE => 'http://www.odeon.co.uk/pls/Odeon/Display.page?page=cinema_xy.js&Parameters=CINEMA~';




sub get_regions {

  my $content = get( REGIONS ) || return;
  
  if ( $content =~ /var c_menu = \[([^\]]+)]/ ) {
    return _get_items( $1 );
  }

  return;

}


sub get_cinemas {

  my $region = shift || return;

  my $content = get( CINEMAS . $region ) || return;
  if ( $content =~ /var cinemas=\[([^\]]+)/ ) {
    return _get_items( $1 );
  }

  return;

}


sub get_details {

  my $theatre = shift || return;

  # copies of the 'd', 'f', 'p' arrays from Odeon's javascript
  my ( @d, @f, @p );
  # not currently used: will be available in a future version
  my ( @photo );
  my ( %data );

  $theatre =~ tr/ /_/;   # quick sanity check
  my $content = get( THEATRE . $theatre ) || return;

  if ( $content =~ /var d = \[([^]]+)/ ) {
    @d = _get_items( $1 );
  }
  if ( $content =~ /var f = \[([^]]+)/ ) {
    @f = _get_items( $1 );
  }
  if ( $content =~ /var p = \[([^]]+)/ ) {
    @p = _get_items( $1 );
  }
  if ( $content =~ /var photo = \[([^]]+)/ ) {
    @photo = _get_items( $1 );
  }

  # The data string in the javascript is composed of entries for this cinema in the format
  # date (2 chars), film (2 chars), performance details (2 chars)

  # Not sure why Odeon's javascript made this a string rather than an array, but we'll
  # chop it up and turn it into a hash

  if ( $content =~ /var data = "([0-9A-F]+)"/ ) {
    my @records = grep { length } split /(.{6})/, $1;
    foreach my $record ( @records ) {
      my ( $idate, $ifilm, $iperf ) = $record =~ /(..)(..)(..)/;
        # indexes set above are hex
        my ( $perftime, $perfavail ) = split / /, $p[hex $iperf];
        $data{ $d[hex $idate] }{ $f[hex $ifilm] }{ $perftime } = $perfavail;
    }
  }

  return \%data;

}


# The javascript arrays are of items that are [single|double]-quote delimited and comma-separated
# As far as I can tell nothing ever has a comma in the item name, which makes parsing very simple
sub _get_items {

  my @items;

  for ( split /,/, shift ) {
    tr/"'\\//d;
    push @items, $_;
  }

  @items;

}


1;



=head1 NAME

WWW::Odeon - A simple API for screen-scraping the www.odeon.co.uk website


=head1 SYNOPSIS

 use WWW::Odeon;
 my @regions = get_regions();
 my @cinemas = get_cinemas( $regions[2] );
 my $details = get_details( $cinemas[4] );

 my @dates = keys %$details;
 foreach my $day ( @dates ) {
   my @films = keys %{ $details->{$day} };
   foreach my $film ( @films ) {
     while ( my ( $showing, $availability ) = each %{ $details->{$day}->{$film} } ) {
       print "Film '$film' is $availability at $showing on $day\n";
     }
   }
 }


=head1 DESCRIPTION

This module allows data about films showing at Odeon cinemas in the United Kingdom to
be retrieved. The only prerequisite is L<LWP::Simple> -- and a connection to the web!

To fully use this module it is necessary to understand the hierarchy by which Odeon UK
structures its film information. The country is divided into regions, each region
contains multiple cinemas, each cinema shows several films, at various times, for
several days. This structure is represented in the module API.

=over 3

=item get_regions

Retrieves a list of all the available regions. Unless Odeon UK radically change their
systems then this is likely to remain static; the regions are currently:

Central_London, Channel_Islands, Greater_London, Midlands, North_East_England, North_West_England, Scotland, South_East_England, South_West_England, Wales

Note that regions made up of multiple words use underscores (as shown) not spaces, so
for display it would be recommended to do a C<tr/_/ /> for each item in the array. The
order in which regions are retrieved is not guaranteed: in particular, it is not
guaranteed to be alphabetical order.

If the attempt to retrieve the data fails, an empty list is returned.

=item get_cinemas( $region )

Retrieves a list of all cinemas for a given region. The region name should be identical
to that returned by the L<get_regions()> subroutine.

If the attempt to retrieve the data fails, an empty list is returned.

=item get_details( $cinema )

Retrieve the film and showing details for a given cinema. Returns a reference to a hash
containing the data for the cinema requested, which should be a string identical to
one returned by the L<get_cinemas()> subroutine.

The hashref points at a hash which has the following general structure:

 $details{ $day => { $title => { $time => $availability } } }

In other words, if C<$details> is the hashref returned by C<get_details()>, then:

C<keys %$details> will be a list of dates, C<keys %{$details-E<gt>{DATE_FROM_LIST}}> will be
a list of film titles, and C<keys %{$details-E<gt>{DATE_FROM_LIST}-E<gt>{FILM_TITLE}}}> will be a
list of film times. For each time the value will be either 'available' or 'sold out'
depending on whether or not any tickets are still available for purchase.



=back


=head1 BACKGROUND

This module provides a simple procedure-oriented API for accessing film times from the
Odeon UK website at http://www.odeon.co.uk/. It was inspired by Matthew Somerville's
I<Accessible Odeon> website at http://www.dracos.co.uk/odeon/ which was closed down in
July 2004 after receiving "Cease and Desist"-type notifications from Odeon's lawyers.

As the official Odeon site is extremely poorly written -- it requires Microsoft Internet
Explorer 5.x or 6.x to work, and then only if Javascript is enabled -- it was felt that
there was a strong community requirement for a continuation of an accessible form of the
website. This module allows Odeon's data to be retrieved so that it can be displayed by
a CGI or command-line program, and the hope that if an open source solution is available
to the community then Odeon will not be able to keep on shutting down each and every
"Accessible" front-end to their site, or ideally, will create a working version of their
own site.


=head1 COPYRIGHT

Copyright 2004 Iain Tatch E<lt>iaint@cpan.orgE<gt>

This software is distributed under the Artistic Licence, a copy of which should
accompany the distribution, or if not, can be found on the Web at
http://www.opensource.org/licenses/artistic-license.php

