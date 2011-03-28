echo; echo "************ git push"
git push

echo; echo "************ git push heroku"
git push heroku
echo; echo "************ heroku rake db:migrate"
heroku rake db:migrate
echo "Heroku Done....."

script/migrate_all_databases.sh
