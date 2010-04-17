#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use KiokuDB::Backend::Hash;
use KiokuDB;

use ok 'KiokuX::MessageBus';

{
    package Foo;

    use Moose;

    has name => ( isa => "Str", is => "ro" );

    has friend => ( is => "ro" );
}

my $backend = KiokuDB::Backend::Hash->new;

my ( @dirs ) = map { KiokuDB->new( backend => $backend ) } 1 .. 2;

my ( $one, $two ) = map { KiokuX::MessageBus->new( directory => $_ ) } @dirs;

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
    $one->encode(
        Foo->new(name => "first"),
        Foo->new( name => "second" ),
        { yes => "no" },
    );
};

{
    my $s = $two->new_scope;
    my @objs = $two->decode($nary_msg);

    is( scalar(@objs), 3, "3 objects received" );

    isa_ok( $objs[0], 'Foo' );

    is( $objs[0]->name, 'first', "message data" );
}

my $perm_id = $one->directory->txn_do( scope => 1, body => sub {
    my $object = Foo->new( name => "permanent", friend => Foo->new( name => "the friend" ) );

    $one->directory->insert($object);
});

my $referencing_db = do {
    my $s = $one->new_scope;

    my $obj = $one->directory->lookup($perm_id);

    isa_ok( $obj, "Foo" );

    $one->encode(
        $obj,
        Foo->new(name => "transient"),
    );
};

{
    my $s = $two->new_scope;
    my @objs = $two->decode($referencing_db);

    is( scalar(@objs), 2, "2 objects received" );

    isa_ok( $_, "Foo" ) for @objs;

    my ( $perm, $trans ) = @objs;

    is( $trans->name, "transient", "anon object" );
    is( $perm->name, "permanent", "db object" );

    isa_ok( $perm->friend, "Foo" );
    is( $perm->friend->name, "the friend", "indirectly referenced db object" );
}

my $scalar_referencing_db = do {
    my $s = $one->new_scope;

    my $obj = $one->directory->lookup($perm_id);

    isa_ok( $obj, "Foo" );

    $one->encode($obj);
};

{
    my $s = $two->new_scope;
    my $perm = $two->decode($scalar_referencing_db);

    isa_ok( $perm, "Foo" );
    is( $perm->name, "permanent", "db object" );

    isa_ok( $perm->friend, "Foo" );
    is( $perm->friend->name, "the friend", "indirectly referenced db object" );
}


done_testing;

# ex: set sw=4 et:

