#!/usr/bin/env perl

use strict;
use warnings;

use lib '../lib';

use WWW::Proxy4FreeCom;

my $prox = WWW::Proxy4FreeCom->new;

$prox->get_list
    or die $prox->error;

my $filtered_ref = $prox->filter( type => 'transparent' )
    or die $prox->error;

printf "http://%s:%d (last tested on %s)\n", @$_{ qw(ip port last_test) }
    for @$filtered_ref;