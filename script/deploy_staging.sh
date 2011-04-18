echo; echo "************ git push staging master"
git push staging master

echo; echo "************ heroku rake db:migrate --remote staging"
heroku rake db:migrate --remote staging

echo "Heroku Staging Done....."
