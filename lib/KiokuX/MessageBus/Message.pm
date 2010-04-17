package KiokuX::MessageBus::Message;
use Moose;

use namespace::autoclean;

our $VERSION = "0.01";

has contents => (
    isa => "ArrayRef",
    required => 1,
    reader => "_contents",
);

sub contents {
    my $self = shift;
    
    my $objs = $self->_contents;

    return ( @$objs == 1 ? $objs->[0] : @$objs );    
}

__PACKAGE__->meta->make_immutable;

# ex: set sw=4 et:

__PACKAGE__

__END__
