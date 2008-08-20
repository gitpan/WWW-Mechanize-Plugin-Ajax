#!/usr/bin/perl

BEGIN { require 5.006; }
use ExtUtils::MakeMaker;
%prq = (
        constant                           => 1.03, # multip. const. @ 1ce
        constant::lexical                  => 0,
        Encode                             => 2.09, # decode $ref
        HTML::DOM::Event                   => 0,
	HTML::DOM::Exception               => 0,
        HTML::DOM::Interface               => 0,
        HTTP::Cookies                      => 0,
	HTTP::Headers                      => 0, # version ???
        HTTP::Headers::Util                => 0,
        HTTP::Request                      => 0, # version ???
	LWP::Protocol                      => 0,
        Scalar::Util                       => 1.09,
        URI                                => 1, # new_abs
	URI::Escape                        => 0, # version ???
        warnings                           => 0,
        WWW::Mechanize::Plugin::JavaScript =>  .003, # correct types for
                                                    # bound read-only props
        XML::DOM::Lite                     => 0, # version???
# for testing:
	HTML::DOM::Exception               => .013, # code
	HTTP::Response => 0, # version???
	lib => 0,
	strict => 0,
	Test::More => 0,
	utf8 => 0,
	warnings => 0,
        WWW::Mechanize::Plugin::JavaScript =>  .004, # location stringific.
);

eval{require WWW::Mechanize}
	&& WWW::Mechanize->can('use_plugin')
or $prq{WWW::Mechanize} = 9999, print <<, "\n" ;
This module requires the experimental version of WWW::Mechanize that
is to be found at the following URL:
http://www-mechanize.googlecode.com/svn/branches/plugins/



WriteMakefile(
    NAME                => 'WWW::Mechanize::Plugin::Ajax',
    AUTHOR              => 'Father Chrysostomos <sprout & cpan . org>',
    VERSION_FROM        => 'lib/WWW/Mechanize/Plugin/Ajax.pm',
    ABSTRACT_FROM       => 'lib/WWW/Mechanize/Plugin/Ajax.pm',
    PL_FILES            => {},
    PREREQ_PM           => \%prq,
    dist               => { COMPRESS => 'gzip -9f', SUFFIX => 'gz',
                            TAR => 'COPYFILE_DISABLE=1 tar' },
    clean              => { FILES => 'WWW-Mechanize-Plugin-Ajax-*' },
);
