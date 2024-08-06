#!/bin/bash

# Prepare Android files for Weblate
langs=$(egrep '=' data/strings/strings.txt | cut -d "=" -f1 | sed "s/[[:space:]]//g" | egrep -v "comment|tags|ref" | cut -d ":" -f 1 | sort -u)
android_strings_xml=$(find android/app/src/main/res/values* -name "strings.xml" -type f)
iphone_strings=$(find iphone/Maps/LocalizedStrings/*.lproj -name "Localizable.strings" -type f)

# Resolve any missing languages
for lang in $langs; do
	# https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes
	[[ $lang = "en" ]] && continue  # Skip source language

	alang=${lang/he/iw}  # Hebrew
	alang=${alang/id/in}  # Indonesian
	alang=${alang/zh-Hans/zh}  # Chinese (Simplified)
	alang=${alang/zh-Hant/zh-TW}  # Chinese (Traditional)
	alang=${alang/-/-r}   # Region: e.g. en-rGB
	ls android/app/src/main/res/values-$alang/strings.xml >/dev/null 2>&1 || (echo $alang - Android missing; mkdir -p android/app/src/main/res/values-$alang)

	ilang=$lang
	ls iphone/Maps/LocalizedStrings/$ilang.lproj/Localizable.strings >/dev/null 2>&1 || (echo $ilang - iPhone missing; mkdir -p iphone/Maps/LocalizedStrings/$ilang.lproj)
done
echo -n "Twine: "
echo "$langs" | wc -l
echo -n "Android: "
echo "$android_strings_xml" | wc -l
echo -n "iPhone: "
echo "$iphone_strings" | wc -l

# Perform one last migration from source files
./tools/unix/generate_localizations.sh

# Prepare Android files for Weblate
android_strings_xml=$(find android/app/src/main/res/values* -name "strings.xml" -type f)
# Remove Twine header
sed -i "" -E "/^<!-- Android Strings File -->/d" $android_strings_xml
sed -i "" -E "/^<!-- Generated by Twine -->/d" $android_strings_xml
sed -i "" -E "/^<!-- Language: [-a-zA-Z]+ -->/d" $android_strings_xml

# Replace \t indents
sed -i "" -E "s/^	  /        /" $android_strings_xml # Plurals [tab][sp][sp] -> 8x[sp]
sed -i "" -E "s/^	/    /" $android_strings_xml # Other [tab] -> 4x[sp]

# Adapt \n to incluce a line break like Weblate does
sed -i "" -E '/<string /s/\\n/\n\\n/g' $android_strings_xml
# Remove blank lines before <! SECTION...
sed -i "" -E '/^$/d' $android_strings_xml
# Remove 'other' translation form for languages that don't have it in Weblate
#sed -i "" -E '/<item quantity="other">/d' android/app/src/main/res/values-{be,pl,ru,uk}/strings.xml
# Sort plurals
sed -i "" -E '/<item quantity="zero"/s/(<item quantity="zero">)/0\1/' $android_strings_xml
sed -i "" -E '/<item quantity="one"/s/(<item quantity="one">)/1\1/' $android_strings_xml
sed -i "" -E '/<item quantity="two"/s/(<item quantity="two">)/2\1/' $android_strings_xml
sed -i "" -E '/<item quantity="few"/s/(<item quantity="few">)/3\1/' $android_strings_xml
sed -i "" -E '/<item quantity="many"/s/(<item quantity="many">)/4\1/' $android_strings_xml
sed -i "" -E '/<item quantity="other"/s/(<item quantity="other">)/5\1/' $android_strings_xml
#vim -c 'exe "normal /<plurals name=\<cr>jV/<\/plurals>\<cr>k: ! sort\<cr>" | wq!' android/app/src/main/res/values-be/strings.xml
gawk -i inplace  '/<plurals name=/ {f=0; delete a}
      /<item quantity=/ {f=1}
      /<\/plurals>/ {f=0; n=asort(a); for (i=1;i<=n;i++) print a[i]}
      !f
      f{a[$0]=$0}' $android_strings_xml
sed -i "" -E '/<item quantity=/s/[[:digit:]](<item quantity=.+$)/\1/' $android_strings_xml
# Remove EOF newlines
for xml_file in $android_strings_xml; do
	truncate -s -1  $xml_file
done

# Prepare iPhone files for Weblate
iphone_strings=$(find iphone/Maps/LocalizedStrings/*.lproj -name "Localizable.strings" -type f)
iphone_infoplist_strings=$(find iphone/Maps/LocalizedStrings/*.lproj -name "InfoPlist.strings" -type f)
iphone_stringsdict=$(find iphone/Maps/LocalizedStrings/*.lproj -name "Localizable.stringsdict" -type f)

# Remove Twine headers
sed -i "" 1,6d $iphone_strings $iphone_infoplist_strings # Remove Twine header from .strings
sed -i "" 3,6d $iphone_stringsdict # Remove Twine header from .stringdict

# Remove blank lines between translatable strings
sed -i "" -E '/^$/d' $iphone_strings $iphone_infoplist_strings
# Readd two blank line before header comments
sed -i "" -E '/^[/][*][*]/i \
\
\
' $iphone_strings $iphone_infoplist_strings
# Readd blank line before comments
sed -i "" -E '/^[/][*][^*]/i \
\
' $iphone_strings $iphone_infoplist_strings
# Add a blank line after comment headers
sed -i "" -E $'/^[/][*][*]/,+1{/^"/s/^"/\\\n"/g;}' $iphone_strings $iphone_infoplist_strings
sed -i "" '1,/^./{/^$/d;}' $iphone_strings $iphone_infoplist_strings # Drop spurious first line

# Indent stringdict 2[sp] -> [tab]
sed -i "" -E '/[ ]+</s/  /	/g' $iphone_stringsdict

# Remove 'other' translation form for languages that don't have it in Weblate
sed -i "" -E '/<key>other<\/key>/,+1d' iphone/Maps/LocalizedStrings/{be,pl,ru,uk}.lproj/Localizable.stringsdict
