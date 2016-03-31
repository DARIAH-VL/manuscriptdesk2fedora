requires 'perl','5.10.1';
requires 'Catmandu','1.00';
requires 'Catmandu::MediaWiki','0.021';
requires 'Catmandu::FedoraCommons','0.274';
requires 'Clone','0';
requires 'WWW::Mechanize','0';
requires 'HTML::TreeBuilder::XPath','0';

on 'test', sub {
    requires 'Test::Exception','0';
    requires 'Test::More','0';
};
