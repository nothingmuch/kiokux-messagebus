#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use ok 'KiokuX::MessageBus';

{
    package Foo;

    use Moose;

    has name => ( isa => "Str", is => "ro" );
}

my ( $one, $two ) = map { KiokuX::MessageBus->new } 1 .. 2;

my $scalar_msg = do {
    my $s = $one->new_scope;
    $one->encode(Foo->new(name => "blah"));
};

{
    my $s = $two->new_scope;
    my $obj = $two->decode($scalar_msg);

    isa_ok( $obj, 'Foo' );

    is( $obj->name, 'blah', "message data" );
}

my $nary_msg = do {
    my $s = $one->new_scope;
    $one->encode(Foo->new(name => "first"), Foo->new( name => "second" ), { yes => "no" });
};

{
    my $s = $two->new_scope;
    my @objs = $two->decode($nary_msg);

    is( scalar(@objs), 3, "3 objects received" );

    isa_ok( $objs[0], 'Foo' );

    is( $objs[0]->name, 'first', "message data" );
}

done_testing;

# ex: set sw=4 et:

