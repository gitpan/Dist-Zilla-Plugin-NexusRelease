use strict;
use warnings;

package Dist::Zilla::Plugin::NexusRelease;
$Dist::Zilla::Plugin::NexusRelease::VERSION = '0.0.1';

# ABSTRACT: Release a Dist::Zilla build to a Sonatype Nexus instance.

use utf8;
use Moose;
with 'Dist::Zilla::Role::Releaser';

use Log::Any qw($log);
use Scalar::Util qw(weaken);
use Carp;

use namespace::autoclean;

{

    package Dist::Zilla::Plugin::NexusRelease::_Uploader;
$Dist::Zilla::Plugin::NexusRelease::_Uploader::VERSION = '0.0.1';
    # Nexus::Uploader will be loaded later if used
    our @ISA = 'Nexus::Uploader';

    sub log {
        my $self = shift;
        $self->{'Dist::Zilla'}{plugin}->log(@_);
    }
}


has username => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    lazy     => 1,
    default  => sub {
        my $self = shift;
        return $self->zilla->chrome->prompt_str('Nexus username: ');
    }
);


has password => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    lazy     => 1,
    default  => sub {
        my $self = shift;
        return $self->zilla->chrome->prompt_str( 'Nexus password: ',
            { noecho => 1 } );
    }
);


has nexus_URL => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    default  => 'http://localhost:8081/nexus/',
);


has repository =>
    ( is => 'ro', isa => 'Str', required => 1, default => 'releases', );


has group => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->zilla->chrome->prompt_str('Nexus group: ');
    },
);


has artefact =>
    ( is => 'ro', isa => 'Str', lazy => 1, builder => '_build_artefact' );
sub _build_artefact { my $self = shift; $self->zilla->name; }


has version =>
    ( is => 'ro', isa => 'Str', lazy => 1, builder => '_build_version' );
sub _build_version { my $self = shift; $self->zilla->version; }


has uploader => (
    is      => 'ro',
    isa     => 'Nexus::Uploader',
    lazy    => 1,
    default => sub {
        my ($self) = @_;

        # Load the module lazily
        require Nexus::Uploader;

        my $uploader = Dist::Zilla::Plugin::NexusRelease::_Uploader->new(
            {   username   => $self->username,
                password   => $self->password,
                nexus_URL  => $self->nexus_URL,
                repository => $self->repository,
                group      => $self->group,
                artefact   => $self->artefact,
                version    => $self->version,
            }
        );

        $uploader->{'Dist::Zilla'}{plugin} = $self;
        weaken $uploader->{'Dist::Zilla'}{plugin};

        return $uploader;
    }
);

sub release {
    my $self    = shift;
    my $archive = shift;

    my @missing_attributes = ();
    for my $attr (qw(username password group)) {
        if ( !length $self->$attr ) {
            $self->log("You need to supply a $attr");
            push( @missing_attributes, $attr );
        }
    }
    if ( scalar @missing_attributes ) {
        croak "Missing attributes " . join( ', ', @missing_attributes );
    }

    $log->info('Releasing to Sonatype Nexus');
    $self->uploader->upload_file($archive);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::NexusRelease - Release a Dist::Zilla build to a Sonatype Nexus instance.

=head1 VERSION

version 0.0.1

=head1 SYNOPSIS

If loaded, this plugin will allow the C<release> command to upload a distribution to a Sonatype Nexus instance.

=head1 DESCRIPTION

This plugin looks for configuration in your F<dist.ini> or (more
likely) F<~/.dzil/config.ini>:

  [NexusRelease]
      username   = Nexus tokenised username
      password   = Nexus tokenised password
      group      = Nexus group ID to use for the upload

The following are optional but very likely to be used:

      nexus_URL  = Base Nexus URL
      repository = Nexus repo ID

The Nexus Artefact is set to the Perl distribution name (C<name> in F<dist.ini>, and the version is set to the Perl distribution version.

=head1 ATTRIBUTES

=head2 username

This is the Nexus user to log in with.

User will be prompted if this is not set in F<dist.ini>.

=head2 password

The Nexus password. It is *strongly* advised that you take advantage of the Nexus user tokens feature!

User will be prompted if this is not set in F<dist.ini>.

=head2 nexus_URL

The Nexus URL (base URL) to use. Defaults to L<http://localhost:8081/nexus>.

=head2 repository

Name of the repository to use for uploads. Defaults to C<releases>.

=head2 group

The group to use when uploading. There is no default although a reasonable value would be your CPAN ID.

User will be prompted if this is not set in F<dist.ini>.

=head2 artefact

The artefact name to use when uploading - defaults to the distribution name.

=head2 version

The version of the distribution - defaults to the $VERSION set in the distribution.

=head1 METHODS

=head2 release

The C<release> method required by L<Dist::Zilla::Role::Releaser>.


=head1 SEE ALSO

- L<Nexus::Uploader>
- L<Dist::Zilla::Plusin::UploadToCPAN>

=head1 AUTHOR

Brad Macpherson <brad@teched-creations.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Brad Macpherson.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
