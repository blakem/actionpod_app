echo; echo "************ annotate"
annotate
script/save_heroku_configs.sh
script/commit.sh $@
script/migrate_all_databases.sh

