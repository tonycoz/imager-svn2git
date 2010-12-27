#!/bin/sh
rm -rf svnwork
svnadmin create svnwork
perl svnxlate.pl <svndump.txt >svndumpfilt.txt
svnadmin load svnwork/ <svndumpfilt.txt || exit 1
svn ls file://`pwd`/svnwork/branches/antialias || exit 1
rm -rf gitwork
git svn clone file://`pwd`/svnwork/ --no-metadata -s -Ttrunk/Imager -A gitauthor.txt --prefix svn/ gitwork || exit 1
cd gitwork
git svn-abandon-fix-refs
git svn-abandon-cleanup
git config --remove-section svn
git config --remove-section svn-remote.svn
# empty branch left from having some branches under branches/Imager
git checkout antialias || ( echo No anti-alias! ; exit 1 )
git branch -D Imager
