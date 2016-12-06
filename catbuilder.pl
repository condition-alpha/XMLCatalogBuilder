#!/usr/bin/perl -w

###
# Copyright (c) 2016 by condition-alpha.com  /  All rights reserved.
###
#    Generating XML Catalog files for XML Schemas and Classification Schemes
#                      in a Three-Tier Directory Tree
#    -----------------------------------------------------------------------
#
# The namesapces are determined as follows:
#
# *.xsd: root element -> @targetNamespace
# *.xml: root element -> @uri
# *.dtd: placeholder entry (public/system ID must be fixed manually)
#
# The following directory structure is assumed:
#
#   dir/ ---+--- catalog.xml [1]
#           +--- dir/ ---+--- catalog.xml [2]
#           |            +--- dir/ ---+--- *.xsd
#           |            |            +--- *.xml
#           |            +--- dir/ ---+--- *.xsd
#           |            |            +--- *.xml
#           |            ...
#           +--- dir/ ---+--- catalog.xml [2]
#           |            +--- dir/ ---+--- *.xsd
#           |            |            +--- *.xml
#           |            +--- dir/ ---+--- *.xsd
#           |            |            +--- *.xml
#           |            ...
#
# The catalog file [1] will be generated, and will only contain <nextCatalog>
# references to the [2] catalog files.
#
# The [2] catalog files will also be generated, and will contain a <group> for
# each directory that is in the same directory as the [2] catalog itself,
# and their subdirectories (recursively). Within each <group>, it will contain
# <uri name="urn:..." uri="..."/> entries for all W3C XML Schemas (*.xsd) and
# XML Instance Documents (*.xml) in the group's subdirectory.
#
# The use-case for which this script was developed is to have a repository of
# many W3C XML Schemas and TV-Anytime and DVB Classification Schemes, and to
# index them with XML Catalog for use with an XML authoring tool. The rationale
# for the directory structure is that the directories at the level of the [1]
# catalog represent the originating organisation (e.g. W3C, MPEG-7, etc.), and
# the directories at the level of the [2] catalog represent the published
# versions (e.g. 2012, or 2.3.0). This enables you to simply drop an XML
# metadata package into one the version directories (if there is only one
# version simpley call it "Content") as it is, and the generated catalogs will
# reside _outside_ of the package (i.e. it will remain unaltered). 
#
# -----------------------------------------------------------------------------
# EXAMPLE:
#
# Consider the following example directory tree:
#
# metadata-library/
# metadata-library/W3C/
# metadata-library/W3C/2008/
# metadata-library/W3C/2008/foo.xsd
# metadata-library/W3C/2008/barCS.xml
# metadata-library/W3C/2015/
# metadata-library/W3C/2015/foo.xsd
# metadata-library/W3C/2015/barCS.xml
# metadata-library/MPEG-7/
# metadata-library/MPEG-7/Content/
# metadata-library/MPEG-7/Content/oogle.xsd
# metadata-library/MPEG-7/Content/froogle.xsd
# metadata-library/MPEG-7/Content/boogle.xml
# metadata-library/MPEG-7/Content/zork.xml
#
# Running this script on the above tree will generate:
#
# 1) metadata-library/catalog.xml with <nextCatalog> entries for W3C/catalog.xml
#    and MPEG-7/catalog.xml
#
# 2) metadata-library/W3C/catalog.xml with two <group> elements, one for the
#    2008 subdirectory, and one for the 2015 subdirectory. In each group, there
#    will be a <uri> element for foo.xsd, and for barCS.xml.
#
# 3) metadata-library/MPEG-7/catalog.xml with a single <group> element for the
#    Content subdirectory, an in that group four <uri> elements for the four
#    files in the Content subdirectory.
# -----------------------------------------------------------------------------
#
# XSD and XML files in the first-level subdirectory (i.e. W3C and MPEG-7 in the
# above example) are _NOT_SUPPORTED_ and will be ignored.
#
# Further subdirectories under the second-level subdirectory (i.e. 2008, 2015,
# and Content in the above example) are supported. They will be repesented as
# <group> elements in the [2] catalog files.
#
###

use strict;
use warnings;
use integer;
use Cwd;
use Term::ANSIColor;
use XML::LibXML;

sub isdir { -d $_[0] }
sub isxsd { $_[0] =~ m/\.xsd$/ }
sub isxml { $_[0] =~ m/\.xml$/ }
sub isdtd { $_[0] =~ m/\.dtd$/ }
sub isdot { $_[0] =~ m/^\./ }

sub trim($)
{
   my $string = shift;
   $string =~ s/^\s+//;
   $string =~ s/\s+$//;
   return $string;
}

sub processdir3
{
   my $dir = $_[0];
   my $cat = $_[1];

   my @subdirs;
   my $subdir;
   my @schemas;
   my @classifications;
   my @dtds;
   my $schema;
   my $classification;
   my $dtd;
   my $dom;
   my $ns;
   
   opendir(my $dh, $dir) or die $!;
   while (my $node = readdir($dh))
   {
      # skip dot files
      next if isdot($node);
      # collect subdirectories
      push(@subdirs, $node) if isdir("$dir/$node");
      # collect schemas and classification schemes
      push(@schemas, $node) if isxsd($node);
      push(@classifications, $node) if isxml($node);
      # collect DTDs
      push(@dtds, $node) if isdtd($node);
   }
   close($dh);

   print $cat "   <group xml:base=\"$dir/\">\n";
   
   if (@schemas)
   {
     print $cat "      <!-- W3C XML Schemas -->\n";
     foreach $schema (@schemas)
     {
       undef $ns;
      open my $fh, '<', "$dir/$schema";
       binmode $fh; # drop all PerlIO layers possibly created by a use open pragma
       $dom = XML::LibXML->load_xml(IO => $fh, recover => 2);
       my $docelem = $dom->getElementsByLocalName('schema')->item(0);
       if (defined($docelem))
       {
	 $ns = $docelem->getAttribute('targetNamespace');
	 if (defined($ns))
	 {
	   print $cat "      <uri name=\"" . trim($ns) . "\" uri=\"$schema\"/>\n";
	 }
	 else
	 {
	   print color('bold red');
	   print "\"$dir/$schema\" Warning: ";
	   print color ('reset red');
	   print "W3C XML Schema with no target namespace; no catalog entry generated\n";
	   print color('reset');
	}
       }
       else
       {
	 print color('bold red');
	 print "\"$dir/$schema\" Warning: ";
	 print color ('reset red');
	 print ".xsd file with no W3C XML <schema> element; no catalog entry generated\n";
	 print color('reset');
       }
     }
   }

   if (@classifications)
   {
     print $cat "      <!-- Classification Schemes -->\n";
     foreach $classification (@classifications)
     {
       undef $ns;
      open my $fh, '<', "$dir/$classification";
       binmode $fh; # drop all PerlIO layers possibly created by a use open pragma
       $dom = XML::LibXML->load_xml(IO => $fh, recover => 2);
       my $docelem = $dom->getElementsByTagNameNS('*', 'ClassificationScheme')->item(0);
       if (defined($docelem))
       {
	 $ns = $docelem->getAttribute('uri');
         if (defined($ns))
         {
            print $cat "      <uri name=\"" . trim($ns) . "\" uri=\"$classification\"/>\n";
         }
         else
         {
            print color('bold red');
            print "\"$dir/$classification\" Warning: ";
            print color ('reset red');
            print "Classification Scheme with no namespace; no catalog entry generated\n";
            print color('reset');
         }
       }
       else
       {
         $ns = $dom->documentElement()->getAttribute('targetNamespace');
         if (defined($ns))
	 {
	   print $cat "      <uri name=\"" . trim($ns) . "\" uri=\"$classification\"/>\n";
         }
         else
         {
	   print color('bold red');
	   print "\"$dir/$classification\" Warning: ";
	   print color ('reset red');
	   print "Classification Scheme with no namespace; no catalog entry generated\n";
	   print color('reset');
         }
       }
     }
   }

   if (@dtds)
   {
     print $cat "      <!-- DTDs -->\n";
     foreach $dtd (@dtds)
     {
       # insert a blank catalog entry
       print $cat "      <!-- FIXME: please fill in the public and/or system ID for this DTD, and remove any unneeded entry -->\n";
       print $cat "      <public publicId=\"\" uri=\"$dtd\"/>\n";
       print $cat "      <system systemId=\"\" uri=\"$dtd\"/>\n";
       
       # issue a warning to fill in the public and/or system ID
       print color('bold magenta');
       print "\"$dir/$dtd\" FIXME: ";
       print color ('reset magenta');
       print "DTD entry requires manually setting a public and/or system ID in \n";
       print color('reset');
     }
   }
     
   print $cat "   </group>\n";
   print "      [group \"$dir\" with " . ($#schemas + $#classifications + $#dtds + 3) . " entries]\n";
     
   # recurse into subdirectories
   foreach $subdir (@subdirs)
   {
      my $pwd = cwd();
      chdir($subdir);
      processdir3("$dir/$subdir", $cat);
      chdir($pwd);
   }
}

sub processdir2
{
  my $dir = $_[0];
  
  my @subdirs;
  my $subdir;
   
  opendir(my $dh, $dir) or die $!;
  while (my $node = readdir($dh))
  {
    # skip dot files
    next if isdot($node);
    # collect subdirectories
    push(@subdirs, $node) if isdir("$dir/$node");
  }
  close($dh);
   
  # preamble
  print color('bold blue');
  print "   $dir/catalog.xml\n";
  print color('reset');
   open(my $cat, ">:encoding(UTF-8)", "$dir/catalog.xml") or die "cannot open > $dir/catalog.xml: $!";
  print $cat "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  print $cat "<!DOCTYPE catalog PUBLIC \"-//OASIS//DTD XML Catalogs V1.1//EN\" \"http://www.oasis-open.org/committees/entity/release/1.1/catalog.dtd\">\n";
  print $cat "<catalog xmlns=\"urn:oasis:names:tc:entity:xmlns:xml:catalog\">\n";
  
  # generate groups for files in subdirectories
  foreach $subdir (@subdirs)
  {
    my $pwd = cwd();
    chdir($dir);
    processdir3($subdir, $cat);
    chdir($pwd);
  }

  #postamble
  print $cat "</catalog>\n";
  close($cat);
}

sub processdir1
{
  my $dir = $_[0];
  
  my @subdirs;
  my $subdir;
  
  opendir(my $dh, $dir) or die $!;
  while (my $node = readdir($dh))
  {
    # skip dot files
    next if isdot($node);
    # collect subdirectories
    push(@subdirs, $node) if isdir("$dir/$node");
  }
  closedir($dh);
  #
  # generate pointers to catalog in next level subdirs
  #
  print color('bold blue');
  print "   $dir/catalog.xml\n";
  print color('reset');
  open(my $cat, ">:encoding(UTF-8)", "$dir/catalog.xml") or die "cannot open > $dir/catalog.xml: $!";
  print $cat "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  print $cat "<!DOCTYPE catalog PUBLIC \"-//OASIS//DTD XML Catalogs V1.1//EN\" \"http://www.oasis-open.org/committees/entity/release/1.1/catalog.dtd\">\n";
  print $cat "<catalog xmlns=\"urn:oasis:names:tc:entity:xmlns:xml:catalog\">\n";
  foreach $subdir (@subdirs)
  {
    print $cat "   <nextCatalog catalog=\"$subdir/catalog.xml\"/>\n";
  }
  print $cat "</catalog>\n";
  close($cat);
  
  # recurse into subdirectories
  foreach $subdir (@subdirs)
  {
    my $pwd = cwd();
    chdir($dir);
    processdir2($subdir);
    chdir($pwd);
  }
}


###
# void main() {
###
print "Generating XML Catalog files:\n";
if (@ARGV)
{
  foreach my $argnum (0 .. $#ARGV)
  {
    processdir1($ARGV[$argnum]);
  }
}
else
{
   processdir1('.');
}
exit 0;

###
# }  /* end of main() */
###

########################################################################
