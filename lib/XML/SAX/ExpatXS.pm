# $Id: ExpatXS.pm,v 1.29 2005/03/07 10:32:23 cvspetr Exp $

package XML::SAX::ExpatXS;
use strict;
use vars qw($VERSION @ISA);

use XML::SAX::ExpatXS::Encoding;
use XML::SAX::Base;
use DynaLoader ();
use Carp;
use IO::File;

$VERSION = '1.06';
@ISA = qw(DynaLoader XML::SAX::Base);

XML::SAX::ExpatXS->bootstrap($VERSION);

my @supported_features = (
	'http://xml.org/sax/features/namespaces',
	'http://xml.org/sax/features/external-general-entities',
	'http://xmlns.perl.org/sax/join-character-data',
	'http://xmlns.perl.org/sax/ns-attributes',
	'http://xmlns.perl.org/sax/locator',
			 );

#------------------------------------------------------------
# API methods
#------------------------------------------------------------

sub new {
    my $proto = shift;
    my $options = ($#_ == 0) ? shift : { @_ };

    $options->{Features}->{$supported_features[0]} = 1;
    $options->{Features}->{$supported_features[1]} = 1;
    $options->{Features}->{$supported_features[2]} = 1;
    $options->{Features}->{$supported_features[3]} = 1;
    $options->{Features}->{$supported_features[4]} = 1;

    return $proto->SUPER::new($options);
}

sub get_feature {
    my ($self, $feat) = @_;
      if (exists $self->{Features}->{$feat}) {
	  return $self->{Features}->{$feat};
      }
      else {
          return $self->SUPER::get_feature($feat);
      }
  }

sub set_feature {
    my ($self, $feat, $val) = @_;
      if (exists $self->{Features}->{$feat}) {
	  return $self->{Features}->{$feat} = $val;
      }
      else {
          return $self->SUPER::set_feature($feat, $val);
      }
  }

sub get_features {
    my $self = shift;
    return %{$self->{Features}};
}

sub supported_features {
    my $self = shift;

    return @supported_features;
}

#------------------------------------------------------------
# internal methods
#------------------------------------------------------------

sub _parse_characterstream {
    my ($self, $fh) = @_;
    $self->{ParseOptions}->{ParseFunc} = \&ParseStream;
    $self->{ParseOptions}->{ParseFuncParam} = $fh;
    $self->_parse;
}

sub _parse_bytestream {
    my ($self, $fh) = @_;
    $self->{ParseOptions}->{ParseFunc} = \&ParseStream;
    $self->{ParseOptions}->{ParseFuncParam} = $fh;
    $self->_parse;
}

sub _parse_string {
    my $self = shift;
    $self->{ParseOptions}->{ParseFunc} = \&ParseString;
    $self->{ParseOptions}->{ParseFuncParam} = $_[0];
    $self->_parse;
}

sub _parse_systemid {
    my $self = shift;
    my $fh = IO::File->new(shift);
    $self->{ParseOptions}->{ParseFunc} = \&ParseStream;
    $self->{ParseOptions}->{ParseFuncParam} = $fh;
    $self->_parse;
}

sub _parse {
    my $self = shift;

    my $args = bless $self->{ParseOptions}, ref($self);

    # copy handlers over
    $args->{Handler} = $self->{Handler};
    $args->{DocumentHandler} = $self->{DocumentHandler};
    $args->{ContentHandler} = $self->{ContentHandler};
    $args->{DTDHandler} = $self->{DTDHandler};
    $args->{LexicalHandler} = $self->{LexicalHandler};
    $args->{DeclHandler} = $self->{DeclHandler};
    $args->{ErrorHandler} = $self->{ErrorHandler};
    $args->{EntityResolver} = $self->{EntityResolver};
    $args->{Features} = $self->{Features};

    $args->{_State_} = 0;
    $args->{Context} = [];
    $args->{ErrorMessage} ||= '';
    $args->{Namespace_Stack} = [[ xml => 'http://www.w3.org/XML/1998/namespace' ]];
    $args->{Parser} = ParserCreate($args, $args->{ProtocolEncoding}, 1);
    $args->{Locator} = GetLocator($args->{Parser}, 
				  $args->{Source}->{PublicId},
				  $args->{Source}->{SystemId},
				  $args->{Source}->{Encoding}
				 );
    $args->{RecognizedString} = GetRecognizedString($args->{Parser});
    $args->{ExternEnt} = GetExternEnt($args->{Parser});

    # the most common handlers are available as refs
    SetCallbacks($args->{Parser}, 
 		 \&XML::SAX::Base::start_element,
 		 \&XML::SAX::Base::end_element,
 		 \&XML::SAX::Base::characters,
  		);

    $args->set_document_locator($args->{Locator});
    $args->start_document({});
   
    my $result;
    $result = $args->{ParseFunc}->($args->{Parser}, $args->{ParseFuncParam});

    ParserFree($args->{Parser});

    my $rv = $args->end_document({});   # end_document is still called on error

    croak($args->{ErrorMessage}) unless $result;
    return $rv;
}

sub _get_external_entity {
    my ($self, $base, $sysid, $pubid) = @_;

    # resolving with the base URI
    if ($base and $sysid and $sysid !~ /^[a-zA-Z]+[a-zA-Z\d\+\-\.]*:/) {
	$base =~ s/[^\/]+$//;
	$sysid = $base . $sysid;
    }

    # user defined resolution
    my $src = $self->resolve_entity({PublicId => $pubid, 
				     SystemId => $sysid});
    my $fh;
    if (ref($src) eq 'CODE') {
	$fh = IO::File->new($sysid)
	  or croak("Can't open external entity: $sysid\n");

    } elsif (ref($src) eq 'HASH') {
	if (defined $src->{CharacterStream}) {
	    $fh = $src->{CharacterStream};
	} elsif (defined $src->{ByteStream}) {
	    $fh = $src->{ByteStream};
	} else {
	    $fh = IO::File->new($src->{SystemId})
	      or croak("Can't open external entity: $src->{SystemId}\n");
	}

    } else {
	croak ("Invalid object returned by EntityResolver: $src\n");
    }

    undef $/;
    my $result = <$fh>;
    close($fh);
    return $result;
}

1;
__END__

=head1 NAME

XML::SAX::ExpatXS - Perl SAX 2 XS extension to Expat parser

=head1 SYNOPSIS

 use XML::SAX::ExpatXS;

 $handler = MyHandler->new();
 $parser = XML::SAX::ExpatXS->new( Handler => $handler );
 $parser->parse($uri);
  #or
 $parser->parse_string($xml);

=head1 DESCRIPTION

XML::SAX::ExpatXS is a direct XS extension to Expat XML parser. It implements
Perl SAX 2.1 interface. See http://perl-xml.sourceforge.net/perl-sax/ for
Perl SAX description.

=head2 Features

The parser behavior can be changed by setting features.

 $parser->set_feature(FEATURE, VALUE);

XML::SAX::ExpatXS provide these features:

=over

=item http://xmlns.perl.org/sax/join-character-data

Consequent character data are joined (1, default) or not (0).

=item http://xmlns.perl.org/sax/ns-attributes

Namespace attributes are reported as common attributes (1, default) or not (0).

=item http://xmlns.perl.org/sax/locator

Document locator is updated (1, default) for ContentHadler events or not (0).

=back

=head1 AUTHORS

Matt Sergeant <matt AT sergeant DOT org>
Petr Cimprich <petr AT gingerall DOT org> (maintainer)

=cut
