package KiokuX::MessageBus;
use Moose;

use KiokuDB;
use KiokuX::MessageBus::Message;

use namespace::autoclean;

our $VERSION = "0.01";

with qw(KiokuDB::Backend::Serialize::Delegate);

has directory => (
    isa => "KiokuDB",
    handles => "KiokuDB::Role::API",
    lazy_build => 1,
);

sub _build_directory {
    KiokuDB->connect("hash");
}

has collapser => (
    isa => "KiokuDB::Collapser",
    is  => "ro",
    lazy_build => 1,
);

sub _build_collapser { shift->directory->collapser }

has linker => (
    isa => "KiokuDB::Linker",
    is  => "ro",
    lazy_build => 1,
);

sub _build_linker { shift->directory->linker }



sub decode {
    my ( $self, @args ) = @_;

    $self->message_entry_to_objects( $self->deserialize(@args) );
}

sub encode {
    my ( $self, @args ) = @_;

    $self->serialize( $self->objects_to_message_entry(@args) );
}

sub message_entry_to_objects {
    my ( $self, $message ) = @_;

    my ( $message_object ) = $self->linker->register_and_expand_entries($message, @{ $message->backend_data || [] });

    if ( blessed($message_object) and $message_object->isa('KiokuX::MessageBus::Message') ) {
        return $message_object->contents;
    } else {
        return $message_object;
    }
}

sub objects_to_message_entry {
    my ( $self, @objects ) = @_;

    my $message = KiokuX::MessageBus::Message->new( contents => \@objects );

    my ( $buffer, $id ) = $self->collapser->collapse( root_set => 0, only_new => 1, objects => [ $message ] );

    my ( $message_entry, @other_entries ) = sort { $a->id eq $id ? -1 : 1 } $buffer->entries;

    if ( @other_entries == 1 and @objects == 1 ) {
        return $other_entries[0];
    } else {
        $message_entry->backend_data([ $buffer->entries ]);
        return $message_entry;
    }
}


__PACKAGE__->meta->make_immutable;

# ex: set sw=4 et:

__PACKAGE__

__END__

=head1 NAME

KiokuX::MessageBus - Use L<KiokuDB> as a message broker

=head1 SYNOPSIS

    my $bus = KiokuX::MessageBus->new( directory => $kiokudb );

    my $str = $bus->encode($some_object);

    $message_queue->send($str);

=head1 DESCRIPTION

B<NOTE>: since L<KiokuDB> does not yet support event driven operations, this
module is likely to change when that happens in order to better integrate into
event driven applications.

This class implements a filter that converts a list of objects into a string
using L<KiokuDB>'s collapsing code.

It can take an optional L<KiokuDB> directory, in which case database objects
can be referred to as well.

=head1 METHODS

=over 4

=item encode @objects

Returns a string that can be sent.

=item decode $string

Returns the list of objects passed to the C<encode> which created the message
string.

=back

=head1 SCOPES TRANSACTIONS

If using a shared database for referenced objects, messages should be queued
until transactions have been comitted before they are sent out, otherwise the
receiver might not see the effects.

All sent and received objects are registered with the live object set, so be
sure to create live object scopes, but also very importantly, be sure to
dispose of them. If you're receiving messages in a long running loop, create
one scope per C<decode> call.
