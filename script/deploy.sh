echo; echo "************ git push"
git push

echo; echo "************ git push heroku"
git push heroku
echo "Heroku Done....."

script/migrate_all_databases.sh
