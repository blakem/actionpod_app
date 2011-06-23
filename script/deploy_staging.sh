echo; echo "************ git push staging tropo:master"
git push staging tropo:master

echo; echo "************ heroku rake db:migrate --remote staging --trace"
heroku rake db:migrate --remote staging --trace

echo "Heroku Staging Done....."
