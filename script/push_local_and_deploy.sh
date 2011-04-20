echo; echo "************ annotate"
annotate

script/commit.sh $@
script/deploy.sh
script/migrate_all_databases.sh
script/deploy_staging.sh

