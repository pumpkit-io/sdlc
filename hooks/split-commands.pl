#!/usr/bin/env perl
# Reads a shell command line on stdin and prints one simple command per line, in order, for the hooks.
# Heredoc bodies are dropped unless a shell reads them, `sh -c` and `eval` arguments become commands of
# their own, and a quoted string stays only when it is a single word (so `"main"` survives and a commit
# message doesn't).
use strict;
use warnings;

my $s = do { local $/; <STDIN> };
$s = "" unless defined $s;
my (@out, @pending);
for my $line (split /\n/, $s, -1) {
  if (@pending) {
    my ($term, $keep) = @{ $pending[0] };
    if ($line =~ /^\s*\Q$term\E\s*$/) { shift @pending; next }
    push @out, $line if $keep;
    next;
  }
  push @out, $line;
  while ($line =~ /(?<!<)<<(?!<)-?\s*([\x27"]?)([A-Za-z_][\w-]*)\1/g) {
    my $before = substr($line, 0, $-[0]);
    push @pending, [$2, $before =~ /(?:^|[\s;&|(])(?:ba|z|da)?sh(?:\s+-\S+)*\s*$/ ? 1 : 0];
  }
}
$s = join "\n", @out;
my @lifted;
while ($s =~ /(?:\b(?:ba|z|da)?sh\s+-c|\beval)\s+(\x27[^\x27]*\x27|"(?:[^"\\]|\\.)*")/g) {
  push @lifted, substr($1, 1, -1);
}
$s = join "\n", $s, @lifted;
$s =~ s{\x27([^\x27]*)\x27|"((?:[^"\\]|\\.)*)"}{
  my $q = defined $1 ? $1 : $2;
  $q =~ /^[^\s;&|()<>`\$]*$/ ? $q : " _ ";
}ge;
for (split /[;&|\n()`]/, $s) { s/^\s+|\s+$//g; print "$_\n" if length }
