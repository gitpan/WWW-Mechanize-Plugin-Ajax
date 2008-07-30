package WWW::Mechanize::Plugin::Ajax;

use 5.006;

use HTML::DOM::Interface ':all';
use Scalar::Util 'weaken';

# just 2 check the version:
use WWW::Mechanize::Plugin::JavaScript 0.003 ();
# Note: It’s actually WWW::Mechanize::Plugin::JavaScript::JE 0.003 that we
# need,  *if* the JE back end is being used. Since we would need version 
# 0.003 of the plugin to see which back end is being used, why bother?

use warnings; no warnings 'utf8';

our $VERSION = '0.01';

sub init {
	my($pack,$mech) = (shift,shift);
	my $js_plugin = $mech->use_plugin(JavaScript => @{$_[0]});
	@{$_[0]} = ();
	
	$js_plugin->bind_classes({
		__PACKAGE__.'::XMLHttpRequest' => 'XMLHttpRequest',
		XMLHttpRequest => {
			_constructor => sub {
				(__PACKAGE__."::XMLHttpRequest")->new(
					$mech, @_)
			},
			# ~~~ I need to verify these return types.
			abort => METHOD | VOID,
			getAllResponseHeaders => METHOD | STR,
			getResponseHeader => METHOD | STR,
			open => METHOD | VOID,
			send => METHOD | VOID,
			setRequestHeader => METHOD | VOID,

			onreadystatechange => OBJ,
			readyState => NUM | READONLY,
			responseText => STR | READONLY,
			responseXML => OBJ | READONLY,
			status => NUM | READONLY,
			statusText => STR | READONLY,
		},
	});

	weaken $mech; no warnings 'parenthesis';
	return bless \my $foo, $pack;
	# That $foo thing is used below to store one tiny bit of info:
	# whether bind_class has been called yet. (I’ll have to change the
	# structure if we need to store anything else.)
}

sub options {
	${+shift}->plugin('JavaScript')->options(@_);
}

package WWW::Mechanize::Plugin::Ajax::XMLHttpRequest;

use Encode 'decode';
use Scalar::Util qw 'weaken blessed';
use HTTP::Headers::Util 'split_header_words';
use HTTP::Request;

no constant 1.03 ();
use constant::lexical {
	mech => 0,
	clone => 1,
	method => 2,
	url => 3,
	async => 4,
	name => 5,
	pw => 6,
	orsc => 7,
	state => 8,
	res => 9,
	headers => 10,
	tree => 11,
	xml => 12, # boolean
};

sub new {
	my $self = bless [], shift;
	$self->[mech] = shift;
	weaken $self->[mech];
	$self->[state] = 0;
	$self;
}


# Instance Methods

sub open{
	my ($self) = shift;
	@$self[method,url,async,name,pw] = @_;
	$self->[url] = "$self->[url]"; # HTTP::Request doesn’t like objects
	@_ < 3 and $self->[async] = 1; # default
	$self->[state]=1;
	$self->[orsc] && $self->[orsc](); # ~~~ What about a ‘this’ value?
	return;
}

sub send{
	my ($self, $data) = @_;
	my $clone = $self->[clone] =
		$self->[mech]->clone->clear_history(1);
	$clone->stack_depth(1);
	defined $self->[name] || defined $self->[pw] and
		$clone->credentials($self->[name], $self->[pw]);
	my $request = new HTTP::Request uc $self->[method], $self->[url],
		$self->[headers]||[],
		$data;
	$self->[state] = 2; # sent
	$self->[orsc] && $self->[orsc](); # ~~~ What about a ‘this’ value?
	my $res = $self->[res] = $clone->request($request);

	$self->[xml] = ($res->content_type||'') =~
	   /(?:^(?:application|text)\/xml|\+xml)\z/ || undef;
	# This needs to be undef, rather than false, for responseXML to
	# work correctly.

	$self->[state] = 4; # complete
	$self->[orsc] && $self->[orsc](); # ~~~ What about a ‘this’ value?
	delete $self->[tree] ;

	return $res->is_success;
	# ~~~ Ajax for Web Application Developers says it has to equal 200.
	#     That doesn’t sound right to me. (E.g., what if it’s 206?)
}

sub abort { # ~~~ If I make this asynchronous, this method might actually
            #     be made to do something useful.
	shift->[state] = 0;
	return
}

sub getAllResponseHeaders { # ~~~ is the format correct?
	shift->[res]->headers->as_string
}

sub getResponseHeader {
	shift->[res]->header(shift)
}

sub setRequestHeader {
	push@{shift->[headers] ||= []}, shift, shift;
}
# ~~~ Quoth Ajax for Web Application Developers: ‘If a header is not well
# formed, it is not used and an error occurs, which stops the header from
# being set.’ What does this mean?


# Attributes

sub onreadystatechange {
	my $old = $_[0]->[orsc];
	$_[0]->[orsc] = $_[1] if @_ > 1;
	$old;
}

sub readyState {
	shift->[state];
}

sub responseText { # string response from the server
	my $content = (my $res = $_[0]->[res]||return '')->content;
	my $cs = { map @$_,
	  split_header_words $res->header('Content-Type')
	 }->{charset};
	decode defined $cs ? $cs : utf8 => $content
}

sub responseXML { # XML::DOM::Lite object
	my $self = shift;
	$$self[state] == 4 or return;
	$$self[tree] || $$self[xml] && do {
		require WWW::Mechanize::Plugin::Ajax::_xml_stuff;
		$$self[mech]->plugin('JavaScript')->bind_classes(
			\%WWW::Mechanize::Plugin::Ajax::_xml_interf
		) unless ${$$self[mech]->plugin('Ajax')}++;
		$self->[tree] =
		    XML::DOM::Lite::Parser->parse($$self[res]->content);
		# ~~~ xdlp returns an empty document when there is a parse
		#     error. Could I detect that and return nothing? Or can
		#     a valid XML document be empty?
	}
}

sub status { # HTTP status code
	die "The HTTP status code is not available yet"
		if $_[0][state] < 3;
	shift->[res]->code
}

sub statusText { # HTTP status massage
	die "The HTTP status message is not available yet"
		if $_[0][state] < 3;
	shift->[res]->message
}


!+()

__END__

How on earth should the control flow work if the
connection is supposed to be asynchronous? If threads are supported, I
could make the connection in another thread, and have some message passed
back. The client script (in the main thread) will have to tell the
XMLHttpRequest object to check whether it's ready yet (from some event
loop, presumably), and, if it is, the
latter will call its readystatechange event. This could be hooked into the
wmpjs's timeout system.

If threads are not supported, I could just make it synchronous, and have
the event triggered before the C<send> method returns. Maybe this should be
the default even with a threaded Perl, and the threaded behaviour should be
optional.

=head1 NAME

WWW::Mechanize::Plugin::Ajax - WWW::Mechanize plugin that provides the XMLHttpRequest object

=head1 VERSION

Version 0.01 (alpha)

=head1 SYNOPSIS

  use WWW::Mechanize;
  $m = new WWW::Mechanize;
  
  $m->use_plugin('Ajax');
  $m->get('http://some.site.com/that/relies/on/ajax');

=head1 DESCRIPTION

This module is a plugin for L<WWW::Mechanize> that loads the JavaScript
plugin (L<WWW::Mechanize::Plugin::JavaScript>) and provides it with the
C<XMLHttpRequest> object.

To load the plugin, use L<WWW::Mechanize>'s C<use_plugin> method, as shown
in the Synopsis. (The
current stable release of W:M doesn't support it; see L</PREREQUISITES>,
below.) Any extra arguments to C<use_plugin> will be passed on to the
JavaScript plugin (at least for now).

=head1 ASYNCHRONY

The C<XMLHttpRequest> object currently does not support asynchronous
connections. Later this will probably become an option, at least for
threaded perls.

=head1 PREREQUISITES

This plugin requires perl 5.8.3 or higher, and the following modules:

=over 4

=item *

WWW::Mechanize::Plugin::JavaScript version 0.003 or
later

=item *

constant 1.03 or later

=item *

constant private

=item *

XML::DOM::Lite

=back

And you'll also need the experimental version of 
WWW::Mechanize available at
L<http://www-mechanize.googlecode.com/svn/branches/plugins/>

=head1 BUGS

If you find any bugs, please report them to the author by e-mail
(preferably with a
patch :-).

There is currently one known security issue: The server to which a request
is sent is not checked to see whether it the same server from which
the requesting page originated.

Fake cookies (created with the C<setRequestHeader> method) are clobbered if
there are any real cookies.

XML::DOM::Lite is quite lenient toward badly-formed XML, so the 
C<responseXML> property returns something useful even in cases when it
should be null.

Furthermore, this module follows the badly-designed API that is
unfortunately the de facto standard so I can't do anything about it.

=head1 AUTHOR & COPYRIGHT

Copyright (C) 2007 Father Chrysostomos
<C<< ['sprout', ['org', 'cpan'].reverse().join('.')].join('@') >>E<gt>

This program is free software; you may redistribute it and/or modify
it under the same terms as perl.

=head1 SEE ALSO

L<WWW::Mechanize>

L<WWW::Mechanize::Plugin::JavaScript>

L<XML::DOM::Lite>
