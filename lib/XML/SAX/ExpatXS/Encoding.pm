# $Id: Encoding.pm,v 1.1 2004/04/07 13:08:11 cvspetr Exp $

package XML::SAX::ExpatXS::Encoding;
require 5.004;

use strict;
use vars qw(@ISA %Encoding_Table @Encoding_Path $have_File_Spec);
use XML::SAX::ExpatXS;
use Carp;

require DynaLoader;

@ISA = qw(DynaLoader);


$have_File_Spec = $INC{'File/Spec.pm'} || do 'File/Spec.pm';

%Encoding_Table = ();
if ($have_File_Spec) {
  @Encoding_Path = (grep(-d $_,
                         map(File::Spec->catdir($_, qw(XML SAX ExpatXS Encodings)),
                             @INC)),
                    File::Spec->curdir);
}
else {
  @Encoding_Path = (grep(-d $_, map($_ . '/XML/SAX/ExpatXS/Encodings', @INC)), '.');
}
  
sub load_encoding {
  my ($file) = @_;

  $file =~ s!([^/]+)$!\L$1\E!;
  $file .= '.enc' unless $file =~ /\.enc$/;
  unless ($file =~ m!^/!) {
    foreach (@Encoding_Path) {
      my $tmp = ($have_File_Spec
                 ? File::Spec->catfile($_, $file)
                 : "$_/$file");
      if (-e $tmp) {
        $file = $tmp;
        last;
      }
    }
  }

  local(*ENC);
  open(ENC, $file) or croak("Couldn't open encmap $file:\n$!\n");
  binmode(ENC);
  my $data;
  my $br = sysread(ENC, $data, -s $file);
  croak("Trouble reading $file:\n$!\n")
    unless defined($br);
  close(ENC);

  my $name = XML::SAX::ExpatXS::LoadEncoding($data, $br);
  croak("$file isn't an encmap file")
    unless defined($name);

  $name;
}  # End load_encoding


################################################################

package XML::SAX::ExpatXS::Encinfo;

sub DESTROY {
  my $self = shift;
  XML::SAX::ExpatXS::FreeEncoding($self);
}

1;

__END__

=head1 NAME

XML::SAX::ExpatXS::Encoding - Encoding support for XML::SAX::ExpatXS

=head1 DESCRIPTION

This module is derived from XML::Parser::Expat. It provides XML::SAX::ExpatXS
parser with support of not-built-in encodings. 

=head1 AUTHORS

Larry Wall <F<larry@wall.org>>

and

Clark Cooper <F<coopercc@netheaven.com>> authored XML::Parser::Expat.

Petr Cimprich <F<petr@gingerall.cz>> addapted it for XML::SAX::ExpatXS.

=cut
