XML Catalog Builder
===================

Why does this project exist?
----------------------------

When authoring XML, it is likley that you will be using prior art, i.e. W3C XML Schmeas and other metadata definitions. To do this, your XML document will simply use (via `xmlns:xyz="..."`) or import (via `<import namespace="...">`) those third party namespaces. To do this, many people simply gather all XML files which define those namespaces in the same directory as their own XML document, and reference them via `@schemaLocation`. The problems with this approach are:

* The files you reference may - and often will - in turn reference further files. This means that you will need to go through a series of trial and error cycles until you have copied all the dependncies to your working directory.

* When you publish your working directory so that other people can use your metadata definitions, how will anyone know which file is yours and where to start?

* Some basic metadata definitions are likely to be used by more than one of your dependencies (W3C and MPEG are prime examples of this category). Likleay they will however refer to different versions of those basic definitions, since everybody will have used the most recent version at the tim ethey wrote their definitions. If the file names do not follow a naming convention involving th erelease version, name clashes will occur and it won't validate.

I have thus developed the habit of not using `@schemaLocation` at all. Instead, I have a directory tree wheer I keep copies of all the third part XML metadata definitions that I am using often. This tree is indexed by [XML Catalog](https://www.oasis-open.org/committees/download.php/14810/xml-catalogs.pdf) files. Additionally, I have configured my XML validation to ignore `@schemaLocation` if a catalog entry for the entity exists. That way I don't have to remove `@schemaLocation` from XML files I receive. The tedious bit of this scheme is maintaing the catalog, because the collection of XML files I keep has a couple hundred files. So I needed a script to regenerate the catalog whenever I drop in a new XML package.

How do I install it?
--------------------

Put the perl script in a directory that's in your `${PATH}`, and make sure it's executable (`chmod +x`). Of course you will also need perl installed.

How do I use it?
----------------

According to the motivation provided above, the script assumes a certain directory tree layout:

![Metadata Library Structure](https://github.com/c-alpha/XMLCatalogBuilder/raw/master/LibraryStructure.png)

The most basic way of using this script is to `cd` to the metadata library root directory, and invoke it without any arguments. In the example tree shown in the diagram above, this will generate four `catalog.xml` files:

* One `catalog.xml` in the metadata library root directory, containing `<nextCatalog>` elements pointing to the `catalog.xml` at the top of each originator directory. In our example:
```xml
<nextCatalog catalog="W3C/catalog.xml"/>
<nextCatalog catalog="MPEG-7/catalog.xml"/>
<nextCatalog catalog="MPEG-21/catalog.xml"/>
```
* Three `catalog.xml`, each one at the top of each originator directory (W3C, MPEG-7, and MPRG-21 in our example). They will contain a `<group>` element for each recursive subdirectory. In our example:

`W3C/catalog.xml`:
```xml
<group xml:base="Content/"> ...
```

`MPEG-7/catalog.xml`:
```xml
<group xml:base="2008/"> ...
<group xml:base="2012/"> ...
<group xml:base="2012/profiles/"> ...
```

`MPEG-21/catalog.xml`:
```xml
<group xml:base="1.2.3/"> ...
<group xml:base="1.2.3/dii/"> ...
<group xml:base="1.2.3/dis/"> ...
<group xml:base="1.2.3/dib/"> ...
<group xml:base="2.3.0/"> ...
<group xml:base="2.3.0/dii/"> ...
<group xml:base="2.3.0/dii/profiles/"> ...
<group xml:base="2.3.0/dis/"> ...
<group xml:base="2.3.0/dib/"> ...
```

With this scheme, you can simply add a new package by creating new directories as appropriate, i.e. a new version directory if it's an update, or a new subtree for a new originator, and run the script again. All catalog.xml will be deleted and re-generated. So your catalogs are always up to date, whether you add or remove packages. The package subtree is not "polluted" by catalog files, so that you can still diff versions to see what changed.


Who made this app?
------------------

* [condition-alpha.com](https://github.com/c-alpha)

Change log
----------

2016-01-16 - **v1.0**

* First commit. ([c-alpha](https://github.com/c-alpha))