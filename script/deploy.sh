echo; echo "************ git push heroku"
git push heroku

echo; echo "************ heroku rake db:migrate --app actionpods --trace"
heroku rake db:migrate --app actionpods --trace

echo "Heroku Done....."
