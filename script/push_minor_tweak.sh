if [ "$1" = "" ]; then
	comment="minor change for live test"
else
	comment="$@"
fi

echo; echo "************ annotate"
annotate

echo; echo "************ git add ."
git add .

echo; echo "************ git commit -m \"$comment\""
git commit -m "$comment"

script/deploy.sh
