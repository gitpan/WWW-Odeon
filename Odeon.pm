package WWW::Odeon;

use warnings;
use strict;

use LWP::Simple qw( get );
use Carp;

use vars '$VERSION';

our @ISA = qw( Exporter );
our @EXPORT = qw( get_regions get_cinemas get_details );

$VERSION = '1.07';


use constant REGIONS => 'http://www.odeon.co.uk/pls/odeon/Display.page?page=menu_items.js';
use constant CINEMAS => 'http://www.odeon.co.uk/pls/Odeon/display.page?Page=regionx.js&Parameters=REGION~';
use constant THEATRE => 'http://www.odeon.co.uk/pls/Odeon/Display.page?page=cinema_xy.js&Parameters=CINEMA~';



### Procedural interface

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


### OO Interface

sub new {

  my $class = shift;
  my $self = bless {}, $class;

  $self->{_cache_secs} = 0;
  $self->flush_cache;

  return $self;

}


sub cache_time {

  my $self = shift;

  if ( $_[0] ) {
    $self->{_cache_secs} = 60 * shift;
  }

  $self->{_cache_secs} / 60;

}


sub cached {

  shift->{_cache_hit};

}


sub flush_cache {

  my $self = shift;
  $self->{_cache} = ();
  $self->{_cache_hit} = 0;

  return;

}


sub regions {

  my $self = shift;

  $self->{_cache}{regions_last} ||= 0;
  if ( time - $self->{_cache}{regions_last} < $self->{_cache_secs} ) {
	$self->{_cache_hit} = 1;
    return $self->{_cache}{regions};
  }

  $self->{_cache_hit} = 0;
  $self->{_cache}{regions_last} = time;
  $self->{_cache}{regions} = [ get_regions() ]

}


sub cinemas {

  my $self = shift;

  my ( $region ) = @_;
  croak "No region name supplied when requesting cinema list" unless $region;
  $region =~ tr/ /_/;

  $self->{_cache}{"cinemas_${region}_last"} ||= 0;
  if ( time - $self->{_cache}{"cinemas_${region}_last"} < $self->{_cache_secs} ) {
    $self->{_cache_hit} = 1;
	return $self->{_cache}{"cinemas_$region"};
  }

  $self->{_cache_hit} = 0;
  $self->{_cache}{"cinemas_${region}_last"} = time;
  $self->{_cache}{"cinemas_$region"} = [ get_cinemas($region) ];

}


sub details {

  my $self = shift;

  my ( $cinema ) = @_;
  croak "No cinema name supplied when requesting full details" unless $cinema;

  $self->{_cache}{"details_${cinema}_last"} ||= 0;
  if ( time - $self->{_cache}{"details_${cinema}_last"} < $self->{_cache_secs} ) {
    $self->{_cache_hit} = 1;
	return $self->{_cache}{"details_{$cinema}"};
  }

  $self->{_cache_hit} = 0;
  $self->{_cache}{"details_${cinema}_last"} = time;
  $self->{_cache}{"details_$cinema"} = get_details($cinema);

}


sub films {

  my $self = shift;

  my ( $cinema ) = @_;
  croak "No cinema name supplied when requesting film titles" unless $cinema;

  unless ( exists $self->{_cache}{"details_${cinema}_last"} ) {
    $self->details( $cinema );
  }
  else {
    $self->{_cache_hit} = 1;
  }
  my %titles;
  foreach my $date ( keys %{$self->{_cache}{"details_${cinema}"}} ) {
    foreach my $title ( keys %{$self->{_cache}{"details_${cinema}"}{$date}} ) {
	  $titles{$title} = 1;
    }
  }

  return keys %titles;

}


sub dates {

  my $self = shift;

  my ( $cinema ) = @_;
  croak "No cinema name supplied when requesting available dates" unless $cinema;

  unless ( exists $self->{_cache}{"details_${cinema}_last"} ) {
    $self->details( $cinema );
  }
  else {
    $self->{_cache_hit} = 1;
  }
  my %dates;
  foreach my $date ( keys %{$self->{_cache}{"details_${cinema}"}} ) {
    $dates{$date} = 1;
  }

  return keys %dates;

}


sub availability {

  my $self = shift;
  my ( $cinema, $film, $day ) = @_;
  croak "You must supply a cinema, a film title, and a day when request availability information"
	unless $cinema && $film && $day;

  unless ( exists $self->{_cache}{"details_${cinema}_last"} ) {
    $self->details( $cinema );
  }
  else {
    $self->{_cache_hit} = 1;
  }
  my %cinema = %{$self->{_cache}{"details_${cinema}"}};
  if ( not exists $cinema{$day}{$film} ) {
	# Carp about it?
    return;
  }
  my @times;
  while ( my ($showing, $is_available) = each %{$cinema{$day}{$film}} ) {
    push @times, $showing if $is_available;
  }

  return sort _by_time @times;

}


# The javascript arrays are of items that are [single|double]-quote delimited and comma-separated
sub _get_items {

  my ( $list ) = @_;
  my @items;

  # OK, time to stop trying to be quick'n'dirty and split the
  # list up the way it always should've been done :)
  # `perldoc -q split' is your (and my) friend
  push(@items, $+) while $list =~ m{
      "([^\"\\]*(?:\\.[^\"\\]*)*)",?
    | ([^,]+),?
    | ,
  }gx;
  push(@items, undef) if substr($list,-1,1) eq ',';
										  @items;

}


# Simply sorts time strings supplied in the format 'HH:MM'
sub _by_time {

  my ( $a_HH, $a_MM, $b_HH, $b_MM );

  if ( $a =~ /^(\d\d):(\d\d)$/ ) {
    ( $a_HH, $a_MM ) = ( $1, $2 );
  }
  else {
    return 0;
  }

  if ( $b =~ /^(\d\d):(\d\d)$/ ) {
    ( $b_HH, $b_MM ) = ( $1, $2 );
  }
  else {
    return 0;
  }

  return $a_HH <=> $b_HH || $a_MM <=> $b_MM;

}


1;



=head1 NAME

WWW::Odeon - A simple API for screen-scraping the www.odeon.co.uk website


=head1 SYNOPSIS

 # Procedural interface

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

 # Object-oriented interface

 use WWW::Odeon ();

 my $odeon = new WWW::Odeon;
 $odeon->cache_time( 30 );

 my $regions = $odeon->regions;
 my $cinemas = $odeon->cinemas( $regions->[2] );
 my $details = $odeon->details( $cinemas->[4] );

 # Or directly access film data if you know the cinema name
 print "The following films are on at Odeon Leicester Square:\n";
 print join( "\n", $odeon->films('Leicester Square') );
 print "There is information about the following dates for Odeon York:\n";
 print join( "\n", $odeon->dates('York') )
 
 @showtimes = $odeon->availability( $cinema, $film, $day );


=head1 DESCRIPTION

This module allows data about films showing at Odeon cinemas in the United Kingdom to
be retrieved. The only prerequisite is L<LWP::Simple> -- and a connection to the web!

To fully use this module it is necessary to understand the hierarchy by which Odeon UK
structures its film information. The country is divided into regions, each region
contains multiple cinemas, each cinema shows several films, at various times, for
several days. This structure is represented in the module API.

=head2 Procedural Interface

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

=head2 Object-Oriented Interface

There is one important difference to be aware of between the proecdural functions and
OO methods supplied by this module. Whereas the procedural functions C<get_regions()>
and C<get_cinemas()> return lists, the equivalent OO methods C<$odeon->regions()> and
C<$odeon->cinemas()> return I<references> to arrays. Don't get caught out!

=over 3

=item new()

Creates and returns a new B<WWW::Odeon> object.

=item cache_time( $minutes )

The object-oriented API can cache the data it retrieves from the Odeon website. This has
two advantages: firstly it means that subsequent requests for the same data are returned
much faster, as there is no need to make an HTTP request, and for same reason it uses
less bandwidth and puts less strain on the I<www.odeon.co.uk> website, which is also a
good thing.

You can specify the length of time that cached data is valid for using this method.
Data that is older than the cache time will be automatically refreshed the next time it
is requested.

Due to the fact that cinema programmes are fairly static, it is recommended that quite
a long cache time is used. At a minimum a cache time of 60 (1 hour) should be used, and
for most purposes even longer, up to 240 or 480 minutes will be perfectly sufficient.

=item flush_cache()

It may occasionally be useful to flush the entire cache that the object has built up
over time, such as in a long-running program that wants to ensure data is refreshed
twice daily to reflect any updates made by Odeon. This method will achieve that goal.

=item cached()

Simply returns 1 if the last method called retrieved cached data, 0 otherwise. Might be
useful for analysis of cacheing performance.

=item regions()

Analogous to C<get_regions()> in the procedure-oriented interface, this method returns
a reference to an array of regions. Cached data will be returned when available.

=item cinemas( $region )

Analogous to C<get_cinemas()> in the procedure-oriented interface, this method returns
a reference to an array of cinema names for the specified region. Cached data will be
returned when available.

=item details( $cinema )

Analogous to C<get_details()> in the procedure-oriented interface, this method returns
a reference to a hash containing the details for the specified cinema. Cached data will
be returned when available.

See the C<get_details()> function from the procedure-oriented interface for a description
of the format of the returned data structure.

=item films( $cinema )

This will return a list of film titles that are showing at the specified cinema, using
cached data when available.

Note that it is B<not> necessary to load in the list of regions and/or cinemas
beforehand, as long as you know the I<exact> cinema title (as used by I<www.odeon.co.uk>).
So the following example is a valid perl one-liner:

 perl -MWWW::Odeon -le '$o=new WWW::Odeon;print join "\n", $o->films("Leicester Square")'

=item dates( $cinema )

This will return a list of dates for which there is film information available for the
specified cinema. This method will use cached data where available. Note that the dates
are in the format used on the Odeon website, which is I<day DD-MM-YYYY>.

It is B<not> necessary to load in the list of regions and/or cinemas
beforehand, as long as you know the I<exact> cinema title (as used by I<www.odeon.co.uk>).

=item availability( $cinema, $film, $day )

Returns a sorted list of times (in format I<HH:MM>) when the specified film is showing
at the specified cinema and date. Cached data will be used when available.

The caveats here the same as with the other methods in this class: data B<MUST> be
supplied in the format that is recognised by I<www.odeon.co.uk>, so that means the
cinema name must match one returned by C<cinemas()> and the film and requested day need
to be in the formats mentioned above.

This method can be called without any need to pre-load the list of regions and/or
cinemas.

=back


=head1 BACKGROUND

This module provides simple procedure- and object-oriented APIs for accessing film times
from the Odeon UK website at http://www.odeon.co.uk/. It was inspired by Matthew
Somerville's I<Accessible Odeon> website at http://www.dracos.co.uk/odeon/ which was
closed down in July 2004 after receiving "Cease and Desist"-type notifications from
Odeon's lawyers.

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

