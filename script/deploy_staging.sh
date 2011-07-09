echo; echo "************ git push staging"
git push staging

echo; echo "************ heroku rake db:migrate --remote staging --trace"
heroku rake db:migrate --remote staging --trace

echo "Heroku Staging Done....."
