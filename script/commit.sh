if [ "$1" = "" ]; then
	comment="minor change for live test"
else
	comment="$@"
fi

echo; echo "************ git add ."
git add .

echo; echo "************ git commit -m \"$comment\""
git commit -am "$comment"

echo; echo "************ git push origin"
git push origin

echo; echo "************ rm -f tmp/*.html"
rm -f tmp/*.html