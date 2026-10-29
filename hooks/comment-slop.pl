#!/usr/bin/env perl
# Flags comment slop in the lines a unified diff adds: the patterns from the code-comments skill
# that a regex can catch. Judgement calls, like a comment restating its line, are left to review.
# Usage: git diff -U0 <base>...<head> | perl comment-slop.pl
# Prints file:line: finding: comment, and exits 1 when anything is found. Under GitHub Actions
# it also prints an error annotation per finding.
use strict;
use warnings;
use utf8;
use Encode qw(decode);

binmode STDOUT, ':encoding(UTF-8)';

my $SKIP_PATH = qr{(?:^|/)(?:node_modules|vendor|dist|build|\.git)/|\.min\.\w+$|(?:^|/)(?:package-lock\.json|yarn\.lock|pnpm-lock\.yaml|uv\.lock|Cargo\.lock|poetry\.lock|go\.sum)$|\.(?:md|mdx|markdown|txt|rst|adoc|json|csv|svg|snap|lock|png|jpe?g|gif|webp|ico|pdf)$}i;
my $SLASH_EXT = qr{\.(?:js|jsx|mjs|cjs|ts|tsx|mts|cts|java|kt|kts|swift|go|rs|c|h|cc|cpp|hpp|cs|scss|less|dart|php|scala|groovy|vue|svelte|css)$}i;
my $HASH_EXT = qr{\.(?:py|pyi|sh|bash|zsh|rb|ya?ml|toml|pl|pm|r|ex|exs|cfg|ini|conf|tf|nix|ps1|cmake|mk)$|(?:^|/)(?:Dockerfile[^/]*|Makefile|Gemfile|Rakefile|\.gitignore|\.dockerignore|\.env[^/]*)$}i;
my $MARKUP_EXT = qr{\.(?:html?|xml|vue|svelte|astro)$}i;
my $HASH_DIRECTIVE = qr{^#(?:!|include|define|undef|ifn?def|if|elif|else|endif|pragma|import|region|endregion|error|warning|line|\[|\{)}i;

my ($file, $line, @findings);

sub comment_text {
    my ($code) = @_;
    my $t = $code;
    $t =~ s/^\s+//;
    my $slash = $file =~ $SLASH_EXT;
    my $hash = $file =~ $HASH_EXT;
    my $markup = $file =~ $MARKUP_EXT;
    if ($slash && $t =~ m{^(?:\{\s*)?/[/*]}) { return $t }
    if ($slash && $t =~ m{^\*(?:\s|/|$)}) { return $t }
    if ($hash && $t =~ /^#/ && $t !~ $HASH_DIRECTIVE) { return $t }
    if ($markup && $t =~ /^<!--/) { return $t }
    if ($slash && $code =~ m{\S\s+(//\s.*)$} && $code !~ m{:\s*//}) { return $1 }
    if ($hash && $code =~ m{\S\s+(#\s.*)$}) { return $1 }
    return;
}

sub check {
    my ($raw) = @_;
    my $c = $raw;
    $c =~ s{^\{?\s*(?://+|/\*+|\*+/?|#+|<!--)\s*}{};
    $c =~ s{\s*(?:\*+/\s*\}?|-->)\s*$}{};
    my @hits;
    (my $unquoted = $c) =~ s/"[^"]*"|`[^`]*`//g;
    push @hits, 'em-dash in a comment (use a comma, colon, period or parentheses)' if $unquoted =~ /\x{2014}/;
    push @hits, 'banner comment' if $c =~ /^[=\-*#~_+\x{2500}-\x{257F}]{4,}/ || $c =~ /[=\-*#~\x{2500}-\x{257F}]{4,}\s*$/;
    push @hits, 'step narration' if $c =~ /^(?:(?i:step)\s*\d+\b|(?:First|Finally)\s*(?:,|:|\.\.\.))/;
    push @hits, 'emoji in a comment' if $c =~ /[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B50}\x{2B55}]/;
    push @hits, 'end-of-block marker' if $c =~ /^end\s+(?:of\s+)?(?:if|for|foreach|while|loop|function|func|method|class|switch|try|block|module|component)\b/i;
    push @hits, 'empty label' if $c =~ /^(?:main logic|helper functions?|helpers|utility functions?|utils|error handling|handle errors?|imports?|variables|constants|constructor|initiali[sz]e(?: variables| state)?|return(?: the)? result|main function|loop through(?: the)? items)\s*[.:]?\s*$/i;
    if ($c =~ /\b(?:TODO|FIXME|XXX|HACK)\b(\([^)]*\))?\s*:?\s*(.*)$/) {
        my ($owner, $task) = ($1 // '', $2);
        my @words = split ' ', $task;
        push @hits, 'TODO without a task (say what to do and why, or link a ticket)'
            if @words < 4 && "$owner $task" !~ m{#\d+|[A-Z][A-Z0-9]+-\d+|https?://};
    }
    if ($c =~ /^(?:\@param\s+(?:\{[^}]*\}\s+)?\[?([\w.\$]+)\]?|:param\s+(?:\w+\s+)?(\w+):)\s*-?\s*(.*)$/) {
        my ($name, $desc) = ($1 // $2, lc $3);
        $desc =~ s/^(?:the|a|an)\s+//;
        $desc =~ s/[^a-z0-9]//g;
        (my $n = lc $name) =~ s/[^a-z0-9]//g;
        push @hits, "doc line that only repeats the parameter name" if $desc eq '' || $desc eq $n;
    }
    return @hits;
}

while (my $bytes = <STDIN>) {
    my $l = decode('UTF-8', $bytes);
    chomp $l;
    if ($l =~ m{^\+\+\+ (?:b/)?(.*)$}) { $file = $1; $file =~ s/\t.*$//; next }
    if ($l =~ /^@@ -\S+ \+(\d+)/) { $line = $1; next }
    next unless defined $file && defined $line;
    next if $file eq '/dev/null' || $file =~ $SKIP_PATH;
    if ($l =~ /^\+(.*)$/) {
        my $code = $1;
        if (defined(my $text = comment_text($code))) {
            push @findings, [$file, $line, $_, $text] for check($text);
        }
        $line++;
    } elsif ($l !~ /^-/ && $l !~ /^\\/) {
        $line++;
    }
}

for my $f (@findings) {
    my ($path, $n, $what, $text) = @$f;
    $text =~ s/^\s+|\s+$//g;
    print "$path:$n: $what: $text\n";
    print "::error file=$path,line=$n,title=Comment slop::$what\n" if ($ENV{GITHUB_ACTIONS} // '') eq 'true';
}
exit(@findings ? 1 : 0);
