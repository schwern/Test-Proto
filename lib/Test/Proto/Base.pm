package Test::Proto::Base;
use 5.006;
use strict;
use warnings;
use base 'Test::Builder::Module';
use Test::Deep::NoTest; # provides eq_deeply for _is_deeply. Consider removing this dependency.
use Test::Proto::Test;
use Test::Proto::Fail;
use Test::Proto::Exception;
use Data::Dumper; # not used in canonical but keep for the moment for development
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;
our $VERSION = '0.01';
my $CLASS = __PACKAGE__;

sub initialise
{
	return $_[0];
}

sub new
{
	my $class = shift;
	my $self = bless {
		tests=>[],
	}, $class;
	return $self->initialise;
}

sub clone
{
	my $self = shift;
	my $new = bless {
		tests=>$self->{'tests'},
	}, ref $self;
	return $new;
}

sub add_test #???
{
	my ($self, $testtype, @args) = @_;
	my $test = Test::Proto::Test->new($testtype, @args);

	if (defined $test)
	{
		push @{$self->{'tests'}}, $test;
	}
	else
	{
		warn 'Failed to create test!'; # exception?
		return undef;
	}

	return $self;
}
sub _is_defined
{
	return sub{
		my $got = shift;
		return fail('undef') unless defined $got;
		return 1;
	};
}
sub _can_be_string
{
	return sub{
		eval {$_[0] .= ''};
		return fail($@) if $@;
		return 1;
	};
}
sub as_string
{
	my ($self, $expected, $why) = @_;
	$self->add_test(_as_string($self->upgrade($expected)), $why);
}

sub _as_string
{
	my ($expected) = @_;
	return sub{
		return $expected->validate("$_[0]");
	};
}
sub as_number
{
	my ($self, $expected, $why) = @_;
	$self->add_test(_as_number($self->upgrade($expected)), $why);
}
sub _as_number
{
	my ($expected) = @_;
	return sub{
		return $expected->validate(0+$_[0]);
	};
}
sub as_bool
{
	my ($self, $expected, $why) = @_;
	$self->add_test(_as_bool($self->upgrade($expected)), $why);
}
sub _as_bool
{
	my ($expected) = @_;
	return sub{
		return $expected->validate($_[0] ? 1 : 0);
	};
}

sub _is_a
{
	my ($type) = @_;
	return sub{
		my $got = shift;
		$type = ref $type if (ref $type);
		unless (ref $got)
		{
			return 'SCALAR' eq $type ? 1 : fail('SCALAR ne '.$type) ;
		}
		foreach (qw(
		SCALAR
		ARRAY
		HASH
		CODE
		REF
		GLOB
		LVALUE
		FORMAT
		IO
		VSTRING
		Regexp))
		{
			if (ref $got eq $_)
			{
				return $_ eq $type ? 1 : fail ("$_ ne $type");
			}
		}
		return $got->isa($type);
	}
}
sub _is_ne
{
	my ($expected) = @_;
	return sub{
		my $got = shift;
		my $result;
		eval {$result = "$got" ne "$expected"};
		return fail($@) if $@;
		return $result ? 1 : fail("\"$got\" eq \"$expected\"");
	};
}
sub _is_also
{
	my ($expected) = @_;
	return sub{
		my $got = shift;
		my $result;
		eval {$result = $expected->validate($got)};
		return fail($@) if $@;
		return $result;
	};
}

sub validate
{
	my ($self, $got) = @_;
	foreach (@{$self->{'tests'}})
	{
		my $result = $_->run($got);
		return $result unless $result;
	}
	return 1;
}
sub is_also
{
	my ($self, $expected, $why) = @_;
	$self->add_test(_is_also($self->upgrade($expected)), $why);
}

sub is_a
{
	my ($self, $expected, $why) = @_;
	$self->add_test(_is_a($expected), $why);
}
sub is_defined
{
	my ($self, $why) = @_;
	$self->add_test(_is_defined(), $why);
}
sub ok
{
	my($self, $got, $why) = @_;
	my $tb = $CLASS->builder;
	my $result = $self->validate($got);
	# output failure:
	$tb->diag($result) unless $result;
	return $tb->ok($result, $why);
}
sub eq
{
	my ($self, $cmp, $expected, $why) = @_;
	$self->add_test(_cmp($cmp, 'eq', $expected), $why);
}
sub ne
{
	my ($self, $cmp, $expected, $why) = @_;
	$self->add_test(_cmp($cmp, 'ne', $expected), $why);
}
sub gt
{
	my ($self, $cmp, $expected, $why) = @_;
	$self->add_test(_cmp($cmp, 'gt', $expected), $why);
}
sub ge
{
	my ($self, $cmp, $expected, $why) = @_;
	$self->add_test(_cmp($cmp, 'ge', $expected), $why);
}
sub lt
{
	my ($self, $cmp, $expected, $why) = @_;
	$self->add_test(_cmp($cmp, 'lt', $expected), $why);
}
sub le
{
	my ($self, $cmp, $expected, $why) = @_;
	$self->add_test(_cmp($cmp, 'le', $expected), $why);
}

sub is_eq
{
	my ($self, $expected, $why) = @_;
	$self->add_test(_is_eq($expected), $why);
}
sub is_ne
{
	my ($self, $expected, $why) = @_;
	$self->add_test(_is_ne($expected), $why);
}
sub is_deeply
{
	my ($self, $expected, $why) = @_;
	$self->add_test(_is_deeply($expected), $why);
}
sub is_like
{
	my ($self, $expected, $why) = @_;
	$self->add_test(_is_like($expected), $why);
}
sub is_unlike
{
	my ($self, $expected, $why) = @_;
	$self->add_test(_is_unlike($expected), $why);
}
sub _is_eq
{
	my ($expected) = @_;
	return sub{
		my $got = shift;
		my $result;
		eval {$result = "$got" eq "$expected"};
		return fail($@) if $@;
		return $result ? 1 : fail("\"$got\" ne \"$expected\"");
	};
}
sub _cmp
{
	my ($cmp, $type, $expected) = @_;
	return sub{
		my $got = shift;
		my $result;
		my $success=0;
		eval {$result = &{$cmp}($got,$expected)};
		return fail($@) if $@;
		if ($result > 0 and $type =~ /ge|gt|ne/)
		{
			$success = 1;
		}
		elsif ($result == 0 and $type =~ /ge|le|eq/)
		{
			$success = 1;
		}
		elsif ($result < 0 and $type =~ /lt|le|ne/)
		{
			$success = 1;
		}
		return $success ? 1 : fail("\"$got\" !$type \"$expected\"");
	};
}
sub _is_deeply
{
	my ($expected) = @_;
	return sub{
		my $got = shift;
		my $result;
		eval {$result=eq_deeply ($got, $expected)}; # consider replacing this with something more 'native' later. 
		return fail($@) if $@;
		return $result ? 1 : fail(Dumper ($got). " !is_deeply ". Dumper($expected));
	};
}
sub _is_like
{
	my ($expected) = @_;
	return sub{
		my $got = shift;
		my $result;
		eval {$result = "$got" =~ m/$expected/};
		return fail($@) if $@;
		return $result ? 1 : fail("\"$got\" !~ /$expected/");
	};
}
sub _is_unlike
{
	my ($expected) = @_;
	return sub{
		my $got = shift;
		my $result;
		eval {$result = "$got" !~ m/$expected/};
		return fail($@) if $@;
		return $result ? 1 : fail("\"$got\" =~ /$expected/");
	};
}

sub try
{
	my ($self, $code, $why) = @_;
	$self->add_test(_try($code), $why);
}
sub _try
{
	my ($code) = @_;
	return sub{
		my $got = shift;
		my $result;
		eval {$result = &{$code}($got)};
		return fail($@) if $@;
		return $result ? 1 : fail("try returned ".$result);
	};
}
sub upgrade
{
	my ($self, $expected, $why) = @_;
	if (&{_is_a('SCALAR')}($expected))
	{
		return Test::Proto::Base->new($why)->is_eq($expected);
	}
	# returns => implicit elses
	if (&{_is_a('Test::Proto::Base')}($expected) or &{_is_a('Test::Proto::Series')}($expected))
	{
		return $expected;
	}
	if (&{_is_a('Regexp')}($expected))
	{
		return Test::Proto::Base->new($why)->is_like($expected);
	}
	if (&{_is_a('ARRAY')}($expected))
	{
		return Test::Proto::ArrayRef->new($why)->is_deeply($expected); # iterate?
	}
	if (&{_is_a('HASH')}($expected))
	{
		return Test::Proto::HashRef->new($why)->is_deeply($expected);
	}
	if (&{_is_a('CODE')}($expected))
	{
		return Test::Proto::Base->new($why)->add_test($expected);
	}
	if (ref $expected)
	{
		return Test::Proto::Object->new($why)->is_a(ref $expected);
	}
	return $expected; # exception?
}

sub fail
{
	# should there be a metasugar module for things like this?
	# More detailed interface to T::P::Fail? (More detailed T::P::F first!)
	my ($why) = @_;
	# warn $why; # results in false positives
	return Test::Proto::Fail->new($why);
}

sub exception
{
	my ($why) = @_;
	return Test::Proto::Exception->new($why);
}


#sub fail
#{
#	my ($self, $name, $why) = @_;
#	return Test::Proto::Fail->new();
#}

return 1; # module loaded ok

=pod
=head1 NAME

Test::Proto::HashRef - Test Prototype for Hash References. 

=head1 SYNOPSIS

	my $test = Test::Proto::Base->new->is_eq(-5);
	$test->ok ($temperature) # will fail unless $temperature is -5
	$test->ok ($score) # you can use the same test multple times
	ok($test->validate($score)) # If you like your "ok"s first

This is a test prototype which requires that the value it is given is defined and is a hashref. It provides methods for interacting with hashrefs. (To test hashes, make them hashrefs and test them with this module)

=head1 METHODS

=head3 new

=head3 initialise

=head3 add_test

=head3 is_a

=head3 is_also

=head3 is_defined

=head3 is_eq

=head3 is_ne

=head3 is_like

=head3 is_unlike

=head3 validate

=head3 ok

=head3 upgrade

=head3 clone

=head3 as_string

=head3 as_number

=head3 as_bool


=head1 OTHER INFORMATION

For author, version, bug reports, support, etc, please see L<Test::Proto>. 


