manuscriptdesk2fedora
=====================

The tool mediawiki2fedora archives mediawiki pages in a Fedora Commons (version 3) repository.

This tool enriches the existant content in Fedora by adding new datastreams specific for
a Transcribe Bentham adaption of mediawiki.

### Requirements
* perl >= 5.10.1

### Installation

Install all perl dependencies locally
```sh
$ cpanm Carton
$ cd manuscriptdesk2fedora
$ carton install
```
### Configuration
Copy default catmandu.yml.default to catmandu.yml:
```
$ cp catmandu.yml.default catmandu.yml
```
Edit:
```yml
#fedora login details
fedora:
  #baseurl
  - "http://localhost:8080/fedora"
  #username
  - "fedoraAdmin"
  #password
  - "fedoraAdmin"

namespace: mediawiki
mediawiki_importer: mediawiki

# which importer to use (see key 'importer')
mediawiki_importer: mediawiki

#available importers
importer:
  mediawiki:
    package: "Catmandu::Importer::MediaWiki"
    options:
      fix: "mediawiki"
      url: "https://manuscriptdesk.uantwerpen.be/w/api.php"
      lgname: myname
      lgpassword: mypassword
      args:
        prop: "revisions|info"
        rvprop: "ids"
        rvlimit: "max"
        gaplimit: 100
        gapfilterredir: "nonredirects"
```

### Usage

Add extra datastreams from Transcribe Bentham to existing Fedora objects
```
$ carton exec perl bin/md2fedora.pl [--force]
```
Parameters:
  - **force**: force update of object/datastream if it exists already


### Background

See tool mediawiki2fedora

### Extra datastreams

* TB_IMG: this tool gets the html page of the revision, and reads the first link with text 'Original Image'
