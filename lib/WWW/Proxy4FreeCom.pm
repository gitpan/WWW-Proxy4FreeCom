package WWW::Proxy4FreeCom;

use warnings;
use strict;

our $VERSION = '1.003';

use Carp;
use URI;
use LWP::UserAgent;
use Mojo::DOM;

use base 'Class::Accessor::Grouped';
__PACKAGE__->mk_group_accessors( simple => qw/
    list
    error
    ua
    debug
/);

sub new {
    my $self = bless {}, shift;

    croak "Must have even number of arguments to new()"
        if @_ & 1;
    my %args = @_;
    $args{ +lc } = delete $args{ $_ } for keys %args;

    $args{timeout} ||= 30;

    $args{ua} ||= LWP::UserAgent->new(
            timeout => $args{timeout},
            agent   => 'Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:26.0)'
                        .' Gecko/20100101 Firefox/26.0',
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

    return $self->_set_error('Page number can only be 1..14')
        if grep { $_ < 1 or $_ > 14 } @pages_list;

    my $ua = $self->ua;
    my @proxies;
    for ( @pages_list ) {
        my $response = $ua->get(
            'http://www.proxy4free.com/list/webproxy' . $_ . '.html'
        );

        if ( $response->is_success ) {
            my $parse = $self->_parse_proxy_list(
                $response->decoded_content
            ) or return; ## parse error; error is already set

            push @proxies, @$parse;
        }
        else {
            $self->debug
                and carp "Page $_: " . $response->status_line;
        }
    }

    return $self->list( \@proxies );
}

sub _parse_proxy_list {
    my ( $self, $content ) = @_;

    my $dom = Mojo::DOM->new( $content );
    my @proxies;
    eval {
        for my $tr ( $dom->find('.proxy-list tbody tr')->each ) {
            my %tds;
            @tds{qw/domain  features_hian  features_ssl/}
            = ( $tr->find('td')->each )[1, 9, 10];

            @tds{qw/
                rating  country  access_time
                uptime  online_since  last_test
            /} = map "$_", map $_->text, ( $tr->find('td')->each )[ 3..8 ];

            $tds{domain} = $tds{domain}->find('a')->text;
            $tds{ $_ } = $tds{ $_ } =~ /on/ ? 1 : 0
                for qw/features_hian  features_ssl/;

            $_ = "$_" for values %tds;

            push @proxies, +{ %tds };
        }
    };

    $@ and return $self->_set_error("Parser error: $@");

    return \@proxies;
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

=encoding utf8

=head1 NAME

WWW::Proxy4FreeCom - fetch proxy list from http://proxy4free.com/

=head1 SYNOPSIS

    use strict;
    use warnings;
    use WWW::Proxy4FreeCom;

    my $prox = WWW::Proxy4FreeCom->new;

    my $proxies = $prox->get_list
        or die $prox->error;

    printf "%-40s (last tested %s ago)\n", @$_{ qw(domain last_test) }
        for @$proxies;

=head1 DESCRIPTION

The module provides means to fetch proxy list
from L<http://proxy4free.com/> website.

=head1 CONSTRUCTOR

=head2 C<new>

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

=head3 C<timeout>

    ->new( timeout => 10 );

B<Optional>. Specifies the C<timeout> argument of L<LWP::UserAgent>'s
constructor, which is used for retrieving data.
B<Defaults to:> C<30> seconds.

=head3 C<ua>

    ->new( ua => LWP::UserAgent->new(agent => 'Foos!') );

B<Optional>. If the C<timeout> argument is not enough for your needs
of mutilating the L<LWP::UserAgent> object used for retrieving proxy list,
feel free
to specify the C<ua> argument which takes an L<LWP::UserAgent> object
as a value. B<Note:> the C<timeout> argument to the constructor will
not do anything if you specify the C<ua> argument as well. B<Defaults to:>
plain boring default L<LWP::UserAgent> object with C<timeout> argument
set to whatever C<WWW::Proxy4FreeCom>'s C<timeout> argument is
set to as well as C<agent> argument is set to mimic Firefox.

=head3 C<debug>

    ->new( debug => 1 );

When C<get_list()> is called any unsuccessfull page retrievals will be
silently ignored. Setting C<debug> argument to a true value will C<carp()>
any network errors if they occur.

=head1 METHODS

=head2 C<get_list>

    my $list_ref = $prox->get_list # just from the "proxy list 1"
        or die $prox->error;

    my $list_ref = $prox->get_list( 2 ) # just from the "proxy list 2"
        or die $prox->error;

    $prox->get_list( [3,5] ) # lists 3 and 5 only
        or die $prox->error;

Instructs the objects to fetch a fresh list of proxies from
L<http://proxy4free.com/>. B<On failure> returns C<undef> or an
empty list, depending on the context, and the human-readable error
will be available by calling the C<< ->error >> method.
B<On success> returns an arrayref of
hashrefs, each representing a proxy entry. Takes one optional argument which
can be either a number between 1 and 14 (inclusive) or an arrayref with
several of these numbers. The numbers represent the page number of
proxy list pages on L<http://proxy4free.com/>.
B<By default> only the list from the "proxy list 1" will be fetched.

Each hashref in the returned arrayref is in a following format
(if any field is missing on the site it will be reported as a string
C<N/A>):

    {
        'domain' => 'localfast.info',
        'rating' => '65',
        'country' => 'Germany',
        'access_time' => '1.3',
        'uptime' => '96',
        'online_since' => '16 hours',
        'last_test' => '30 minutes',
        'features_hian' => '1',
        'features_ssl' => '0',
    }

Where all the values correspond to the proxy list table columns on
the website. The C<features_hian> and C<features_ssl> keys will be
set to true values, if the proxy offers C<HiAn> or C<SSL> features
respectively.

=head2 C<error>

    my $list = $prox->get_list # just from the "proxy list 1"
        or die $prox->error;

If C<get_list()> method fails it will return
either C<undef> or an empty list, depending on the context, and the reason
for the error will be available via C<error()> method. Takes no arguments,
return a human-readable error message explaining the failure.

=head2 C<list>

    my $last_list_ref = $prox->list;

Must be called after a successfull call to C<get_list()>. Takes
no arguments, returns the same arrayref of hashrefs as
last call to C<get_list()> returned.

=head2 C<ua>

    my $old_LWP_UA_obj = $prox->ua;

    $prox->ua( LWP::UserAgent->new( timeout => 10, agent => 'foos' );

Returns a currently used L<LWP::UserAgent> object used for retrieving
data. Takes one optional argument which must be an L<LWP::UserAgent>
object, and the object you specify will be used in any subsequent calls
to C<get_list()>.

=head2 C<debug>

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
