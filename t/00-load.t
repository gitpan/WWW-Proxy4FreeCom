#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 17;

BEGIN {
    use_ok('Carp');
    use_ok('URI');
    use_ok('LWP::UserAgent');
    use_ok('HTML::TokeParser::Simple');
    use_ok('Class::Data::Accessor');
	use_ok( 'WWW::Proxy4FreeCom' );
}

diag( "Testing WWW::Proxy4FreeCom $WWW::Proxy4FreeCom::VERSION, Perl $], $^X" );

my $o = WWW::Proxy4FreeCom->new( timeout => 10, debug=> 1 );
isa_ok($o,'WWW::Proxy4FreeCom');
can_ok($o,qw(new get_list filter
                list
                filtered_list
                error
                ua
                debug
                _parse_proxy_list
                _set_error
));
isa_ok($o->ua, 'LWP::UserAgent');
SKIP: {
    my $list_ref = $o->get_list
        or diag "Got error: " . $o->error and skip 'Some error', 7;

    diag "\nGot " . @$list_ref . " proxies in a list\n\n";

    is( ref $list_ref, 'ARRAY', 'get_list() must return an arrayref' );

    my ($flail,$flail_keys) = (0,0);
    my %test;
    @test{ qw(ip  port  type  country  last_test) } = (0) x 5;
    
    my %test_res = (
        # ZOMFG!! THIS IS NOT AN IP RE!!!
        ip        => qr#^((\d{1,3}\.){3}\d{1,3}|N/A)$#,
        port      => qr#^(\d+|N/A)$#,
        type      => qr#^(high anonymity|transparent|anonymous|N/A)$#,
        country   => qr#^[\w./\s()]+$#,
        last_test => qr#^(\d{4}(-\d{2}){2}|N/A)$#,
    );
    
    for my $prox ( @$list_ref ) {
        ref $prox eq 'HASH' or $flail++;
        for ( keys %test ) {
            exists $prox->{$_} or $flail_keys++;
            $prox->{$_} =~ /$test_res{$_}/
                or ++$test{$_}
                and diag "Failed $_ regex test (value is: `$prox->{$_}`)";
        }
    }
    is( $flail, 0,
        "All elements of get_list() must be hashrefs ($flail of them aren't)"
    );
    is( $flail_keys, 0,
        qq|All "proxy" hashrefs must have all keys ($flail_keys are missing)|
    );

    for ( keys %test ) {
        is ( $test{$_}, 0, "test for $_ failed $test{$_} times" );
    }
}

