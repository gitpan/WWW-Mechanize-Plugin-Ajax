# Interface for XML::DOM::Lite, version 0.15
package WWW::Mechanize::Plugin::Ajax;
use XML::DOM::Lite;
use HTML::DOM::Interface ':all'; # for the constants

  %WWW::Mechanize::Plugin::Ajax::_xml_interf = (
  	'XML::DOM::Lite::Document' => 'Document',
  	'XML::DOM::Lite::Node' => 'Node',
  	'XML::DOM::Lite::NodeList' => 'NodeList',
  	 Document => {
		_isa => 'Node',
		_hash => 0,
		_array => 0,
  		doctype => OBJ | READONLY,
  		implementation => OBJ | READONLY,
  		documentElement => OBJ | READONLY,
  		createElement => METHOD | OBJ,
  		createDocumentFragment => METHOD | OBJ,
  		createTextNode => METHOD | OBJ,
  		createComment => METHOD | OBJ,
  		createCDATASection => METHOD | OBJ,
  		createProcessingInstruction => METHOD | OBJ,
  		createAttribute => METHOD | OBJ,
  		createEntityReference => METHOD | OBJ,
  		getElementsByTagName => METHOD | OBJ,
  	 },
  	 Node => {
		_hash => 0,
		_array => 0,
  		_constants => [qw[
  			XML::DOM::Lite::Node::ELEMENT_NODE
  			XML::DOM::Lite::Node::ATTRIBUTE_NODE
  			XML::DOM::Lite::Node::TEXT_NODE
  			XML::DOM::Lite::Node::CDATA_SECTION_NODE
  			XML::DOM::Lite::Node::ENTITY_REFERENCE_NODE
  			XML::DOM::Lite::Node::ENTITY_NODE
  			XML::DOM::Lite::Node::PROCESSING_INSTRUCTION_NODE
  			XML::DOM::Lite::Node::COMMENT_NODE
  			XML::DOM::Lite::Node::DOCUMENT_NODE
  			XML::DOM::Lite::Node::DOCUMENT_TYPE_NODE
  			XML::DOM::Lite::Node::DOCUMENT_FRAGMENT_NODE
  			XML::DOM::Lite::Node::NOTATION_NODE
  		]],
  		nodeName => STR | READONLY,
  		nodeValue => STR,
  		nodeType => NUM | READONLY,
  		parentNode => OBJ | READONLY,
  		childNodes => OBJ | READONLY,
  		firstChild => OBJ | READONLY,
  		lastChild => OBJ | READONLY,
  		previousSibling => OBJ | READONLY,
  		nextSibling => OBJ | READONLY,
  		attributes => OBJ | READONLY,
  		ownerDocument => OBJ | READONLY,
  		insertBefore => METHOD | OBJ,
  		replaceChild => METHOD | OBJ,
  		removeChild => METHOD | OBJ,
  		appendChild => METHOD | OBJ,
  		hasChildNodes => METHOD | BOOL,
  		cloneNode => METHOD | OBJ,
  	 },
  	 NodeList => {
		_hash => 1,
		_array => 1,
  		item => METHOD | OBJ,
  		length => NUM | READONLY,
  	 },
  );

for my $i(\%WWW::Mechanize::Plugin::Ajax::_xml_interf){
	for(grep /::/, keys %$i) {
		my $i = $$i{$$i{$_}};
		for my $k(grep !/^_/,keys%$i){
			delete $$i{$k} unless $_->can($k);
		}
	}	
}
__
