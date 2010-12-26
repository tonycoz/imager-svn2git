#!perl -w
use strict;
use SVN::Dump;
use feature 'switch';

my $dump = SVN::Dump->new({ file => "-" });

my $iscvstag = 0;
while (my $rec = $dump->next_record) {
  my $type = $rec->type;
  print STDERR "Record: ", $rec->type, "\n";
  my $action = "KEEP";
  given ($type) {
    when ("revision") {
      print STDERR "Revision ", $rec->get_header('Revision-number'), "\n";
      $iscvstag = $rec->get_property("svn:log") =~ /^This commit was manufactured by cvs2svn to create tag/;
    }
    when ("node") {
      my $path = $rec->get_header('Node-path');
      my $outpath = $path;
      $action = "SKIP";
      if ($path =~ /^(trunk|branches|tags)$/
	 || $path =~ m(^trunk/Imager(/|$))
	 || $path =~ m(^tags/Imager-0)
	 || $path =~ m(^branches/)) {
	$action = "KEEP";
	if ($path =~ /CVSROOT/
	    || $path =~ m(^branches/POE-)
	    # the following have an Imager directory under the tag
	    #|| $path =~ m(^tags/Imager-0_\w+$)
	   ) {
	  $action = "SKIP";
	}
	if ($action eq "KEEP"
	    && $outpath =~ s(^(tags/Imager-0_\w+/)Imager/)($1)) {
	  $rec->set_header('Node-path', $outpath);
	  if ($rec->get_header('Node-copyfrom-path') eq "trunk") {
	    $rec->set_header('Node-copyfrom-path', "trunk/Imager");
	  }
	}
      }
      if ($iscvstag &&
	  $rec->get_header("Node-kind") eq "file") {
	$action = "SKIP";
      }
      if ($iscvstag) {
	if ($rec->get_header("Node-kind") eq "dir"
	  && $rec->get_header("Node-copyfrom-path") eq "branches/devel") {
	  $rec->set_header("Node-copyfrom-path", "trunk/Imager");
	}
	else {
	  $action = "SKIP";
	}
      }

      if ($outpath =~ s(^branches/Imager/)(branches/)) {
	$rec->set_header('Node-path', $outpath);
      }
#       elsif ($outpath =~ s((^branches/\w+/)Imager/)($1)) {
# 	$rec->set_header('Node-path', $outpath);
#       }
      fix_paths($rec);
      my $inc = $rec->get_included_record;
      if ($inc) {
	print STDERR "Subrecord:\n";
	fix_paths($inc);
	$rec->set_included_record($inc);
	print STDERR "EndSubrecord\n";
      }
      $rec->update_headers;

      print STDERR "  ", $rec->get_header("Node-action"), ": $path - $action\n";
      print STDERR "    rename: $outpath\n" if $outpath ne $path;
    }
    default {
      print STDERR "$type\n";
    }
  }
  if ($action eq "KEEP") {
    my $text = $rec->as_string;
    $text =~ s/^Content-length: 0\n//m;
    $text =~ s/^Prop-content-length: 0\n//m;
    print $text;
  }
  print STDERR "EndRecord\n";
}


sub fix_paths {
  my ($rec) = @_;

#   my $outpath = $rec->get_header("Node-Path");
#   if ($outpath) {
#     if ($outpath =~ s(^(branches/\w+/)Imager/)($1)) {
#       $rec->set_header("Node-path", $outpath);
#       print STDERR "Rename: $outpath\n";
#     }
#   }

  my $copypath = $rec->get_header('Node-copyfrom-path');
  if ($copypath) {
    print STDERR "Copyfrom: $copypath\n";

#     if ($copypath =~ s(^branches/devel/Imager/)(trunk/Imager/)
# 	|| $copypath =~ s(^branches/Imager/)(branches/)) {
#       $rec->set_header('Node-copyfrom-path', $copypath);
#       print STDERR "Newcopyfrom: $copypath\n";
#     }
#    if ($copypath =~ s((^branches/\w+/)Imager/)($1)) {
    if ($copypath =~ s(^branches/Imager/)(branches/)) {
      $rec->set_header('Node-copyfrom-path', $copypath);
      print STDERR "Newcopyfrom: $copypath\n";
    }
  }
}
