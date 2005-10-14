# This Makefile.PL contains portions borrowed 
# from XML::Parser and XML::SAX

use ExtUtils::MakeMaker;
use Config;

$expat_libpath = '';
$expat_incpath = '';

my @replacement_args;

foreach (@ARGV) {
  if (/^EXPAT(LIB|INC)PATH=(.+)/) {
    if ($1 eq 'LIB') {
      $expat_libpath = $2;
    }
    else {
      $expat_incpath = $2;
    }
  }
  else {
    push(@replacement_args, $_);
  }
}

@ARGV = @replacement_args;

if (not $expat_libpath and $] >= 5.006001) {
  require ExtUtils::Liblist;		# Buggy before this
  ($expat_libpath) = ExtUtils::Liblist->ext('-lexpat');
}

unless ($expat_libpath) {
  # Test for existence of libexpat
  my $found = 0;
  foreach (split(/\s+/, $Config{libpth})) {
    if (-f "$_/libexpat." . $Config{so}) {
      $found = 1;
      last;
    }
  }

  unless ($found) {
      die <<'Expat_Not_Installed;';

Expat must be installed prior to building XML::SAX::ExpatXS and I can't 
find it in the standard library directories. You can download expat from:

http://sourceforge.net/projects/expat/

If expat is installed, but in a non-standard directory, then use the
following options to Makefile.PL:

    EXPATLIBPATH=...  To set the directory in which to find libexpat

    EXPATINCPATH=...  To set the directory in which to find expat.h

For example:

    perl Makefile.PL EXPATLIBPATH=/home/me/lib EXPATINCPATH=/home/me/include

Note that if you build against a shareable library in a non-standard location
you may (on some platforms) also have to set your LD_LIBRARY_PATH environment
variable at run time for perl to find the library.

Expat_Not_Installed;
  }
}

my $libs = "-lexpat";
$libs = "-L$expat_libpath $libs"
  if $expat_libpath;

@extras = ();

push(@extras, INC => "-I$expat_incpath")
  if $expat_incpath;

push(@extras,
     CAPI => 'TRUE')
    if ($PERL_VERSION >= 5.005 and $OSNAME eq 'MSWin32'
	and $Config{archname} =~ /-object\b/i);

push(@extras,
     ABSTRACT_FROM => 'lib/XML/SAX/ExpatXS.pm',
     AUTHOR => 'Matt Sergeant <matt AT sergeant DOT org>')
    if ($ExtUtils::MakeMaker::Version >= 5.4301);


WriteMakefile(
    NAME => 'XML::SAX::ExpatXS',
    VERSION_FROM => 'lib/XML/SAX/ExpatXS.pm',
    PREREQ_PM => {
		    'XML::SAX' => 0.12,
		   },
    LIBS => $libs,
    @extras
);

sub MY::install {
    package MY;
    my $script = shift->SUPER::install(@_);
    if (ExtUtils::MakeMaker::prompt("Do you want to alter ParserDetails.ini?", "Y") =~ /^y/i) {
        $script =~ s/install :: (.*)$/install :: $1 install_expat_xs/m;
        $script .= <<"INSTALL";

install_expat_xs :
\t\@\$(PERL) -MXML::SAX -e "XML::SAX->add_parser(q(XML::SAX::ExpatXS))->save_parsers()"

INSTALL

    }

    return $script;
}
