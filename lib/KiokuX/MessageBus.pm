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

    if ( @other_entries == 1 ) {
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
