package Module::XSOrPP;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Dist::Util qw(packlist_for);
use Module::Path::More qw(module_path);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       is_xs
                       is_pp
                       xs_or_pp
               );

our @XS_OR_PP_MODULES = qw(
                              Params::Validate
                              Params::Util
                              List::MoreUtils
);

our @XS_MODULES = qw(
                        Scalar::Util
                );

our @PP_MODULES = qw(
                );

sub xs_or_pp {
    use experimental 'smartmatch';

    my ($mod, $opts) = @_;
    die "Please specify module\n" unless $mod;

    if ($mod =~ m!/!) {
        $mod =~ s!/!::!g;
        $mod =~ s/\.pm$//;
    }

    $opts //= {};
    $opts->{warn}  //= 0;
    my $warn = $opts->{warn};
    $opts->{debug} //= 0;
    my $debug = $opts->{debug};

    if ($mod ~~ @XS_OR_PP_MODULES) {
        warn "$mod is xs_or_pp (from list)\n" if $debug;
        return "xs_or_pp";
    }

    if ($mod ~~ @XS_MODULES) {
        warn "$mod is xs (from list)\n" if $debug;
        return "xs";
    }

    if ($mod ~~ @PP_MODULES) {
        warn "$mod is pp (from list)\n" if $debug;
        return "pp";
    }

    my $path = packlist_for($mod);
    {
        last unless $path;
        my $fh;
        unless (open $fh, '<', $path) {
            warn "Can't open .packlist $path: $!\n" if $warn;
            last;
        }
        while (my $line = <$fh>) {
            chomp $line;
            if ($line =~ /\.(bs|so|[Dd][Ll][Ll])\z/) {
                warn "$mod is XS because the .packlist contains .{bs,so,dll} files\n" if $debug;
                return "xs";
            }
        }
        warn "$mod is PP because the .packlist doesn't contain any .{bs,so,dll} files\n" if $debug;
        return "pp";
    }

    $path = module_path(module=>$mod);
    {
        last unless $path;
        local $/;
        my $fh;
        unless (open $fh, '<', $path) {
            warn "Can't open module file $path: $!" if $warn;
            last;
        }
        while (my $content = <$fh>) {
            if ($content =~ m!^\s*(use|require) \s+ (DynaLoader|XSLoader)\b!mx) {
                warn "$mod is XS because the source contains 'use {DynaLoader,XSLoader}' statement\n" if $debug;
                return "xs";
            }
        }
        warn "$mod is PP because the source code doesn't contain any 'use {DynaLoader,XSLoader}' statement\n" if $debug;
        return "pp";
    }

    {
        my $mod = $mod;
        unless ($mod =~ /\.pm\z/) { $mod =~ s!::!/!g; $mod .= ".pm" }

        if ($mod =~ m!/XS\.pm\z|/[^/]+_(xs|XS)\.pm\z!) {
            warn "$mod is probably XS because its name contains XS" if $debug;
            return "xs";
        } elsif ($mod =~ m!/PP\.pm\z|/[^/]+_(pp|PP)\.pm\z!) {
            warn "$mod is probably PP because its name contains PP" if $debug;
            return "pp";
        }
    }

    warn "Can't determine whether $mod is XS: all methods tried\n" if $warn;
    undef;
}

sub is_xs {
    my ($mod, $opts) = @_;
    my $res = xs_or_pp($mod, $opts);
    return undef unless defined($res);
    $res eq 'xs' || $res eq 'xs_or_pp';
}

sub is_pp {
    my ($mod, $opts) = @_;
    my $res = xs_or_pp($mod, $opts);
    return undef unless defined($res);
    $res eq 'pp' || $res eq 'xs_or_pp';
}

1;
# ABSTRACT: Determine if an installed module is XS or pure-perl

=head1 SYNOPSIS

 use Module::XSOrPP qw(
     is_xs is_pp xs_or_pp
 );

 say "Class::XSAccessor is an XS module" if is_xs("Class/XSAccessor.pm");
 say "JSON::PP is a pure-Perl module" if is_pp("JSON::PP");
 say "Params::Util is an XS module with PP fallback" if xs_or_pp("Class/XSAccessor.pm") =~ /^(xs|xs_or_pp)$/;


=head1 DESCRIPTION


=head1 FUNCTIONS

=head2 xs_or_pp($mod, \%opts) => str

Return either "xs", "pp", or "xs_or_pp" (XS with a PP fallback). Return undef if
can't determine which. C<$mod> value can be in the form of C<Package/SubPkg.pm>
or C<Package::SubPkg>. The following ways are tried, in order:

=over

=item * Predetermined list

Some CPAN modules are XS with a PP fallback. This module maintains the list.

=item * Looking at the C<.packlist>

If a .{bs,so,dll} file is listed in the C<.packlist>, then it is assumed to be
an XS module. This method will fail if there is no C<.packlist> available (e.g.
core or uninstalled or when the package management strips the packlist), or if a
dist contains both pure-Perl and XS.

=item * Looking at the source file for usage of C<XSLoader> or C<DynaLoader>

If the module source code has something like C<use XSLoader;> or <use
DynaLoader;> then it is assumed to be an XS module. This is currently
implemented using a simple regex, so it is somewhat brittle.

=item * Guessing from the name

If the module has "XS" in its name then it's assumed to be an XS module. If the
module has "PP" in its name, it's assumed to be a pure-Perl module.

Known false positives will be prevented in the future.

=back

Other methods will be added in the future (e.g. a database like in
L<Module::CoreList>, consulting MetaCPAN, etc).

Options:

=over

=item * warn => BOOL (default: 0)

If set to true, will warn to STDERR if fail to determine.

=item * debug => BOOL (default: 0)

If set to true will print debugging message to STDERR.

=back

=head2 is_xs($mod, \%opts) => BOOL

Return true if module C<$mod> is an XS module, false if a pure Perl module, or
undef if can't determine either. See C<xs_or_pp> for more details.

=head2 is_pp($mod, \%opts) => BOOL

Return true if module C<$mod> is a pure Perl module or XS module with a PP
fallback. See C<is_xs> for more details. See C<xs_or_pp> for more details.

=cut
