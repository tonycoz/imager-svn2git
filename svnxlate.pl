#!perl -w
use strict;
use SVN::Dump;
use feature 'switch';

my $dump = SVN::Dump->new({ file => "-" });

my $iscvstag = 0;
my $iscvsbranch = 0;
my $revnum = 0;
my $pending;
my @pending;
my $pending_rev;
while (my $rec = $dump->next_record) {
  my $type = $rec->type;
  print STDERR "Record: ", $rec->type, "\n";
  my $action = "KEEP";
  given ($type) {
    when ("revision") {
      if ($pending) {
	end_pending(\@pending, $pending_rev);
	$pending = 0;
      }
      my $revnum = $rec->get_header('Revision-number');
      print STDERR "Revision $revnum\n";
      #$revnum == 165 and $DB::single = 1;
      my $log = $rec->get_property("svn:log");
      $iscvstag = $log =~ /^This commit was manufactured by cvs2svn to create tag/;
      $iscvsbranch = $log =~ /^This commit was manufactured by cvs2svn to create branch/;

      if ($iscvstag || $iscvsbranch) {
	$pending = 1;
	$pending_rev = $revnum-1;
	$action = "SKIP";
      }
    }
    when ("node") {
      my $path = $rec->get_header('Node-path');
      my $outpath = $path;
      my $kind = $rec->get_header('Node-kind') || '';
      my $copyfrom = $rec->get_header("Node-copyfrom-path") || "";
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
	  $kind eq "file") {
	$action = "SKIP";
      }
      if ($iscvsbranch &&
	  $kind eq "file") {
	$action = "SKIP";
      }
      if ($iscvstag) {
	if ($kind eq "dir"
	  && $rec->get_header("Node-copyfrom-path") eq "branches/devel") {
	  $rec->set_header("Node-copyfrom-path", "trunk/Imager");
	}
	else {
	  $action = "SKIP";
	}
      }
      if ($iscvsbranch) {
	if ($kind eq "dir" && ($copyfrom eq "branches/devel" || $copyfrom eq "trunk")) {
print STDERR "New branch $outpath\n";
	  $rec->set_header("Node-copyfrom-path", "trunk/Imager");
	}
	else {
	  $action = "SKIP";
	}
      }

      if ($outpath =~ s(^branches/Imager/)(branches/)) {
	$rec->set_header('Node-path', $outpath);
      }
      elsif ($outpath =~ s((^branches/\w+/)Imager/)($1)) {
 	$rec->set_header('Node-path', $outpath);
print STDERR "  Branch rename $outpath\n";
      }
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
  if ($pending) {
    push @pending, $rec;
    my $copyrev = $rec->get_header("Node-copyfrom-rev");
    if ($copyrev && $copyrev > $pending_rev) {
      $pending_rev = $copyrev;
    }
    $action = "SKIP";
  }
  if ($action eq "KEEP") {
    print_recs($rec);
  }
  print STDERR "EndRecord\n";
}

if (@pending) {
  end_pending(\@pending, $pending_rev);
}

sub print_recs {
  my (@recs) = @_;

  for my $rec (@recs) {
    my $text = $rec->as_string;
    $text =~ s/^Content-length: 0\n//m;
    $text =~ s/^Prop-content-length: 0\n//m;
    print $text;
  }
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

sub end_pending {
  my ($pending, $rev) = @_;

  # discard the individual copies
  splice(@$pending, 2);

  $pending->[1]->set_header("Node-copyfrom-rev", $rev);
  print_recs(@$pending);

  @$pending = ();
}
