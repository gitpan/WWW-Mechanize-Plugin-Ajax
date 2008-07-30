#!perl

use strict; use warnings;
use lib 't';
use Test::More;

use utf8;
use WWW::Mechanize;
use HTTP::Headers;
use HTTP::Response;

our %SRC;

my $m = new WWW::Mechanize;

# For faking HTTP requests; this gets the source code from the global %SRC
# hash, using the "$method $url" as the key. Each element of the hash
# is an array ref containing (0) the Content-Type and (1) text that is to
# become the body of the response or a coderef.
no warnings 'redefine';
*LWP::UserAgent::simple_request = sub {
	my($lwp, $request) = @_;
	$lwp->_request_sanity_check($request);
#diag("B4:\n".$request->as_string) if $request->as_string =~ /Cookie/;
	$request = $lwp->prepare_request($request);
#diag("AF:\n".$request->as_string) if $request->as_string =~ /Cookie/;
	
	my $src_ary = $'SRC{join ' ',method $request,$request->uri};
	my $h = new HTTP::Headers;
	header $h 'Content-Type', $$src_ary[0] if $src_ary;
	my $r = new HTTP::Response
		$src_ary ? (200, 'Okey dokes') : (404, 'Knot found'),
		$h,
		$src_ary && ref $$src_ary[1]
			? $$src_ary[1]->($request)
			: $$src_ary[1];
	request $r $request;
	$r
};

# For echo requests (well, not exactly; the responses have an HTTP response
# header as well)
$SRC{'POST http://foo.com:7/'}=['text/plain',sub{ shift->as_string }];
$SRC{'GET http://foo.com:7/'}=['text/plain',sub{ shift->as_string }];


use tests 1; # plugin isa

isa_ok $m->use_plugin('Ajax' => init => sub {
	for my $js_plugin(shift){
		$js_plugin->new_function($_ => \&$_)
			for qw 'ok is diag pass fail';
	}
}), 'WWW::Mechanize::Plugin::Ajax';


use tests 2; # inline & constructor

$SRC{'GET http://foo.com/inline.html'}=['text/html',<<'EOT'];
<title>Tests that checks whether AJAX works inline and the constructor's
basic functionality is present</title>
<script type='application/javascript'>

var request = new XMLHttpRequest
is(typeof request, 'object', 'typeof new XMLHttpRequest')
is(request, '[object XMLHttpRequest]',
	'stringification of the new object')

</script>
EOT
$m->get('http://foo.com/inline.html');


my $js = $m->plugin("JavaScript");


use tests 5; # basic request, setRequestHeader, and responseText

defined $js->eval(<<'EOT2') or die;
	
	with(request)
		open('POST','http://foo.com:7/',0),
		setRequestHeader('User-Agent', 'wmpajax'),
		setRequestHeader('Accept-Language','el'),
		send('stuff'),
		ok(status === 200, '200 status') ||
			diag(status+' '+typeof status),
		ok(responseText.match(
			/^POST http:\/\/foo\.com:7\/\r?\n/
		), 'first line of request (POST ...) and responseText'),
		ok(responseText.match(/^User-Agent: wmpajax$/m),
			'User-Agent in request'),
		ok(responseText.match(/^Accept-Language: el$/m),
			'Accept-Language in request'),
		ok(responseText.match(/\r?\n\r?\nstuff(?:\r?\n)?$/),
			'body of the request')
			|| diag(responseText)
EOT2

use tests 2; # GET and send(null)

defined $js->eval(<<'EOT3') or die;
	with(request)
		open('GET','http://foo.com:7/',0),
		send(null),
		ok(responseText.match(
			/^GET http:\/\/foo\.com:7\/\r?\n/
		), 'first line of request (GET ...)'),
		ok(responseText.match(/\r?\n\r?\n$/), 'send(null)')

EOT3


use tests 3; # name & password
{
	# I’ve got to override LWP’s simple_request again, since what we
	# have above is not sufficient for this case.

	local *LWP::UserAgent::simple_request = sub {
		my($lwp, $request) = @_;
		$lwp->_request_sanity_check($request);
		$request = $lwp->prepare_request($request);
	
		my $h = new HTTP::Headers;
		header $h 'Content-Type', 'text/html';
		header $h 'WWW-Authenticate', 'basic realm="foo"';
		my $r = new HTTP::Response
			$request->header('Authorization')
			? (200, "hokkhe", $h,
			  '<title>Wellcum</title><h1>Yoologginow</h1>'
			):(401, "Hugo's there", $h,
			  '<title>401 Forbidden</title><h1>Fivebidden</h1>'
			);
		request $r $request;
#		diag($request->as_string);
		$r
	};

	defined $js->eval(<<'	EOT3b') or die;
		with(request)
			open('GET','http://foo.com:7/',0),
			send(null),
			is(status, 401, ' \x08401'),
			ok(responseText.match(/Fivebidden/), '401 msg'),
			open('GET','http://foo.com:7/',0,'me','dunno'),
			send(null),
			ok(responseText.match(/Yoologginow/),
				'authentication')
				 || diag(getAllResponseHeaders())
	EOT3b
}


#use tests 2; # cookies
#
#defined $js->eval(<<'EOT4') or die;
#	document.cookie="foo=bar;expires=" +
#	    new Date(new Date().getTime()-24000*3600*365).toGMTString();
#	    // shouldn't take more than a year to run this test :-)
#	with(request)
#		open('GET','http://foo.com:7/',0),
#		send(),
#		ok(responseText.match(
#			/^Cookie: foo=bar$/m
#		), 'real cookies') || diag(responseText),
#		open('GET','http://foo.com:7/',0),
#		setRequestHeader('Cookie','baz=bonk'),
#		send(),
#		// ~~~ This test is incorrect:
#		ok(  responseText.match(
#			/^Cookie: foo=bar$/m
#		) && responseText.match(
#			/^Cookie: baz=bonk$/m
#		), 'phaque cookies') //|| diag(responseText)
#
#EOT4

use tests 1; # 404

defined $js->eval(<<'EOT5') or die;
	with(request)
		open('GET','http://foo.com:7/eoeoeoeoeo',0),
		send(null),
		ok(status === 404, " \x08404")

EOT5

use tests 10; # responseXML

# XML example stolen from XML::DOM::Lite’s test suite
$SRC{'GET http://foo.com/xmlexample'}=['text/xml',<<XML];
<?xml version="1.0"?>
<!-- this is a comment -->
<root>
  <item1 attr1="/val1" attr2="val2">text</item1>
  <item2 id="item2id">
    <item3 instance="0"/>
    <item4>
      deep text 1
      <item5>before</item5>
      deep text 2
      <item6>after</item6>
      deep text 3
    </item4>
    <item3 instance="1"/>
  </item2>
  some more text
</root>
XML

$SRC{'GET http://foo.com/appxmlexample'}=['application/xml',<<XML2];
<?xml version="1.0"?><root>app</root>
XML2

$SRC{'GET http://foo.com/+xmlexample'}=['image/foo+xml',<<XML3];
<?xml version="1.0"?><root>+xml</root>
XML3

$SRC{'GET http://foo.com/badxml'}=['text/xml',<<XML4];
<?xml version="1.0"?<root>bad</root>
XML4

$SRC{'GET http://foo.com/htmlexample'}=['text/html',<<HTML];
<title> This is a small HTML document</title>
<p>Which is perfectly valid except for the missing doctype header even
though it's missing half its tags
HTML

defined $js->eval(<<'EOT6') or die;
	with(request)
		open('GET','http://foo.com/htmlexample',0),
		send(null),
		ok(responseXML===null, 'null responseXML'),
		open('GET','http://foo.com/xmlexample'),
		send(),
		ok(responseXML, 'responseXML object')
			||diag(status + ' ' + responseText),
		is(responseXML.documentElement.nodeName, 'root',
			'various...'),
		is(responseXML.documentElement.childNodes.length, 5,
			'    parts of'),
		is(responseXML.documentElement.childNodes[1].nodeName,
			'item1',
			'    the XML'),
		is(responseXML.documentElement.childNodes[0].nodeName,
			'#text',
			'    DOM tree'),
		// If those pass, I think we can trust it’s working.

		open('GET','http://foo.com/appxmlexample'),
		is(responseXML, null, 'responseXML after open'),
		send(),
		is(responseXML.documentElement.firstChild.nodeValue, 'app',
			'responseXML with application/xml'),
		abort(),
		is(responseXML, null, 'responseXML after abort'),
		open('GET','http://foo.com/+xmlexample'),
		send(),
		is(responseXML.documentElement.firstChild.nodeValue,'+xml',
			'responseXML with any/thing+xml')//,
		//open('GET','http://foo.com/badxml'),
		//send(),
		//ok(responseXML===null, 'invalid XML')
		// ~~~ XML::DOM::Lite is too lenient for this test to mean
		//     anything
EOT6

use tests 2; # statusText
defined $js->eval(<<'EOT7') or die;
	with(request)
		open('GET','http://foo.com:7/eoeoeoeoeo',0),
		send(null),
		ok(statusText === 'Knot found', "404 statusText"),
		open('GET','http://foo.com:7/',0),
		send(null),
		ok(statusText === 'Okey dokes', "200 statusText")
EOT7

use tests 2; # get(All)ResponseHeader(s)
defined $js->eval(<<'EOT8') or die;
	with(request)
		open('GET','http://foo.com:7/',0),
		send(null),
		ok(getAllResponseHeaders().match(
			/^Content-Type: text\/plain\r?\n$/
		), "getAllResponseHeaders"),
		is(getResponseHeader('Content-Type'), 'text/plain',
			'getResponsHeader');
EOT8

use tests 5; # onreadystatechange and readyState
defined $js->eval(<<'EOT9') or die;
0,function(){ // the function scope provides us with a var ‘scratch-pad’
	with(new XMLHttpRequest) {
		var mystate = '';
		onreadystatechange = function(){
			mystate += readyState
		}
		ok(readyState === 0, 'readyState of fresh XHR obj')
		open('GET','http://foo.com/htmlexample',0)
		ok(readyState === 1,'readyState after open')
		is(mystate, 1, 'open triggers onreadystatechange')
		send(null)
		ok(readyState === 4, 'readyState after completion')
		ok(mystate.match(/[^4]4$/),
			'onreadystatechange is triggered for state 4')
	}
}()
EOT9

use tests 5; # unwritability of the properties
defined $js->eval(<<'EOT10') or die;
0,function(){
	var $f = function(){}
	$f.prototype = new XMLHttpRequest
	with(new $f())
		readyState='foo',
		ok(readyState===0,'readyState is read-only'),
		responseText='foo',
		ok(responseText==='','responseText is read-only'),
		readyState='responseXML',
		ok(responseXML===null,'responseXML is read-only'),
		$f.prototype.open('GET','http://fo',0),$f.prototype.send(),
		ok(status===404,'status is read-only'),
		statusText='foo',
		ok(statusText==='Knot found','statusText is read-only')
}()
EOT10

use tests 4; # encoding
$SRC{'GET http://foo.com/explicit_utf-8.text'}=
	['text/plain; charset=utf-8',"oo\311\237"];
$SRC{'GET http://foo.com/implicit_utf-8.text'} =
	['text/plain',"\311\271aq"];
$SRC{'GET http://foo.com/utf-16be.text'} =
	['text/plain; charset=utf-16be',
	 "\1\335\2\207\2P\2y\0o\2m\2m\1\335\2m\0n\2o\0n\2T\2y\35\t\2T"];
$SRC{'GET http://foo.com/latin-1.text'} =
	['text/plain; charset=iso-8859-1',"\311\271aq"];

defined $js->eval(<<'EOT11') or die;
	with(new XMLHttpRequest)
		open('GET','http://foo.com/explicit_utf-8.text',0),
		send(null),
		is(responseText, 'ooɟ','explicit utf-8 header'),
		open('GET','http://foo.com/implicit_utf-8.text',0),
		send(null),
		is(responseText, 'ɹaq','implicit charset'),
		open('GET','http://foo.com/utf-16be.text',0),
		send(null),
		is(responseText, 'ǝʇɐɹoɭɭǝɭnɯnɔɹᴉɔ', 'utf-16be charset'),
		open('GET','http://foo.com/latin-1.text',0),
		send(null),
		is(responseText, 'É¹aq', 'iso-8859-1 for the charset')
EOT11

use tests 4; # status & statusText exceptions
defined $js->eval(<<'EOT12') or die;
	with(new XMLHttpRequest) {
		try{status;fail('status exception before open')}
		catch($){pass('status exception before open')}
		try{statusText;fail('statusText exception before open')}
		catch($){pass('statusText exception before open')}
		open('GET','http://foo.com:7/eoeoeoeoeo',0)
		try{status;fail('status exception before send')}
		catch($){pass('status exception before send')}
		try{statusText;fail('statusText exception before send')}
		catch($){pass('statusText exception before send')}
	}
EOT12

__END__
	

To add tests for:

third arg for open (once asynchrony is implemented)
