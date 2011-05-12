echo; echo "************ git push staging master"
git push staging master

echo; echo "************ heroku rake db:migrate --remote staging --trace"
heroku rake db:migrate --remote staging --trace

echo "Heroku Staging Done....."
