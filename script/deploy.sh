echo; echo "************ git push heroku"
git push heroku

echo; echo "************ heroku rake db:migrate --app actionpods"
heroku rake db:migrate --app actionpods

echo "Heroku Done....."
