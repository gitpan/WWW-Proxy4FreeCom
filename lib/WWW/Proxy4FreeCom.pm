package WWW::Proxy4FreeCom;

use warnings;
use strict;

our $VERSION = '0.001';

use Carp;
use URI;
use LWP::UserAgent;
use HTML::TokeParser::Simple;
use base 'Class::Data::Accessor';
__PACKAGE__->mk_classaccessors qw(
    list
    filtered_list
    error
    ua
    debug
);

sub new {
    my $self = bless {}, shift;

    croak "Must have even number of arguments to new()"
        if @_ & 1;
    my %args = @_;
    $args{ +lc } = delete $args{ $_ } for keys %args;

    $args{timeout} ||= 30;

    $args{ua} ||= LWP::UserAgent->new(
            timeout => $args{timeout},
            agent   => 'Mozilla/5.0 (X11; U; Linux x86_64; en-US;'
                        . ' rv:1.8.1.12) Gecko/20080207 Ubuntu/7.10 (gutsy)'
                        . ' Firefox/2.0.0.12',
    );

    $self->ua( $args{ua} );
    $self->debug( $args{debug} );

    return $self;
}

sub get_list {
    my $self = shift;
    my $custom_pages = shift;

    $self->$_(undef) for qw(list error);
    
    my @pages_list
        = defined $custom_pages
        ?  ( ref $custom_pages ? @$custom_pages : $custom_pages )
        : ( 1 );

    return $self->_set_error('Page number can only be 1..5')
        if grep { $_ < 1 or $_ > 5 } @pages_list;

    my $ua = $self->ua;

    my @proxies;
    for ( @pages_list ) {
        my $response = $ua->get('http://proxy4free.com/page' . $_ . '.html');
        if ( $response->is_success ) {
            push @proxies, $self->_parse_proxy_list( $response->content );
        }
        else {
            $self->debug
                and carp "Page $_: " . $response->status_line;
        }
    }

    return $self->list( \@proxies );
}

sub filter {
    my $self = shift;

    $self->$_(undef) for qw(error filtered_list);
    
    croak "Must have even number of arguments to filter()"
        if @_ & 1;

    my %args = @_;
    $args{ +lc } = delete $args{ $_ } for keys %args;

    my %valid_filters;
    @valid_filters{ qw(ip  port  type  country  last_test) } = (1) x 5;

    grep { not exists $valid_filters{$_} } keys %args
        and return $self->_set_error(
            'Invalid filter specified, valid ones are: '.
                join q|, |, keys %valid_filters
        );

    my $list_ref = $self->list
        or return $self->_set_error(
           'Proxy list seems to be undefined, did you call get_list() first?'
        );

    my @filtered;
    foreach my $proxy_ref ( @$list_ref ) {
        my $is_good = 0;
        for ( keys %args ) {
            $proxy_ref->{$_} eq $args{$_}
                and $is_good++;
        }

        $is_good == keys %args
            and push @filtered, { %$proxy_ref };
    }
    return $self->filtered_list( \@filtered );
}

sub _parse_proxy_list {
    my ( $self, $content ) = @_;
    my $parser = HTML::TokeParser::Simple->new( \$content );
    
    my %data_names;
    @data_names{ 1..5 } = qw(ip  port  type  country  last_test);

    my %nav;
    @nav{ qw(get_info  get_data  data_level) } = (0) x 3;

    my @data;
    my %proxy;
    while ( my $t = $parser->get_token ) {
        if ( $t->is_start_tag('tr')
            and defined $t->get_attr('class')
            and defined $t->get_attr('height')
            and $t->get_attr('class') eq 'text'
            and $t->get_attr('height') eq '10'
        ) {
            @nav{ qw(get_info level) } = (1, 1);
        }
        elsif ( $nav{get_info} == 1 and $t->is_start_tag('td') ) {
            @nav{ qw(get_data level) } = (1, 2);
            $nav{data_level}++;
        }
        elsif ( $nav{get_data} and $t->is_end_tag('td') ) {
            @nav{ qw(get_data level) } = (0, 3);
        }
        elsif ( $nav{get_data} and $t->is_text ) {
            next
                unless exists $data_names{$nav{data_level}};
            $proxy{ $data_names{$nav{data_level}} } = $t->as_is;
        }
        elsif ( $nav{get_info} == 1 and $t->is_end_tag('tr') ) {
            @nav{qw(get_info data_level level)} = (0, 0, 4);
            my %done_proxy = %proxy;
            %proxy = ();
            
            for ( values %data_names ) {
                $done_proxy{ $_ } = 'N/A'
                    unless exists $done_proxy{ $_ };
            }
            push @data, \%done_proxy;
        }
    }
    return @data;
}

sub _set_error {
    my ( $self, $error_or_response, $type ) = @_;
    if ( defined $type and $type eq 'net' ) {
        $self->error( 'Network error: ' . $error_or_response->status_line );
    }
    else {
        $self->error( $error_or_response );
    }
    return;
}

1;
__END__

=head1 NAME

WWW::Proxy4FreeCom - fetch proxy list from http://proxy4free.com/

=head1 SYNOPSIS

    use strict;
    use warnings;

    use WWW::Proxy4FreeCom;

    my $prox = WWW::Proxy4FreeCom->new;

    $prox->get_list
        or die $prox->error;

    my $filtered_ref = $prox->filter( country => 'China', type => 'anonymous' )
        or die $prox->error;

    printf "http://%s:%d (last tested on %s)\n", @$_{ qw(ip port last_test) }
        for @%filtered_ref;

=head1 DESCRIPTION

The module provides means to fetch proxy list from
L<http://proxy4free.com/> website with means to filter by certain fields.

=head1 CONSTRUCTOR

=head2 new

    my $prox = WWW::Proxy4FreeCom->new;

    my $prox = WWW::Proxy4FreeCom->new(
        timeout => 10,
        debug   => 1,
    );

    my $prox = WWW::Proxy4FreeCom->new(
        ua => LWP::UserAgent->new(
            timeout => 10,
            agent   => 'ProxUA',
        ),
    );

Constructs and returns a brand new yummy juicy WWW::Proxy4FreeCom
object. Takes a few I<optional> arguments. Possible arguments are
as follows:

=head3 timeout

    ->new( timeout => 10 );

B<Optional>. Specifies the C<timeout> argument of L<LWP::UserAgent>'s
constructor, which is used for retrieving data.
B<Defaults to:> C<30> seconds.

=head3 ua

    ->new( ua => LWP::UserAgent->new( agent => 'Foos!' ) );

B<Optional>. If the C<timeout> argument is not enough for your needs
of mutilating the L<LWP::UserAgent> object used for retrieving proxy list,
feel free
to specify the C<ua> argument which takes an L<LWP::UserAgent> object
as a value. B<Note:> the C<timeout> argument to the constructor will
not do anything if you specify the C<ua> argument as well. B<Defaults to:>
plain boring default L<LWP::UserAgent> object with C<timeout> argument
set to whatever C<WWW::Proxy4FreeCom>'s C<timeout> argument is
set to as well as C<agent> argument is set to mimic Firefox.

=head3 debug

    ->new( debug => 1 );

When C<get_list()> is called any unsuccessfull page retrievals will be
silently ignored. Setting C<debug> argument to a true value will C<carp()>
any network errors if they occur.

=head1 METHODS

=head2 get_list

    my $list_ref = $prox->get_list # just from the "proxy list 1"
        or die $prox->error;

    my $list_ref = $prox->get_list( 2 ) # just from the "proxy list 2"
        or die $prox->error;

    $prox->get_list( [3,5] ) # lists 3 and 5 only
        or die $prox->error;

Instructs the objects to fetch a fresh list of proxies from
L<http://proxy4free.com/>. If an error occured returns C<undef> or an
empty list depending on the context. On success returns an arrayref of
hashrefs each representing a proxy entry. Takes one optional argument which
can be either a number between 1 and 5 (inclusive) or an arrayref with
several of these numbers. The numbers represent the numbers of "proxy list"s
on L<http://proxy4free.com/>. B<By default> only the list from the
"proxy list 1" will be fetched.

Each hashref in the returned arrayref is in a following format
(if any field is missing on the site it will be reported as a string
C<N/A>):

    {
        'country' => 'Indonesia',
        'ip' => '202.173.23.141',
        'last_test' => '2008-03-14',
        'type' => 'transparent',
        'port' => '8080'
    }

=head2 filter

    my $filtered_ref = $prox->filter( country => 'China', port => 80 )
        or die $prox->error;

Must be called after a successfull call to C<get_list()>.
Returns an arrayref of hashrefs each of which will be representing the
proxies the exact same way C<get_list()> returns them except proxies will
be filtered by a "ruleset".
Takes a "ruleset" for filtering which is a set of key/value arguments.
The valid names of arguments are the keys of the "proxy" hashefs, namely:
C<country>, C<ip>, C<last_test>, C<type>, and C<port>. Will return either
C<undef> or an empty list (depending on the context) if called with an
invalid filter or last C<get_list()> was unsuccessfull and C<error()> method
will tell you exactly what was wrong.

=head2 error

    my $filtered_ref = $prox->filter( country => 'China', port => 80 )
        or die $prox->error;

    $prox->get_list # just from the "proxy list 1"
        or die $prox->error;

If either C<filter()> or C<get_list()> methods fail they will return
either C<undef> or an empty list depending on the context and the reason
for the error will be available via C<error()> method. Takes no arguments,
return a human parsable error message explaining the failure.

=head2 list

    my $last_list_ref = $prox->list;

Must be called after a successfull call to C<get_list()>. Takes no arguments,
returns the same arrayref of hashref as last call to C<get_list()> returned.

=head2 filtered_list

    my $last_filtered_ref = $prox->filtered_list;

Must be called after a successfull call to C<filter()>. Takes no arguments,
returns the same arrayref of hashref as last call to C<filter()> returned.

=head2 ua

    my $old_LWP_UA_obj = $prox->ua;

    $prox->ua( LWP::UserAgent->new( timeout => 10, agent => 'foos' );

Returns a currently used L<LWP::UserAgent> object used for retrieving
data. Takes one optional argument which must be an L<LWP::UserAgent>
object, and the object you specify will be used in any subsequent calls
to C<get_list()>.

=head2 debug

    my $old_debug => $prox->debug;

    $prox->debug(1);

Returns a currently set debug value, when called with an optional argument
(which can be either a true or false value) will set debug to that value.
See C<debug> argument to constructor for more information.

=head1 AUTHOR

'Zoffix, C<< <'zoffix at cpan.org'> >>
(L<http://zoffix.com>, L<http://haslayout.net>)

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-proxy4freecom at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Proxy4FreeCom>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Proxy4FreeCom

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Proxy4FreeCom>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Proxy4FreeCom>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Proxy4FreeCom>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Proxy4FreeCom>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 'Zoffix, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
